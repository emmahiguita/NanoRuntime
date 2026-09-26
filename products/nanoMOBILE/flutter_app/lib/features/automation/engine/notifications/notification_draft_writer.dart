/// Redacción contextual de una respuesta a notificación (A14.7).
///
/// Lee el contenido REAL de la notificación y produce un borrador entendido
/// con el runtime local. El LLM es OPCIONAL y está gateado por política: sin
/// modelo permitido o sin motor disponible devuelve null (la automatización
/// NO responde con texto genérico — pediría clarificación al humano). El
/// contenido de la notificación es dato no confiable; el prompt lo aísla.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nanoai/core/services/generative_inference_port.dart';
import 'package:nanoai/core/services/llm_engine_client.dart';

import '../../personal_agent/domain/conversation_agent_role.dart'
    show
        ConversationAgentRole,
        ConversationAgentRouting,
        isCorrectionMessage,
        isGreetingLikeMessage,
        isLiveStateQuestion,
        isSocialReactionMessage,
        productMentionedWithoutCommerce;
import '../messaging/conv_turn_state.dart' show isPureGreeting;
import '../messaging/conversation_context_resolver.dart';
import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../messaging/conversation_agent.dart';
import '../messaging/conversation_memory.dart'
    show
        ConversationMemoryEntry,
        ConversationMemoryEntryKind,
        ConversationMemoryStore;
import '../model/cold_start_retry.dart';
import '../scheduling/messaging_metrics.dart';
import '../messaging/incoming_message.dart';
import '../scheduling/event_dedupe_store.dart' show normalizeDedupeText;
import 'conversation_understanding.dart';
import 'conversation_agent_contract.dart';
import 'notification_draft_prompt.dart';
import 'notification_object.dart';
import 'conversation_social_window.dart';
import '../language/temporal_location_context.dart';
import '../language/turn_complexity_classifier.dart'
    show turnComplexityClassifier;

part 'notification_draft_writer_result.part.dart';
part 'notification_draft_writer_queue.part.dart';
part 'notification_draft_writer_context.part.dart';
part 'notification_draft_writer_prompt.part.dart';
part 'notification_draft_writer_generation.part.dart';
part 'notification_draft_writer_draft.part.dart';
part 'notification_draft_writer_response.part.dart';
part 'notification_draft_writer_trace.part.dart';

final class RuntimeNotificationDraftWriter {
  RuntimeNotificationDraftWriter({
    required LLMEngineClient client,
    required bool Function() llmAllowed,
    // WA-LIVE-01 — Future<bool>: el writer valida el resultado (antes el
    // typedef era Future<void> y el bool se descartaba en silencio).
    required Future<bool> Function(String? modelPath) ensureReady,
    required String? Function() modelPath,
    required bool Function() styleEnabled,
    required String Function() styleText,
    String Function(String messageText)? businessBlock,
    String Function()? toneBlock,
    String Function(String conversationId, String messageText)?
    clientContextFor,
    Future<String> Function(
      String conversationId,
      String messageText,
      String sender,
      String role,
    )?
    personaBlock,
    // P0-ROUTE — rol del turno por dominio (router determinista AUTO-02,
    // jamás LLM). null = rutas legacy: negocio y persona entran por match
    // léxico como antes. Con routing, el ROL manda sobre el contexto:
    // SALES → hechos del negocio; PERSONAL → persona+relación; el resto
    // no recibe bloque comercial (NO COMMERCIAL = NO SALES CONTEXT).
    ConversationAgentRouting Function(
      String conversationId,
      String messageText,
      String sender,
      String? packageName,
    )?
    routeFor,
    ConversationAgentId Function(String conversationId, String packageName)?
    agentFor,
    ConversationMemoryStore? memory,
    GenerativeInferencePort? cloudInferencePort,
  }) : _client = client,
       _llmAllowed = llmAllowed,
       _ensureReady = ensureReady,
       _modelPath = modelPath,
       _styleEnabled = styleEnabled,
       _styleText = styleText,
       _businessBlock = businessBlock,
       _toneBlock = toneBlock,
       _clientContextFor = clientContextFor,
       _personaBlock = personaBlock,
       _routeFor = routeFor,
       _agentFor = agentFor,
       _memory = memory,
       _cloudInferencePort =
           cloudInferencePort ?? CloudGenerativeInferenceAdapter();

  final LLMEngineClient _client;
  final GenerativeInferencePort? _cloudInferencePort;
  final bool Function() _llmAllowed;
  final Future<bool> Function(String? modelPath) _ensureReady;
  final String? Function() _modelPath;

  /// WA-PERSONA-01 — estilo declarado por el dueño. Leído EN VIVO en cada
  /// borrador (closures sobre settingsProvider): cambiar el toggle o el texto
  /// aplica desde el siguiente mensaje, sin reconstruir el writer.
  final bool Function() _styleEnabled;
  final String Function() _styleText;

  /// WA-BUSINESS-01/02 — bloque <DATOS DEL NEGOCIO> leído EN VIVO por
  /// mensaje: el selector determinista elige el subconjunto relevante del
  /// catálogo (el texto del mensaje decide qué hechos entran al prompt).
  final String Function(String messageText)? _businessBlock;

  /// WA-NATURAL-01 — bloque <TONO DE RESPUESTA> (frases deterministas del
  /// perfil; '' si deshabilitado). Leído EN VIVO en cada borrador.
  final String Function()? _toneBlock;

  /// WA-STATE-01 + CONTEXT-GATE-01 — recuerdo estructurado de la consulta
  /// anterior de ESTA conversación, gated por el mensaje actual
  /// (<CONTEXTO DEL CLIENTE>; '' si no hay nada que recordar o el recuerdo
  /// no aplica al turno).
  final String Function(String conversationId, String messageText)?
  _clientContextFor;

  /// PERSONA-COMPOSE-08 — bloque <DATOS DE LA PERSONA> (dueño, relación con
  /// el remitente y ejemplos FTS4). Async: el retriever consulta SQLite por
  /// mensaje; '' si no hay perfil ni ejemplos. Remitente factual, jamás LLM.
  final Future<String> Function(
    String conversationId,
    String messageText,
    String sender,
    String role,
  )?
  _personaBlock;

  /// P0-ROUTE — router de dominio por turno. null = comportamiento legacy.
  final ConversationAgentRouting Function(
    String conversationId,
    String messageText,
    String sender,
    String? packageName,
  )?
  _routeFor;

  final ConversationAgentId Function(String conversationId, String packageName)?
  _agentFor;

  /// WA-MEM-08/WA-AGENT-09 — memoria factual de la conversación (contexto
  /// para el borrador). null = el writer conserva el prompt sin historial.
  final ConversationMemoryStore? _memory;

  /// Drafts en vuelo por INPUT LÓGICO. Single-flight solo para la
  /// reemisión del MISMO evento: un notify duplicado de Android (misma
  /// notification.key + mismo timestamp + mismo texto) reutiliza el draft
  /// en curso en vez de lanzar un segundo POST al motor, que lo rechaza
  /// instantáneo (modelo ocupado) y produce un terminal failed falso.
  /// Verificado en dispositivo: notify duplicado a los 10.5s marcó failed
  /// mientras el borrador real llegó 35s después y se envió bien.
  ///
  /// P1-FIX (2026-09-06) — antes la clave era SOLO conversationId: un
  /// mensaje nuevo que llegaba durante un borrador en curso recibía el
  /// Future ANTERIOR y el dispatcher podía enviar el draft del mensaje A
  /// como respuesta al mensaje B (evidencia física: "hola" → "Déjame
  /// confirmar el stock del negro y te digo"). Invariante: 1 INPUT = 1
  /// DRAFT. La clave es conversationId + fingerprint del input (la MISMA
  /// evidencia del dedupe: notification.key, timestamp y texto).
  static final Map<String, Future<NotificationDraftResult?>> _inFlight = {};
  static final Map<String, String> _latestFlightKeyByConv = {};
  static Future<void> _draftTail = Future<void>.value();
  static int _queueDepth = 0;
  static const _maxQueueDepth = 64;

  /// P1-FIX — fingerprint del input lógico. Reutiliza la evidencia real
  /// del evento (no se inventa identidad): la misma notification.key con
  /// el mismo timestamp y texto ES el mismo evento; cualquier diferencia
  /// es un mensaje distinto.
  static String _flightFingerprint(NotificationObject n) =>
      IncomingMessage.fromNotification(n).eventId;

  Future<NotificationDraftResult?> call(NotificationObject notification) =>
      _enqueueNotificationDraft(this, notification);
}

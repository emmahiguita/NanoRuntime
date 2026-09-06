/// Redacción contextual de una respuesta a notificación (A14.7).
///
/// Lee el contenido REAL de la notificación y produce un borrador entendido
/// con el runtime local. El LLM es OPCIONAL y está gateado por política: sin
/// modelo permitido o sin motor disponible devuelve null (la automatización
/// NO responde con texto genérico — pediría clarificación al humano). El
/// contenido de la notificación es dato no confiable; el prompt lo aísla.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:nanoai/core/services/llm_engine_client.dart';

import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../messaging/conversation_memory.dart' show ConversationMemoryStore;
import '../model/cold_start_retry.dart';
import 'conversation_understanding.dart';
import 'notification_draft_prompt.dart';
import 'notification_object.dart';

/// Fuente de borrador contextual. null = no se puede redactar hoy.
typedef NotificationDraftSource =
    Future<String?> Function(NotificationObject notification);

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
    String Function(String conversationId)? clientContextFor,
    ConversationMemoryStore? memory,
  }) : _client = client,
       _llmAllowed = llmAllowed,
       _ensureReady = ensureReady,
       _modelPath = modelPath,
       _styleEnabled = styleEnabled,
       _styleText = styleText,
       _businessBlock = businessBlock,
       _toneBlock = toneBlock,
       _clientContextFor = clientContextFor,
       _memory = memory;

  final LLMEngineClient _client;
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

  /// WA-STATE-01 — recuerdo estructurado de la consulta anterior de ESTA
  /// conversación (<CONTEXTO DEL CLIENTE>; '' si no hay nada que recordar).
  final String Function(String conversationId)? _clientContextFor;

  /// WA-MEM-08/WA-AGENT-09 — memoria factual de la conversación (contexto
  /// para el borrador). null = el writer conserva el prompt sin historial.
  final ConversationMemoryStore? _memory;

  /// Drafts en vuelo por conversación. Single-flight: un segundo evento de
  /// la MISMA conversación (notificación re-emitida por Android) reutiliza
  /// el draft en curso en vez de lanzar un segundo POST al motor, que lo
  /// rechaza instantáneo (modelo ocupado) y produce un terminal failed
  /// falso. Verificado en dispositivo: notify duplicado a los 10.5s marcó
  /// failed mientras el borrador real llegó 35s después y se envió bien.
  static final Map<String, Future<String?>> _inFlight = {};

  Future<String?> call(NotificationObject notification) async {
    if (!_llmAllowed()) return null;
    final conversationId = resolveConversationIdentity(notification).key.id;
    final inFlight = _inFlight[conversationId];
    if (inFlight != null) return inFlight;
    final future = _draft(notification, conversationId);
    _inFlight[conversationId] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[conversationId], future)) {
        _inFlight.remove(conversationId);
      }
    }
  }

  Future<String?> _draft(
    NotificationObject notification,
    String conversationId,
  ) async {
    try {
      // El motor local se asegura bajo demanda (mismo patrón que el draft
      // writer de mensajes): sin motor cargado no hay entendimiento.
      // WA-LIVE-01 — el retorno se VALIDA: antes se ignoraba y el writer
      // generaba contra un motor no listo (o con otro modelo cargado).
      final ready = await _ensureReady(_modelPath());
      if (!ready) {
        debugPrint('[draft] motor no quedó listo; sin borrador (honesto)');
        return null;
      }
      final history = _memory?.memoryFor(conversationId)?.entries;
      // WA-CONV-01 — salida JSON estructurada: el razonamiento textual ya no
      // se pide (quemaba tokens antes de "Respuesta:" y el extractor podía
      // devolver el análisis como mensaje con salidas recortadas). El parser
      // tolerante recupera `reply` de JSON completo, JSON roto o legacy.
      // sessionId por conversación: el motor reutiliza el KV del turno
      // anterior de ESTA conversación (gate R5) y el prefill solo procesa
      // los tokens nuevos (~20-30s) en vez del prompt completo (~125s en
      // Oppo). El retry frío conserva la MISMA sesión.
      final raw = await generateWithColdRetry(
        _client,
        prompt: conversationAgentPromptFor(
          history: formatConversationHistory(history ?? const []),
          text: notification.text,
          style: _styleEnabled() ? _styleText() : null,
          business: _businessBlock?.call(notification.text),
          tone: _toneBlock?.call(),
          clientContext: _clientContextFor?.call(conversationId),
        ),
        temperature: 0.3,
        maxTokens: 320,
        sessionId: conversationId,
      );
      final draft = parseConversationReply(raw);
      if (draft.isEmpty && raw.trim().isNotEmpty) {
        // WA-PHYS-11: sin reply recuperable la traza cruda (acotada) hace
        // el fallo diagnosticable en dispositivo.
        debugPrint('[draft] sin reply parseable; raw=${_sample(raw)}');
      }
      if (draft.isEmpty) return null;
      return draft.length <= 2000 ? draft : draft.substring(0, 2000);
    } on Object catch (e) {
      // Motor local no disponible o falló → sin borrador (honesto).
      // WA-LIVE-01 — el catch mudo escondía la razón real del fallo
      // (evidencia device: 7 min de turno colgado sin una sola traza).
      debugPrint('[draft] falló: ${e.runtimeType}: $e');
      return null;
    }
  }

  /// Muestra acotada de la salida cruda para trazas físicas (200 chars,
  /// una línea: el raw completo con saltos inundaba el logcat).
  static String _sample(String raw) {
    final single = raw.replaceAll('\n', ' ').trim();
    return single.length <= 200 ? single : single.substring(0, 200);
  }
}

/// Redacción contextual de una respuesta a notificación (A14.7).
///
/// Lee el contenido REAL de la notificación y produce un borrador entendido
/// con el runtime local. El LLM es OPCIONAL y está gateado por política: sin
/// modelo permitido o sin motor disponible devuelve null (la automatización
/// NO responde con texto genérico — pediría clarificación al humano). El
/// contenido de la notificación es dato no confiable; el prompt lo aísla.
library;

import 'package:nanoai/core/services/llm_engine_client.dart';

import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../messaging/conversation_memory.dart' show ConversationMemoryStore;
import '../model/cold_start_retry.dart';
import 'notification_draft_prompt.dart';
import 'notification_object.dart';

/// Fuente de borrador contextual. null = no se puede redactar hoy.
typedef NotificationDraftSource =
    Future<String?> Function(NotificationObject notification);

final class RuntimeNotificationDraftWriter {
  RuntimeNotificationDraftWriter({
    required LLMEngineClient client,
    required bool Function() llmAllowed,
    required Future<void> Function(String? modelPath) ensureReady,
    required String? Function() modelPath,
    ConversationMemoryStore? memory,
  }) : _client = client,
       _llmAllowed = llmAllowed,
       _ensureReady = ensureReady,
       _modelPath = modelPath,
       _memory = memory;

  final LLMEngineClient _client;
  final bool Function() _llmAllowed;
  final Future<void> Function(String? modelPath) _ensureReady;
  final String? Function() _modelPath;

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
      await _ensureReady(_modelPath());
      final history = _memory?.memoryFor(conversationId)?.entries;
      final result = await _client.generate(
        prompt: conversationAgentPromptFor(
          history: formatConversationHistory(history ?? const []),
          text: notification.text,
        ),
        temperature: 0.3,
        // WA-CONVERSATION-01 — el CoT (Intención/Hechos/Plan) consume
        // tokens ANTES de "Respuesta:". Con 200, un mensaje largo cortaba
        // la salida a mitad del análisis y el extractor devolvía el
        // razonamiento como respuesta (verificado: respuestas raras con
        // mensajes amplios). 320 deja margen para análisis + respuesta
        // proporcionada sin disparar la latencia del 0.5B.
        maxTokens: 320,
        // WA-CONVERSATION-01 — sesión por conversación: el motor reutiliza
        // el KV del turno anterior de ESTA conversación (gate R5) y el
        // prefill solo procesa los tokens nuevos (~20-30s) en vez del prompt
        // completo (~125s en Oppo). Sin esto, cada borrador arranca con
        // KV reset y el prefill entero revienta el timeout del cliente.
        sessionId: conversationId,
      );
      final draft = _extractResponse(result.text);
      if (draft.isEmpty) return null;
      return draft.length <= 2000 ? draft : draft.substring(0, 2000);
    } on Object {
      // Motor local no disponible o falló → sin borrador (honesto).
      return null;
    }
  }

  /// Extrae solo la respuesta del formato CoT ("Razonamiento: ..." /
  /// "Respuesta: ..."). Tolerante: sin marcador de respuesta se usa el texto
  /// completo; si el modelo escribió el razonamiento pero olvidó el marcador,
  /// se descarta la línea de razonamiento y queda el resto.
  static String _extractResponse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final respMarker = RegExp(r'Respuesta\s*:', caseSensitive: false);
    final m = respMarker.firstMatch(trimmed);
    if (m != null) {
      final tail = trimmed.substring(m.end).trim();
      if (tail.isNotEmpty) return tail;
    }
    final razonMarker = RegExp(
      r'Razonamiento\s*:',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (razonMarker != null) {
      final rest = trimmed.substring(razonMarker.end).trim();
      if (rest.isNotEmpty) return rest;
    }
    return trimmed;
  }
}

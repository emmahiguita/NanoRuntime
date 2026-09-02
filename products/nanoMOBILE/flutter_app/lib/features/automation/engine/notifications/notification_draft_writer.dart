/// Redacción contextual de una respuesta a notificación (A14.7).
///
/// Lee el contenido REAL de la notificación y produce un borrador entendido
/// con el runtime local. El LLM es OPCIONAL y está gateado por política: sin
/// modelo permitido o sin motor disponible devuelve null (la automatización
/// NO responde con texto genérico — pediría clarificación al humano). El
/// contenido de la notificación es dato no confiable; el prompt lo aísla.
library;

import 'package:nanoai/core/services/llm_engine_client.dart';

import 'notification_draft_prompt.dart';
import 'notification_object.dart';

/// Fuente de borrador contextual. null = no se puede redactar hoy.
typedef NotificationDraftSource = Future<String?> Function(
  NotificationObject notification,
);

final class RuntimeNotificationDraftWriter {
  RuntimeNotificationDraftWriter({
    required LLMEngineClient client,
    required bool Function() llmAllowed,
    required Future<void> Function(String? modelPath) ensureReady,
    required String? Function() modelPath,
  }) : _client = client,
       _llmAllowed = llmAllowed,
       _ensureReady = ensureReady,
       _modelPath = modelPath;

  final LLMEngineClient _client;
  final bool Function() _llmAllowed;
  final Future<void> Function(String? modelPath) _ensureReady;
  final String? Function() _modelPath;

  Future<String?> call(NotificationObject notification) async {
    if (!_llmAllowed()) return null;
    try {
      // El motor local se asegura bajo demanda (mismo patrón que el draft
      // writer de mensajes): sin motor cargado no hay entendimiento.
      await _ensureReady(_modelPath());
      final result = await _client.generate(
        prompt: notificationDraftPromptFor(
          packageName: notification.packageName,
          title: notification.title,
          text: notification.text,
        ),
        temperature: 0.3,
        maxTokens: 120,
      );
      final draft = result.text.trim();
      if (draft.isEmpty) return null;
      return draft.length <= 2000 ? draft : draft.substring(0, 2000);
    } on Object {
      // Motor local no disponible o falló → sin borrador (honesto).
      return null;
    }
  }
}

import 'dart:async';
import '../../../core/services/runtime_engine.dart';
import 'nano_ai_models.dart';
import 'nano_assistant_prompt.dart';

/// Adapta el modelo seleccionado de Nano (GGUF, LiteRT, MNN o destino
/// configurado). No carga otro modelo ni crea un motor de inferencia paralelo.
NanoProvider buildNanoRuntimeProvider(RuntimeEngineNotifier engine) {
  Future<void> Function()? activeCancel;
  return NanoProvider(
    id: 'local_litert',
    name: 'Modelo seleccionado de Nano',
    kind: NanoProviderKind.local,
    isOnDevice: () => !engine.isRemoteInference,
    isReady: () =>
        engine.phase == EnginePhase.ready &&
        !engine.client.hasActiveStreamRequest &&
        activeCancel == null,
    unavailableReason: () =>
        engine.client.hasActiveStreamRequest || activeCancel != null
        ? 'El modelo está atendiendo otra petición. Espera antes de consultar.'
        : 'Carga un modelo de chat desde Modelos. ${engine.reason ?? "El motor no está listo."}',
    cancel: () async {
      await activeCancel?.call();
    },
    ask: (prompt) async {
      if (activeCancel != null || engine.client.hasActiveStreamRequest) {
        throw StateError(
          'El modelo está ocupado. No se inició otra generación.',
        );
      }
      if (engine.phase != EnginePhase.ready) {
        throw StateError(
          'El modelo seleccionado no está listo para responder.',
        );
      }
      final client = engine.client;
      final idleTimeout = client.streamIdleTimeout;
      final handle = client.generateStream(
        prompt: nanoAssistantPrompt(prompt),
        maxTokens: 512,
        temperature: .3,
      );
      var cancelling = false;
      Future<void> cancel() async {
        if (cancelling) return;
        cancelling = true;
        // Cierra la conexión/lease propia incluso si el backend tarda en cancelar.
        final request = client.cancelRequest(handle.requestId);
        handle.client.close();
        try {
          await request.timeout(const Duration(seconds: 3));
        } on Object {
          // El cierre ya ocurrió; no se detiene el motor de otro propietario.
        }
      }

      activeCancel = cancel;
      var completed = false;
      try {
        final text = StringBuffer();
        await for (final token in handle.stream.timeout(idleTimeout)) {
          text.write(token.content);
        }
        if (cancelling) throw StateError('Generación cancelada.');
        final value = text.toString().trim();
        if (value.isEmpty) throw StateError('El modelo no produjo texto.');
        completed = true;
        return value;
      } on TimeoutException {
        await cancel();
        rethrow;
      } finally {
        if (!completed) await cancel();
        handle.client.close();
        activeCancel = null;
      }
    },
  );
}

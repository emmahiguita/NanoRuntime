// nano_providers.dart — Riverpod providers del asistente flotante.
// QUÉ: Expone los recursos que NanoFloatingWrapper necesita inyectados:
//      webProviders (lista de NanoProvider incluyendo modelo local LiteRT),
//      actions (NanoActionPort), y audioLevel (ValueNotifier<double> silencioso).
// CÓMO: Lee runtimeEngineProvider para el modelo local y browserAiGatewayProvider para la web.
// POR QUÉ: Un solo lugar de composición (DIP / composition root). Permite al Búho
//          responder offline y ultra-rápido usando Qwen3 LiteRT antes de intentar la web.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser_ai/application/browser_ai_gateway.dart';
import '../../browser_ai/domain/browser_ai_query.dart';
import '../../automation/engine/agent_dependencies.dart';
import '../../../core/services/runtime_engine.dart';
import 'nano_ai_models.dart';
import 'nano_action_port_adapter.dart';

/// Nivel de audio del micrófono 0..1 compartido por toda la sesión.
final nanoAudioLevelProvider = Provider<ValueNotifier<double>>(
  (ref) => ValueNotifier(0.0),
);

/// Inyecta rutas locales y web; prioriza el modelo LiteRT local cuando está disponible.
final nanoWebProvidersProvider = Provider<List<NanoProvider>>((ref) {
  final gateway = ref.watch(browserAiGatewayProvider);
  final engineNotifier = ref.watch(runtimeEngineProvider.notifier);

  // Proveedor Local LiteRT-LM (Qwen3 / Gemma) para inferencia nativa en el dispositivo.
  final localProvider = NanoProvider(
    id: 'local_litert',
    name: 'Nano Local (LiteRT)',
    kind: NanoProviderKind.local,
    ask: (prompt) async {
      try {
        final client = engineNotifier.client;
        final handle = client.generateStream(
          prompt: prompt,
          maxTokens: 512,
          temperature: 0.3,
        );
        final buffer = StringBuffer();
        await for (final token in handle.stream) {
          buffer.write(token.content);
        }
        final result = buffer.toString().trim();
        if (result.isNotEmpty) return result;
      } catch (e) {
        debugPrint('[NanoFloating] Inferencia local LiteRT falló: $e');
      }
      throw Exception('El modelo local no está listo o no generó respuesta.');
    },
  );

  NanoProvider buildWebProvider(String id, String name) => NanoProvider(
    id: id,
    name: name,
    kind: NanoProviderKind.approvedWeb,
    ask: (prompt) async {
      final res = await gateway.query(
        BrowserAiQuery(providerId: id, prompt: prompt),
      );
      if (res.needsUserAction) {
        throw const NanoUserActionRequiredException(
          'La sesión necesita atención. Inicia sesión en el navegador.',
        );
      }
      if (res.isCompleted && res.content.trim().isNotEmpty) {
        return res.content;
      }
      throw Exception(res.error ?? 'La ruta web devolvió una respuesta vacía.');
    },
  );

  return [
    localProvider,
    buildWebProvider('deepseek', 'DeepSeek'),
    buildWebProvider('chatgpt', 'ChatGPT'),
    buildWebProvider('gemini', 'Gemini'),
    buildWebProvider('claude', 'Claude'),
    buildWebProvider('mistral', 'Mistral'),
  ];
});

/// Adapta AgentToolDispatcher al contrato NanoActionPort (modo Acción).
final nanoActionPortProvider = Provider<NanoActionPort>((ref) {
  final dispatcher = ref.watch(agentDispatcherProvider);
  return NanoActionPortAdapter(dispatcher);
});

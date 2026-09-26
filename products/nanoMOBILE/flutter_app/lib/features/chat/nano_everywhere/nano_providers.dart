// nano_providers.dart — Riverpod providers del asistente flotante.
// QUÉ: Expone los tres recursos que NanoFloatingWrapper necesita inyectados:
//      webProviders (lista de NanoProvider), actions (NanoActionPort),
//      y audioLevel (ValueNotifier<double> silencioso).
// CÓMO: Lee browserAiGatewayProvider y agentDispatcherProvider ya existentes;
//      construye NanoProvider.ask usando BrowserAiGateway.query().
// POR QUÉ: Un solo lugar de composición (DIP / composition root). La cápsula
//          flotante no instancia nada — solo consume providers inyectados.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser_ai/application/browser_ai_gateway.dart';
import '../../browser_ai/domain/browser_ai_query.dart';
import '../../automation/engine/agent_dependencies.dart';
import 'nano_ai_models.dart';
import 'nano_action_port_adapter.dart';

/// Nivel de audio del micrófono 0..1 compartido por toda la sesión.
/// Conéctalo al SpeechChannelHandler real cuando esté disponible.
final nanoAudioLevelProvider = Provider<ValueNotifier<double>>(
  (ref) => ValueNotifier(0.0),
);

/// Inyecta las rutas web existentes; el asistente prueba solo una por turno y oculta su origen.
final nanoWebProvidersProvider = Provider<List<NanoProvider>>((ref) {
  final gateway = ref.watch(browserAiGatewayProvider);

  NanoProvider buildProvider(String id, String name) => NanoProvider(
    id: id,
    name: name,
    kind: NanoProviderKind.approvedWeb,
    ask: (prompt) async {
      final res = await gateway.query(
        BrowserAiQuery(providerId: id, prompt: prompt),
      );
      // BrowserAiResponse.isCompleted + .content (no .ok/.text)
      if (res.needsUserAction) {
        throw const NanoUserActionRequiredException(
          'La sesión necesita atención. Inicia sesión en la pestaña del navegador y vuelve a enviar tu mensaje.',
        );
      }
      if (res.isCompleted && res.content.trim().isNotEmpty) {
        return res.content;
      }
      throw Exception(res.error ?? 'La ruta web devolvió una respuesta vacía.');
    },
  );

  return [
    buildProvider('deepseek', 'DeepSeek'),
    buildProvider('chatgpt', 'ChatGPT'),
    buildProvider('gemini', 'Gemini'),
    buildProvider('claude', 'Claude'),
    buildProvider('mistral', 'Mistral'),
  ];
});

/// Adapta AgentToolDispatcher al contrato NanoActionPort (modo Acción).
final nanoActionPortProvider = Provider<NanoActionPort>((ref) {
  final dispatcher = ref.watch(agentDispatcherProvider);
  return NanoActionPortAdapter(dispatcher);
});

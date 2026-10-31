library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../browser_ai/application/browser_ai_gateway.dart';
import '../../browser_ai/domain/browser_ai_query.dart';
import '../../automation/engine/agent_dependencies.dart';
import '../../automation/application/automation_engine_provider.dart';
import '../../../core/services/runtime_engine.dart';
import 'nano_ai_models.dart';
import 'nano_local_provider.dart';
import 'nano_action_port_adapter.dart';
import 'nano_automation_goal_runner.dart';
import '../../automation/application/whatsapp_ui_goal_preparer.dart';
import 'nano_workspace_commands.dart';
import 'nano_floating_wrapper.dart';
import '../../automation/application/whatsapp_contacts_provider.dart';
import '../../automation/engine/execution/handlers/whatsapp_contact_resolver.dart';
import '../../automation/engine/execution/handlers/whatsapp_command_input.dart';

/// Nivel de audio del micrófono 0..1 compartido por toda la sesión.
final nanoAudioLevelProvider = Provider<ValueNotifier<double>>((ref) {
  final level = ValueNotifier(0.0);
  ref.onDispose(level.dispose);
  return level;
});

/// Inyecta rutas existentes; consulta disponibilidad del modelo seleccionado.
final nanoWebProvidersProvider = Provider<List<NanoProvider>>((ref) {
  final gateway = ref.watch(browserAiGatewayProvider);
  final engineNotifier = ref.watch(runtimeEngineProvider.notifier);

  // Readiness se consulta al despachar, sin recrear el controlador por cada fase.
  final localProvider = buildNanoRuntimeProvider(engineNotifier);

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

/// Une órdenes y objetivos del búho al motor público y su cancelación propia.
final nanoActionPortProvider = Provider<NanoActionPort>((ref) {
  final dispatcher = ref.watch(agentDispatcherProvider);
  final goals = NanoAutomationGoalRunner(
    () => ref.read(automationEngineProvider),
    prepare: WhatsAppUiGoalPreparer(
      () => ref.read(agentExecutorProvider),
    ).prepare,
  );
  ref.onDispose(goals.cancel);
  final workspace = NanoWorkspaceCommands(
    executor: () => ref.read(agentExecutorProvider),
    localProvider: () => ref
        .read(nanoWebProvidersProvider)
        .firstWhere((p) => p.kind == NanoProviderKind.local),
    modelKey: () => ref.read(runtimeEngineProvider).modelPath ?? 'sin_modelo',
    progress: (text) =>
        NanoFloatingWrapper.activeController?.reportStatus(text),
    resolveContact: (text) async {
      if (WhatsAppCommandInput.isUsername(text)) return text;
      if (RegExp(r'^\+?[\d\s()\-]{7,22}$').hasMatch(text)) {
        final digits = text.replaceAll(RegExp(r'\D'), '');
        return digits.length >= 7 && digits.length <= 15 ? digits : null;
      }
      final value = await WhatsAppContactResolver(
        ref.read(whatsappContactsServiceProvider),
      ).resolve(text);
      return value == null || value.isGroup ? null : value.number;
    },
  );
  ref.onDispose(workspace.cancel);
  return NanoActionPortAdapter(
    dispatcher,
    workspace: workspace,
    runOwnedGoal: goals.run,
    cancelGoal: goals.cancel,
    runOwnedCommand: (command, id) =>
        ref.read(automationEngineProvider).runCommand(command, executionId: id),
    cancelOwnedCommand: (id) =>
        ref.read(automationEngineProvider).cancelExecution(id),
  );
});

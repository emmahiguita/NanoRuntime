import 'agent_dispatcher_dependencies.dart';
import '../../ledger/automation_command_audit.dart';
export 'agent_dispatcher_exports.dart';

part 'agent_tool_command_router.dart';
part 'agent_tool_execution_router.dart';
part 'agent_tool_messaging_router.dart';
part 'agent_tool_device_helpers.dart';
part 'agent_dispatcher_operations.dart';
part 'agent_dispatcher_state.dart';
part 'agent_dispatcher_commands.dart';
part 'agent_dispatcher_guard_api.dart';
part 'agent_dispatcher_guard.dart';
part 'agent_dispatcher_plans.dart';
part 'agent_dispatcher_runtime.dart';

/// Fachada pública del agente: conserva constructor, métodos y dueños de ejecución.
class AgentToolDispatcher extends _AgentDispatcherBase
    with
        _AgentDispatcherCommands,
        _AgentDispatcherGuardApi,
        _AgentDispatcherGuard,
        _AgentDispatcherPlans,
        _AgentDispatcherRuntime {
  AgentToolDispatcher({
    super.executor,
    super.registry,
    super.policy,
    super.verifier,
    super.router,
    super.linuxAdapter,
    super.launchPackage,
    super.globalAction,
    super.swipe,
    super.longPress,
    super.systemIntentLauncher,
    super.systemGraphSource,
    super.devicePermissionsSource,
    super.shizukuStatusSource,
    super.openPermissionSource,
    super.platformStateReader,
    super.executionJournal,
    super.currentSituationSource,
    super.voiceOutputEnabled,
    super.mcpConnectionRegistry,
    super.installedAppCatalog,
    super.uiHandler,
    super.deviceHandler,
    super.shizukuHandler,
    super.notificationHandler,
    super.linuxHandler,
    super.semanticLinuxHandler,
    super.mcpHandler,
    super.webHandler,
    super.browserAgentHandler,
    super.browserAiAdapter,
    super.whatsAppHandler,
    super.universalMessagingHandler,
    super.alarmHandler,
    super.appInspectorHandler,
    super.diagnosticsHandler,
    super.adbHandler,
    super.benchmarkHandler,
    super.dynamicRegistry,
  });

  static bool isToolCommand(String text) {
    final t = text.trim();
    return t.startsWith('@') && !t.startsWith('@@');
  }
}

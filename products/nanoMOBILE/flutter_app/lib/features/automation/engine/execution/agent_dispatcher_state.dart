part of 'agent_tool_dispatcher.dart';

/// Dueño único de dependencias y estado. Mantiene los defaults reales anteriores.
abstract class _AgentDispatcherBase implements _AgentDispatcherOperations {
  _AgentDispatcherBase({
    AgentExecutor? executor,
    ToolRegistry? registry,
    PolicyEngine? policy,
    AgentVerifier? verifier,
    ActionPathRouter? router,
    LinuxToolAdapter? linuxAdapter,
    Future<bool> Function(String packageName)? launchPackage,
    Future<bool> Function(String action)? globalAction,
    Future<bool> Function(int x1, int y1, int x2, int y2, {int durationMs})?
    swipe,
    Future<bool> Function(int x, int y, {int durationMs})? longPress,
    SystemIntentLauncher? systemIntentLauncher,
    Future<SystemGraph> Function()? systemGraphSource,
    Future<Map<dynamic, dynamic>> Function()? devicePermissionsSource,
    Future<Map<dynamic, dynamic>> Function()? shizukuStatusSource,
    Future<bool> Function(String kind)? openPermissionSource,
    PlatformStateReader? platformStateReader,
    ExecutionJournal? executionJournal,
    CurrentSituationSource? currentSituationSource,
    bool Function()? voiceOutputEnabled,
    McpConnectionRegistry? mcpConnectionRegistry,
    InstalledAppCatalog? installedAppCatalog,
    UiToolHandler? uiHandler,
    DeviceSystemHandler? deviceHandler,
    ShizukuToolHandler? shizukuHandler,
    NotificationToolHandler? notificationHandler,
    LinuxToolHandler? linuxHandler,
    SemanticLinuxToolHandler? semanticLinuxHandler,
    McpToolHandler? mcpHandler,
    WebToolHandler? webHandler,
    BrowserAgentToolHandler? browserAgentHandler,
    BrowserAiToolAdapter? browserAiAdapter,
    WhatsAppToolHandler? whatsAppHandler,
    UniversalMessagingToolHandler? universalMessagingHandler,
    AlarmToolHandler? alarmHandler,
    AppInspectorToolHandler? appInspectorHandler,
    SystemDiagnosticsToolHandler? diagnosticsHandler,
    AdbToolHandler? adbHandler,
    BenchmarkToolHandler? benchmarkHandler,
    DynamicToolRegistry? dynamicRegistry,
  }) : _executor = executor ?? NanoAgentExecutor(),
       _policy = policy ?? PolicyEngine(registry: registry),
       _verifier = verifier,
       _router = router ?? ActionPathRouter(),
       _launchPackage =
           launchPackage ?? NanoRuntimeApi.instance.agentLaunchPackage,
       _globalAction =
           globalAction ?? NanoRuntimeApi.instance.agentGlobalAction,
       _swipe = swipe ?? NanoRuntimeApi.instance.agentSwipe,
       _longPress = longPress ?? NanoRuntimeApi.instance.agentLongPressAt,
       _systemIntentLauncher = systemIntentLauncher,
       _platformStateReader = platformStateReader,
       _executionJournal = executionJournal,
       _currentSituationSource = currentSituationSource,
       _customUiHandler = uiHandler,
       _webHandler = webHandler ?? WebToolHandler(),
       _browserAgentHandler =
           browserAgentHandler ?? const BrowserAgentToolHandler(),
       _browserAiAdapter = browserAiAdapter,
       _whatsAppHandler = whatsAppHandler ?? WhatsAppToolHandler(),
       _universalMessagingHandler =
           universalMessagingHandler ?? UniversalMessagingToolHandler(),
       _alarmHandler = alarmHandler ?? AlarmToolHandler(),
       _appInspectorHandler =
           appInspectorHandler ??
           AppInspectorToolHandler(
             catalog: installedAppCatalog,
             situationSource: currentSituationSource,
           ),
       _diagnosticsHandler =
           diagnosticsHandler ?? SystemDiagnosticsToolHandler(),
       _adbHandler = adbHandler ?? AdbToolHandler(),
       _benchmarkHandler = benchmarkHandler ?? BenchmarkToolHandler(),
       _shizukuHandler = shizukuHandler ?? ShizukuToolHandler(),
       _notificationHandler = notificationHandler ?? NotificationToolHandler(),
       _linuxHandler =
           linuxHandler ??
           LinuxToolHandler(
             adapter: linuxAdapter,
             platformStateReader: platformStateReader,
           ),
       _semanticLinuxHandler =
           semanticLinuxHandler ?? const SemanticLinuxToolHandler(),
       _mcpHandler =
           mcpHandler ??
           McpToolHandler(mcpConnectionRegistry: mcpConnectionRegistry),
       _installedAppCatalog = installedAppCatalog,
       _dynamicRegistry = dynamicRegistry,
       _deviceHandler =
           deviceHandler ??
           DeviceSystemHandler(
             systemGraphSource: systemGraphSource,
             devicePermissionsSource: devicePermissionsSource,
             shizukuStatusSource: shizukuStatusSource,
             openPermissionSource: openPermissionSource,
             voiceOutputEnabled: voiceOutputEnabled,
             installedAppCatalog: installedAppCatalog,
             webHandler: webHandler ?? WebToolHandler(),
             shizukuHandler: shizukuHandler ?? ShizukuToolHandler(),
           );
  final AgentExecutor _executor;
  final PolicyEngine _policy;
  final InstalledAppCatalog? _installedAppCatalog;
  final DynamicToolRegistry? _dynamicRegistry;
  AgentVerifier? _verifier;
  ToolRegistry get registry => _policy.registry;
  bool requiresConfirmation(String toolName) =>
      _policy.requiresConfirmation(toolName);
  bool requiresGoalDirectedExecution(List<ToolCall> plan) =>
      PlanExecutionCoordinator.requiresGoalDirectedExecution(plan);
  late final PlanExecutionCoordinator _planCoordinator =
      PlanExecutionCoordinator(
        policy: _policy,
        router: _router,
        executor: _executor,
        runToolGuarded: runToolGuarded,
        executeWithTimeout: _executeWithTimeout,
        executeReportWithTimeout: (call, tool, budget) =>
            _executeReportWithTimeout(call, tool, budget),
        executeOwnedReportWithTimeout: (call, tool, budget, {cancellation}) =>
            _executeReportWithTimeout(
              call,
              tool,
              budget,
              cancellation: cancellation,
            ),
        executionJournal: _executionJournal,
      );
  final ActionPathRouter _router;
  final Future<bool> Function(String packageName) _launchPackage;
  final Future<bool> Function(String action) _globalAction;
  final Future<bool> Function(int x1, int y1, int x2, int y2, {int durationMs})
  _swipe;
  final Future<bool> Function(int x, int y, {int durationMs}) _longPress;
  final SystemIntentLauncher? _systemIntentLauncher;
  final PlatformStateReader? _platformStateReader;
  final ExecutionJournal? _executionJournal;
  final CurrentSituationSource? _currentSituationSource;
  UiToolHandler? _customUiHandler;
  UiToolHandler get _uiHandler => _customUiHandler ??= UiToolHandler(
    executor: _executor,
    verifier: verifier,
    loop: loop,
    globalAction: _globalAction,
    swipe: _swipe,
    longPress: _longPress,
    systemIntentLauncher: _systemIntentLauncher,
  );
  final DeviceSystemHandler _deviceHandler;
  final ShizukuToolHandler _shizukuHandler;
  final NotificationToolHandler _notificationHandler;
  final LinuxToolHandler _linuxHandler;
  final SemanticLinuxToolHandler _semanticLinuxHandler;
  final McpToolHandler _mcpHandler;
  final WebToolHandler _webHandler;
  final BrowserAgentToolHandler _browserAgentHandler;
  final BrowserAiToolAdapter? _browserAiAdapter;
  final WhatsAppToolHandler _whatsAppHandler;
  final UniversalMessagingToolHandler _universalMessagingHandler;
  final AlarmToolHandler _alarmHandler;
  final AppInspectorToolHandler _appInspectorHandler;
  final SystemDiagnosticsToolHandler _diagnosticsHandler;
  final AdbToolHandler _adbHandler;
  final BenchmarkToolHandler _benchmarkHandler;
  AgentVerifier get verifier =>
      _verifier ??= ActionVerifier(snapshotFn: _executor.snapshot);
  AgentLoop? _loop;
  AgentLoop get loop =>
      _loop ??= AgentLoop(executor: _executor, verifier: verifier);
}

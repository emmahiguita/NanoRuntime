/// AgentToolDispatcher — herramientas de UI para el chat.
///
/// Dos vías de entrada, una sola ejecución segura ([NanoAgentExecutor]):
///
/// 1. Comandos `@` deterministas escritos por el usuario (sin LLM, funcionan
///    con el motor degradado): `@tap text=Bluetooth`, `@pantalla`, `@back`.
/// 2. Tool-calling del LLM: el modelo responde un JSON de una línea
///    `{"tool":"tap","selector":"..."}` y [AgentToolProtocol] lo extrae del
///    texto generado con parseo tolerante (los GGUF 1B-7B no tienen
///    function calling fiable: puede añadir texto alrededor del JSON).
///
/// Invariante: todo fallo degrada a texto legible en español — jamás lanza.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/services/nano_runtime_api.dart';
import '../agent_tools/registry/tool_registry.dart' show DynamicToolRegistry;
import '../governance/action_confirmation.dart';
import '../governance/rule_execution_authority.dart';
import '../governance/semantic_policy.dart';
import '../mcp/mcp_connection_registry.dart';
import '../orchestration/execution_journal.dart';
import '../perception/current_situation.dart';
import '../platform/linux_tool_adapter.dart';
import '../system/installed_app_catalog.dart';
import '../system/system_graph.dart' show SystemGraph;
import '../system/system_intent_launcher.dart' show SystemIntentLauncher;
import '../voice/execution_cancellation.dart';
import 'action_path_router.dart';
import 'action_verifier.dart';
import 'agent_executor.dart';
import 'agent_loop.dart';
import 'handlers/browser_agent_tool_handler.dart';
import 'handlers/alarm_tool_handler.dart';
import 'handlers/app_inspector_tool_handler.dart';
import 'handlers/system_diagnostics_tool_handler.dart';
import 'handlers/adb_tool_handler.dart';
import 'handlers/benchmark_tool_handler.dart';
import 'handlers/device_system_handler.dart';
import 'handlers/linux_tool_handler.dart';
import 'handlers/mcp_tool_handler.dart';
import 'handlers/notification_tool_handler.dart';
import 'handlers/semantic_linux_tool_handler.dart';
import 'handlers/shizuku_tool_handler.dart';
import 'handlers/ui_tool_handler.dart';
import 'handlers/web_tool_handler.dart';
import 'handlers/whatsapp_tool_handler.dart';
import 'platform_verification.dart';
import 'plan_execution_coordinator.dart';
import 'tool_call.dart';
import 'tool_outcome.dart';
import 'tool_registry.dart';

import 'handlers/browser_ai_tool_adapter.dart';

export 'agent_tool_protocol.dart';
export 'handlers/browser_agent_tool_handler.dart';
export 'handlers/alarm_tool_handler.dart';
export 'handlers/app_inspector_tool_handler.dart';
export 'handlers/system_diagnostics_tool_handler.dart';
export 'handlers/adb_tool_handler.dart';
export 'handlers/benchmark_tool_handler.dart';
export 'handlers/browser_ai_tool_adapter.dart';
export 'handlers/device_system_handler.dart';
export 'handlers/linux_tool_handler.dart';
export 'handlers/mcp_tool_handler.dart';
export 'handlers/notification_tool_handler.dart';
export 'handlers/shizuku_tool_handler.dart';
export 'handlers/ui_tool_handler.dart';
export 'handlers/web_tool_handler.dart';
export 'handlers/whatsapp_tool_handler.dart';
export 'plan_execution_coordinator.dart';
export 'tool_call.dart';
export 'tool_loop_detector.dart';
export 'tool_outcome.dart';

part 'agent_tool_command_router.dart';
part 'agent_tool_execution_router.dart';

/// Ejecutor de comandos `@` y de [ToolCall] del LLM.
///
/// Gobernanza (§12): toda ejecución pasa por [PolicyEngine] — herramienta
/// fuera del registro, presupuesto agotado o escritura externa sin
/// confirmación NO se ejecutan. Los comandos `@` (autoría humana) llevan
/// confirmación implícita; el tool-calling del LLM (agencia autónoma) no.
class AgentToolDispatcher {
  /// DIP: depende de las interfaces [AgentExecutor] y [AgentVerifier] — el
  /// composition root (agent_dependencies.dart) inyecta las implementaciones
  /// reales; los tests inyectan fakes. El default es la implementación real
  /// (compat standalone), nunca una falsa.
  AgentToolDispatcher({
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
       _alarmHandler = alarmHandler ?? AlarmToolHandler(),
       _appInspectorHandler = appInspectorHandler ??
           AppInspectorToolHandler(
             catalog: installedAppCatalog,
             situationSource: currentSituationSource,
           ),
       _diagnosticsHandler = diagnosticsHandler ?? SystemDiagnosticsToolHandler(),
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

  /// Fuente única para política y prompt del modelo local.
  ToolRegistry get registry => _policy.registry;

  /// Misma decisión semántica usada justo antes de ejecutar, expuesta para
  /// que la UI pueda anticipar la pausa sin mantener una segunda política.
  bool requiresConfirmation(String toolName) =>
      _policy.requiresConfirmation(toolName);

  /// Un plan legacy con más de una mutación de UI no puede ejecutarse como
  /// una lista ciega. Debe pasar por TaskOrchestrator, que observa y clasifica
  /// de nuevo la superficie después de cada acción.
  bool requiresGoalDirectedExecution(List<ToolCall> plan) =>
      PlanExecutionCoordinator.requiresGoalDirectedExecution(plan);

  late final PlanExecutionCoordinator _planCoordinator =
      PlanExecutionCoordinator(
        policy: _policy,
        router: _router,
        executor: _executor,
        runToolGuarded: runToolGuarded,
        executeWithTimeout: _executeWithTimeout,
        executionJournal: _executionJournal,
      );

  /// Router de ruta de ejecución (C6): etiqueta cada paso del plan con el
  /// mecanismo más eficiente (Intent / Linux / Accessibility / ...).
  final ActionPathRouter _router;

  /// Transporte inyectable para abrir una app mediante Intent Android.
  /// Producción usa el MethodChannel real; los tests verifican sin simular UI.
  final Future<bool> Function(String packageName) _launchPackage;

  /// Transportes inyectables de Device Actions V1 (A1) — DIP: el dispatcher no
  /// depende del singleton para gestos/acciones globales; los tests inyectan
  /// fakes sin MethodChannel.
  final Future<bool> Function(String action) _globalAction;
  final Future<bool> Function(int x1, int y1, int x2, int y2, {int durationMs})
  _swipe;
  final Future<bool> Function(int x, int y, {int durationMs}) _longPress;

  /// Navegación de sistema allowlisted (A3). null = no conectada.
  final SystemIntentLauncher? _systemIntentLauncher;

  /// A14.5 — lector de estado de plataforma para verificar postcondiciones
  /// no-UI (archivo Linux, app fuera de foco). null = no se puede afirmar
  /// verificación de plataforma (se reporta "solo aceptado").
  final PlatformStateReader? _platformStateReader;

  /// Frontera durable de las acciones no repetibles. En producción siempre se
  /// inyecta desde el composition root; si falta, una acción irreversible se
  /// bloquea antes de tocar el dispositivo.
  final ExecutionJournal? _executionJournal;

  /// Observación factual inmediatamente anterior a cualquier navegación.
  /// Ausente o sin estructura = navegación denegada (fail closed).
  final CurrentSituationSource? _currentSituationSource;

  // ── Manejadores Modulares (Clean Architecture / SRP) ──────────────────────
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
  final AlarmToolHandler _alarmHandler;
  final AppInspectorToolHandler _appInspectorHandler;
  final SystemDiagnosticsToolHandler _diagnosticsHandler;
  final AdbToolHandler _adbHandler;
  final BenchmarkToolHandler _benchmarkHandler;

  /// Verificador de postcondiciones (lazy: comparte el snapshot del
  /// executor). null en tests que no verifican.
  AgentVerifier get verifier =>
      _verifier ??= ActionVerifier(snapshotFn: _executor.snapshot);

  /// Loop de ejecución orquestado (lazy): reutiliza el executor + verifier
  /// existentes — añade retry transitorio + verificación entre intentos a
  /// las acciones de ACT (tap/write) con postcondición. Es la lógica real
  /// inyectada (AgentLoop), no un dispatch single-attempt.
  AgentLoop? _loop;

  AgentLoop get loop =>
      _loop ??= AgentLoop(executor: _executor, verifier: verifier);

  /// Compatibilidad con callers legacy. El presupuesto ya no es global: cada
  /// plan posee su propio [ToolExecutionBudget].
  void resetTurn() {}

  /// Huella observable del mundo para detectar tool loops entre rondas LLM.
  /// No expone el snapshot ni ejecuta acciones; solo resume estado real.
  Future<String> worldFingerprint() async {
    final snapshot = await _executor.snapshot();
    if (snapshot == null) return 'serviceOff';
    final nodes = snapshot.visibleNodes
        .map((node) => '${node.id}|${node.label}|${node.bounds}')
        .join('\u001e');
    return '${snapshot.package}|${snapshot.truncated}|$nodes';
  }

  /// True si [text] es un comando de herramienta del usuario (`@comando`).
  /// `@@` escapa: permite enviar texto literal que empiece con @.
  static bool isToolCommand(String text) {
    final t = text.trim();
    return t.startsWith('@') && !t.startsWith('@@');
  }

  // ── Comandos @ ────────────────────────────────────────────────────────────

  /// Ejecuta un comando `@` del usuario y devuelve el feedback para el chat.
  /// Autoría humana: pasa por la política con [humanInitiated] — una
  /// escritura externa escrita a mano por el usuario NO pide confirmación.
  Future<String> runCommand(
    String command, {
    String? executionId,
    ExecutionCancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final t = command.trim();
    if (t.startsWith('@@')) return t.substring(1);

    // Cada comando `@` es un turno propio: presupuesto fresco. El chat ya
    // resetea en send(); esto cubre cualquier llamador directo.
    resetTurn();

    final space = t.indexOf(RegExp(r'\s'));
    final verb = (space < 0 ? t : t.substring(0, space))
        .substring(1)
        .toLowerCase();
    final rest = space < 0 ? '' : t.substring(space + 1).trim();

    return _dispatchCommandVerb(
      verb,
      rest,
      executionId: executionId,
      cancellation: cancellation,
    );
  }

  // ── Tool-calling LLM ──────────────────────────────────────────────────────

  /// Ejecuta un [ToolCall] del LLM bajo política. Sin [confirmed] ni autoría
  /// humana, una escritura externa devuelve needsConfirmation SIN ejecutarse
  /// (el chat muestra el diálogo y re-llama con confirmed: true).
  ///
  /// [authority] (WA-AUTH-04): autorización standing de una regla del usuario;
  /// solo salta la confirmación si satisface ESTA llamada exacta.
  Future<ToolOutcome> runToolGuarded(
    ToolCall call, {
    bool humanInitiated = false,
    bool confirmed = false,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) => _runToolGuarded(
    call,
    humanInitiated: humanInitiated,
    confirmed: confirmed,
    executionId: executionId,
    executionIntent: executionIntent,
    budget: budget,
    cancellation: cancellation,
    authority: authority,
    onPhysicalEffectDispatched: onPhysicalEffectDispatched,
  );

  /// Variante para TaskPlan: añade la identidad semántica sin cambiar el
  /// contrato legacy de [runToolGuarded]. Ambas políticas se combinan de forma
  /// conservadora antes de llegar al mismo ejecutor.
  Future<ToolOutcome> runSemanticToolGuarded(
    ToolCall call, {
    required String semanticAction,
    bool confirmed = false,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    void Function()? onPhysicalEffectDispatched,
  }) => _runToolGuarded(
    call,
    confirmed: confirmed,
    semanticAction: semanticAction,
    executionId: executionId,
    executionIntent: executionIntent,
    budget: budget,
    cancellation: cancellation,
    onPhysicalEffectDispatched: onPhysicalEffectDispatched,
  );

  Future<ToolOutcome> _runToolGuarded(
    ToolCall call, {
    bool humanInitiated = false,
    bool confirmed = false,
    String? semanticAction,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) async {
    cancellation?.throwIfCancelled();
    final runBudget = budget ?? ToolExecutionBudget();
    final decision = _policy.decide(
      call.tool,
      stepsUsed: runBudget.stepsUsed,
      humanInitiated: humanInitiated,
      confirmed: confirmed,
      semanticAction: semanticAction,
    );
    if (decision.denied) {
      // Herramienta fuera del registro: el modelo ve la lista completa y
      // puede autocorregirse en la siguiente ronda.
      var feedback = '[policy] ${decision.reason}.';
      if (decision.tool == null) {
        final names = _policy.registry.all.map((t) => t.name).join(', ');
        feedback += ' Disponibles: $names.';
      }
      return ToolOutcome(verdict: PolicyVerdict.denied, feedback: feedback);
    }
    final tool = decision.tool!;
    final missingInputs = tool.requiredInputs.where(
      (input) => !call.hasInput(input),
    );
    if (missingInputs.isNotEmpty) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[policy] "${tool.name}" requiere ${missingInputs.join(', ')}.',
      );
    }
    if (decision.needsConfirmation) {
      // WA-AUTH-04: la autoridad standing de una regla salta la confirmación
      // SOLO para la acción exacta autorizada (tool + texto fijo). Cualquier
      // otra llamada del plan conserva su confirmación.
      final standingGranted =
          authority != null &&
          authority.satisfiesCall(call.tool, call.textArg ?? '');
      if (!standingGranted) {
        return ToolOutcome(
          verdict: PolicyVerdict.needsConfirmation,
          pendingCall: call,
          feedback:
              '[policy] "${tool.name}" (${tool.description.toLowerCase()}) — requiere tu confirmación.',
        );
      }
    }
    final contextLockFailure = await _notificationHandler.validateContextLock(
      call,
      tool,
      authority: authority,
    );
    if (contextLockFailure != null) return contextLockFailure;
    final semanticRisk = semanticAction == null
        ? null
        : automationSemanticPolicy(semanticAction)?.risk;
    final isAppLauncher =
        call.tool == 'launch_app' ||
        call.tool == 'open_app' ||
        call.tool == 'abrir' ||
        call.tool == 'launch';
    final navigates =
        !isAppLauncher &&
        (tool.semanticPolicy.risk == SemanticActionRisk.navigation ||
            semanticRisk == SemanticActionRisk.navigation);
    if (navigates) {
      final source = _currentSituationSource;
      if (source == null) {
        return const ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[currentSituationUnavailable] Navegación bloqueada: no hay fuente de situación actual.',
        );
      }
      final CurrentSituation? situation;
      try {
        situation = await source();
      } on Object catch (error) {
        return ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[currentSituationUnavailable] Navegación bloqueada: no se pudo observar la situación actual ($error).',
        );
      }
      if (situation == null || !situation.hasStructuralEvidence) {
        return const ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[currentSituationUnavailable] Navegación bloqueada: no existe evidencia estructural de la superficie actual.',
        );
      }
    }
    if (tool.irreversible) {
      return _planCoordinator.runIrreversibleTool(
        call,
        tool,
        runBudget,
        executionId: executionId,
        executionIntent: executionIntent,
        allowPreviouslyUncertain: confirmed && executionIntent != null,
        cancellation: cancellation,
        onPhysicalEffectDispatched: onPhysicalEffectDispatched,
      );
    }
    if (tool.risk != ToolRisk.none && tool.risk != ToolRisk.read) {
      onPhysicalEffectDispatched?.call();
    }
    final feedback = await _executeWithTimeout(
      call,
      tool,
      runBudget,
      cancellation: cancellation,
    );
    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: feedback,
      executionStatus: PlanExecutionCoordinator.executionStatusFor(feedback),
    );
  }

  /// Resultado de ejecutar un plan multi-paso ([runPlanGuarded]).
  Future<PlanOutcome> runPlanGuarded(
    List<ToolCall> plan, {
    bool humanInitiated = false,
    ActionConfirmation? confirmation,
    String? executionId,
    bool confirmed = false,
    ExecutionCancellationToken? cancellation,
    void Function(int stepIndex)? onStep,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) => _planCoordinator.runPlanGuarded(
    plan,
    humanInitiated: humanInitiated,
    confirmation: confirmation,
    executionId: executionId,
    confirmed: confirmed,
    cancellation: cancellation,
    onStep: onStep,
    authority: authority,
    onPhysicalEffectDispatched: onPhysicalEffectDispatched,
  );

  /// Compatibilidad: ejecuta bajo política y degrada el estado de
  /// confirmación a texto (llamadores que no manejan el diálogo).
  Future<String> runTool(ToolCall call) async {
    resetTurn();
    final outcome = await runToolGuarded(call);
    return outcome.feedback;
  }

  /// Ejecución real con timeout del registro.
  Future<String> _executeWithTimeout(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget, {
    ExecutionCancellationToken? cancellation,
  }) async {
    budget.recordExecution();
    final explicitTimeoutSeconds = call.args?['timeout'] is num
        ? (call.args!['timeout'] as num).toInt()
        : int.tryParse('${call.args?['timeout']}');
    final Duration effectiveTimeout;
    if (call.tool.toLowerCase() == 'linux.run' &&
        explicitTimeoutSeconds != null &&
        explicitTimeoutSeconds > 0) {
      effectiveTimeout = Duration(
        seconds: explicitTimeoutSeconds.clamp(1, 600),
      );
    } else {
      effectiveTimeout = tool.timeout;
    }
    debugPrint(
      '[agent-policy] tool=${tool.name} risk=${tool.risk.name} '
      'steps=${budget.stepsUsed} timeout=${effectiveTimeout.inMilliseconds}ms',
    );
    try {
      return await _executeTool(call).timeout(
        effectiveTimeout,
        onTimeout: () {
          // AUT-P1-07: Señalizar cancelación física en el token ante vencimiento
          cancellation?.cancel();
          if (tool.risk == ToolRisk.none || tool.risk == ToolRisk.read) {
            return '[timeout] "${tool.name}" excedió ${effectiveTimeout.inSeconds}s.';
          }
          return '[timeoutOutcomeUnknown] "${tool.name}" excedió '
              '${effectiveTimeout.inSeconds}s. El caller dejó de esperar, pero la '
              'operación nativa puede seguir activa; resultado desconocido.';
        },
      );
    } catch (e) {
      return '[error] "${tool.name}" falló: $e';
    }
  }
}

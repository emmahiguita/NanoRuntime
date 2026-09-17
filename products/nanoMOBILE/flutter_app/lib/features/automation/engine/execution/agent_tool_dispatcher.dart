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
import 'handlers/device_system_handler.dart';
import 'handlers/linux_tool_handler.dart';
import 'handlers/mcp_tool_handler.dart';
import 'handlers/notification_tool_handler.dart';
import 'handlers/semantic_linux_tool_handler.dart';
import 'handlers/shizuku_tool_handler.dart';
import 'handlers/ui_tool_handler.dart';
import 'handlers/web_tool_handler.dart';
import 'platform_verification.dart';
import 'plan_execution_coordinator.dart';
import 'tool_call.dart';
import 'tool_outcome.dart';
import 'tool_registry.dart';

export 'agent_tool_protocol.dart';
export 'handlers/browser_agent_tool_handler.dart';
export 'handlers/device_system_handler.dart';
export 'handlers/linux_tool_handler.dart';
export 'handlers/mcp_tool_handler.dart';
export 'handlers/notification_tool_handler.dart';
export 'handlers/shizuku_tool_handler.dart';
export 'handlers/ui_tool_handler.dart';
export 'handlers/web_tool_handler.dart';
export 'plan_execution_coordinator.dart';
export 'tool_call.dart';
export 'tool_loop_detector.dart';
export 'tool_outcome.dart';

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

    final ToolCall? call;
    switch (verb) {
      case 'pantalla':
      case 'screen':
        call = const ToolCall(tool: 'screen');
      // A16 — extrae TODO el texto visible (observación de contenido, no solo
      // el top de nodos). Base de "dime qué dice esta página".
      case 'leer':
      case 'leer_pantalla':
        return _uiHandler.readScreenText();
      case 'resolver':
      case 'resolve':
        call = ToolCall(tool: 'resolve', selector: rest);
      case 'tap':
      case 'tocar':
        call = ToolCall(tool: 'tap', selector: rest);
      case 'escribir':
      case 'write':
        // Sintaxis: `texto | selector` (el texto puede contener espacios).
        final sep = rest.lastIndexOf(' | ');
        if (sep < 0) {
          return 'Sintaxis: @escribir <texto> | <selector>. Ej: @escribir wifi | editable=true';
        }
        call = ToolCall(
          tool: 'write',
          text: rest.substring(0, sep).trim(),
          selector: rest.substring(sep + 3).trim(),
        );
      case 'back':
      case 'atras':
      case 'atrás':
        call = const ToolCall(tool: 'back');
      case 'notificaciones':
      case 'notifications':
        call = const ToolCall(tool: 'notifications');
      case 'bateria':
      case 'battery':
      case 'dispositivo':
      case 'device_state':
      case 'wifi':
      case 'red':
        return _deviceHandler.deviceState();
      case 'diagnostics':
      case 'device.diagnostics':
      case 'device_diagnostics':
        return _mcpHandler.handleMcpCommand(
          'call device.diagnostics',
          runGuarded: runToolGuarded,
          executionId: executionId,
          cancellation: cancellation,
        );
      case 'git':
        return (await runToolGuarded(
          ToolCall(
            tool: 'linux.run',
            args: {'command': rest.isEmpty ? 'git status' : 'git $rest'},
          ),
          humanInitiated: true,
          executionId: executionId,
          cancellation: cancellation,
        )).feedback;
      case 'home':
      case 'inicio':
        call = const ToolCall(tool: 'home');
      case 'recents':
      case 'recientes':
        call = const ToolCall(tool: 'recents');
      case 'sombra':
        call = const ToolCall(tool: 'open_notifications');
      case 'quick_settings':
      case 'ajustes_rapidos':
        call = const ToolCall(tool: 'open_quick_settings');
      // A14.5 — informe ejecutivo factual de capacidades locales, soberanía de
      // datos y déficits de seguridad. No necesita LLM: lee el SystemGraph real
      // + estado de permisos + Shizuku. Autoría humana (pasa la política).
      case 'capacidades':
      case 'capabilities':
      case 'resumen':
        return _deviceHandler.runCapabilitiesReport();
      // A16 — entrada por voz: transcribe y devuelve el texto.
      case 'escuchar':
      case 'voz':
        return _deviceHandler.listenVoice();
      // A16 — salida por voz (TTS): habla el texto.
      case 'habla':
        return _deviceHandler.speak(rest);
      // A14.5 — "acción que solicite permisos para continuar".
      case 'conceder':
        return _deviceHandler.runGrantPermission(rest);
      case 'conceder_accessibility':
        return _deviceHandler.runGrantPermission('accessibility');
      case 'conceder_notificaciones':
        return _deviceHandler.runGrantPermission('notificaciones');
      case 'conceder_archivos':
        return _deviceHandler.runGrantPermission('archivos');
      case 'conceder_runtime':
        return _deviceHandler.runGrantPermission('runtime');
      case 'conceder_shizuku':
        return _shizukuHandler.grantShizuku();
      // A14.5 — contestar una notificación desde el chat con control humano.
      case 'responder':
      case 'reply':
        return _notificationHandler.respond(rest);
      case 'cuenta':
      case 'mi_cuenta':
      case 'google_account':
        return _webHandler.getGoogleAccountInfo();
      case 'ip':
      case 'mi_ip':
        return _webHandler.fetchIp();
      case 'web':
      case 'fetch':
        return _webHandler.fetchWeb(rest);
      case 'url':
      case 'navegar':
        final u = rest.trim();
        if (u.isEmpty) {
          return 'Sintaxis: @url <enlace>. Ej: @url https://google.com';
        }
        final full = u.startsWith('http://') || u.startsWith('https://')
            ? u
            : 'https://$u';
        return _webHandler.openUrl(full);
      case 'buscar':
      case 'google':
      case 'search':
        return _webHandler.searchKnowledge(rest);
      case 'abrir':
      case 'launch':
      case 'launch_app':
        return _deviceHandler.handleOpenAppCommand(
          rest,
          runGuarded: runToolGuarded,
          executionId: executionId,
          cancellation: cancellation,
        );
      case 'mcp':
        return _mcpHandler.handleMcpCommand(
          rest,
          runGuarded: runToolGuarded,
          executionId: executionId,
          cancellation: cancellation,
        );
      case 'gemini':
        return _browserAgentHandler.handleCommand(
          rest.isNotEmpty ? '@gemini $rest' : '@gemini .',
        );
      case 'gpt':
      case 'chatgpt':
        return _browserAgentHandler.handleCommand(
          rest.isNotEmpty ? '@chatgpt $rest' : '@chatgpt .',
        );
      case 'deepseek':
        return _browserAgentHandler.handleCommand(
          rest.isNotEmpty ? '@deepseek $rest' : '@deepseek .',
        );
      case 'claude':
        return _browserAgentHandler.handleCommand(
          rest.isNotEmpty ? '@claude $rest' : '@claude .',
        );
      case 'browser_ai':
        return _browserAgentHandler.handleCommand(
          rest.isNotEmpty ? '@browser_ai $rest' : '@browser_ai .',
        );
      default:
        return 'Comando desconocido "@$verb". Disponibles: @ip, @gemini <prompt>, @gpt <prompt>, @deepseek <prompt>, @claude <prompt>, @browser_ai, @web <url>, @url <enlace>, @buscar <consulta>, @abrir <app>, @mcp <list|call>, @pantalla, @leer_pantalla, @resolver <selector>, @tap <selector>, @escribir <texto> | <selector>, @notificaciones, @responder [indice] <texto>, @back, @home, @recents, @sombra, @quick_settings, @capacidades, @conceder <permiso|shizuku>.';
    }
    return (await runToolGuarded(
      call,
      humanInitiated: true,
      executionId: executionId,
      cancellation: cancellation,
    )).feedback;
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
    final feedback = await _executeWithTimeout(call, tool, runBudget);
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
    ToolExecutionBudget budget,
  ) async {
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

  /// Ejecución de la herramienta delegada a los handlers especializados.
  Future<String> _executeTool(ToolCall call) async {
    switch (call.tool) {
      case 'screen':
        if (call.args?['readText'] == true || call.args?['mode'] == 'text') {
          return _uiHandler.readScreenText();
        }
        return _uiHandler.describeScreen();
      case 'read_screen':
        return _uiHandler.readScreenText();
      case 'resolve':
        if (call.selectorArg == null || call.selectorArg!.isEmpty) {
          return '[tool] resolve requiere "selector".';
        }
        return _uiHandler.resolve(call.selectorArg!);
      case 'tap':
        if (call.selectorArg == null || call.selectorArg!.isEmpty) {
          return '[tool] tap requiere "selector".';
        }
        return _uiHandler.tap(call);
      case 'write':
        if (call.selectorArg == null || call.selectorArg!.isEmpty) {
          return '[tool] write requiere "selector".';
        }
        return _uiHandler.write(call);
      case 'back':
        return _uiHandler.back(call);
      case 'home':
        return _uiHandler.navigate(call, 'Pantalla de inicio', 'home');
      case 'recents':
        return _uiHandler.navigate(call, 'Recientes', 'recents');
      case 'open_notifications':
        return _uiHandler.navigate(call, 'Sombra de notificaciones', 'notifications');
      case 'open_quick_settings':
        return _uiHandler.navigate(call, 'Ajustes rápidos', 'quick_settings');
      case 'swipe':
        return _uiHandler.doSwipe(call);
      case 'scroll':
        return _uiHandler.doScroll(call);
      case 'long_press':
        return _uiHandler.doLongPress(call);
      case 'open_system':
        return _uiHandler.openSystem(call);
      case 'open_url':
        final urlArg = (call.textArg ?? call.selectorArg ?? '').trim();
        if (urlArg.isEmpty) {
          return '[tool] open_url requiere <url>.';
        }
        final pkgArg = (call.args?['packageName'] as String?)?.trim();
        return _webHandler.openUrl(urlArg, packageName: pkgArg);
      case 'fetch_web':
      case 'web_fetch':
      case 'http_get':
        final urlArg =
            (call.textArg ??
                    call.selectorArg ??
                    (call.args?['url'] as String?) ??
                    '')
                .trim();
        if (urlArg.isEmpty) {
          return '[tool] fetch_web requiere <url>.';
        }
        return _webHandler.fetchWeb(urlArg);
      case 'search_knowledge':
      case 'search_web':
        final q =
            (call.textArg ??
                    call.selectorArg ??
                    (call.args?['query'] as String?) ??
                    '')
                .trim();
        if (q.isEmpty) {
          return '[tool] search_knowledge requiere "query" o texto.';
        }
        return _webHandler.searchKnowledge(q);
      case 'browser_ai_query':
      case 'reverse_agent_query':
        final provider =
            (call.args?['provider'] as String?)?.trim() ?? 'gemini';
        final prompt =
            (call.args?['prompt'] as String?) ??
            call.textArg ??
            call.selectorArg ??
            '';
        final headless = call.args?['headless'] != false;
        return _browserAgentHandler.executeQuery(
          provider: provider,
          prompt: prompt,
          headless: headless,
        );
      case 'launch_app':
        final packageName = call.packageNameArg?.trim() ?? '';
        if (packageName.isEmpty) {
          return '[tool] launch_app requiere args {packageName}.';
        }
        final launched = await _launchPackage(packageName);
        if (!launched) {
          return '[launchFailed] Android no pudo abrir el paquete '
              '"$packageName".';
        }
        final expectation = _uiHandler
            .expectationFor(call)
            .copyWith(expectedPackage: packageName);
        return _uiHandler.verifiedFeedback(
          'Aplicación abierta por Intent: $packageName.',
          expectation,
        );
      case 'notifications':
        return _notificationHandler.listNotifications();
      case 'device_state':
        return _deviceHandler.deviceState();
      case 'shizuku_query_package':
        final pkgArg = (call.textArg ?? call.selectorArg ?? '').trim();
        if (pkgArg.isEmpty) return '[tool] shizuku_query_package requiere <packageName>.';
        return _shizukuHandler.queryPackage(pkgArg);
      case 'force_stop_package':
        final pkgArg2 = (call.textArg ?? call.selectorArg ?? '').trim();
        if (pkgArg2.isEmpty) return '[tool] force_stop_package requiere <packageName>.';
        return _shizukuHandler.forceStop(pkgArg2, platformStateReader: _platformStateReader);
      case 'install_package':
        final apkArg = (call.textArg ?? call.selectorArg ?? '').trim();
        if (apkArg.isEmpty) return '[tool] install_package requiere <apkPath>.';
        return _shizukuHandler.install(apkArg);
      case 'grant_specific_permission':
        final pkgArg3 = (call.textArg ?? call.selectorArg ?? '').trim();
        final permArg = ((call.args?['permission'] as String?) ?? '').trim();
        if (pkgArg3.isEmpty || permArg.isEmpty) {
          return '[tool] grant_specific_permission requiere <packageName> y permission.';
        }
        return _shizukuHandler.grantPermission(pkgArg3, permArg);
      case 'reply_notification':
        final key = call.keyArg?.trim() ?? '';
        final text = call.textArg?.trim() ?? '';
        if (key.isEmpty) return '[tool] reply_notification requiere "key".';
        if (text.isEmpty) return '[tool] reply_notification requiere "text".';
        final rawActionIndex = call.args?['actionIndex'];
        final rawPostTime = call.args?['postTime'];
        return _notificationHandler.replyNotification(
          key: key,
          text: text,
          actionIndex: rawActionIndex is num ? rawActionIndex.toInt() : null,
          remoteInputKey: (call.args?['remoteInputKey'] as String?)?.trim(),
          contextFingerprint: (call.args?['contextFingerprint'] as String?)?.trim(),
          postTime: rawPostTime is num ? rawPostTime.toInt() : null,
        );
      case 'linux.list':
      case 'linux.readFile':
      case 'linux.readfile':
      case 'linux.writeFile':
      case 'linux.writefile':
      case 'linux.run':
        return _linuxHandler.executeLinuxTool(call, registry);
      case 'mcp.read':
      case 'mcp.device':
      case 'mcp.externalWrite':
      case 'mcp.privileged':
        return _mcpHandler.executeMcpTool(call);
      default:
        if (call.tool.toLowerCase().startsWith('nano.linux.')) {
          return _semanticLinuxHandler.handleToolCall(call);
        }
        return '[tool] Herramienta desconocida "${call.tool}".';
    }
  }
}

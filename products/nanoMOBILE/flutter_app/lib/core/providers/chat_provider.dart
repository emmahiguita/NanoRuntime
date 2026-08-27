import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/automation/engine/agent_dependencies.dart';
import '../../features/automation/engine/execution/agent_tool_dispatcher.dart';
import '../../features/automation/engine/memory/experience_cache.dart';
import '../../features/automation/engine/execution/nano_flow.dart';
import '../services/device_info.dart';
import '../services/chat_history_store.dart';
import '../services/chat_system_prompt.dart';
import '../services/llm_engine_client.dart';
import '../services/nano_runtime_api.dart';
import '../services/runtime_engine.dart';
import '../../features/automation/engine/voice/voice_backends.dart';
import '../../features/automation/engine/voice/voice_runtime.dart';
import '../../features/automation/engine/voice/conversation/conversational_world_state.dart';
import '../../features/automation/engine/voice/conversation/grounding_resolver.dart';
import '../models/chat_models.dart';
import '../models/catalog_models.dart';
import 'settings_provider.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart'
    show AutomationResultStatus;
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/application/automation_planner_provider.dart';
import 'package:nanoai/features/automation/engine/memory/object_memory.dart'
    show NanoObjectMemory;
import 'package:nanoai/features/automation/engine/perception/perception_mux.dart'
    show PerceptionMux;
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart'
    show defaultDeterministicCatalog;
import 'package:nanoai/features/automation/engine/planning/linux_voice_command_parser.dart';
import 'package:nanoai/features/automation/ledger/action_ledger_provider.dart';

// ================================================================
// Chat State and Notifier
// ================================================================

/// Propiedad explícita de un único stream HTTP.
///
/// Una ronda vieja puede terminar después de que el usuario pulse Detener y
/// empiece otra. La identidad evita que su `finally` cierre el cliente de la
/// ronda nueva o limpie su request id.
class _StreamLease {
  _StreamLease({
    required this.generationId,
    required this.client,
    required this.requestId,
  });

  final int generationId;
  final http.Client client;
  final String requestId;
  bool released = false;
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  // Interfaz de inferencia del motor: propiedad de RuntimeEngineNotifier
  // (único dueño del ciclo de vida). Nadie crea LLMEngineClient directo.
  LLMEngineClient get _engine =>
      _ref.read(runtimeEngineProvider.notifier).client;
  // Cliente HTTP de la generación streaming en curso. Se cierra para cancelar.
  _StreamLease? _activeStream;
  int _generationSequence = 0;
  int? _activeGenerationId;
  // Monitoreo de conexiones activas para detectar memory leaks
  int _activeConnections = 0;
  // Cancelación cooperativa: STOP o un segundo envío anulan la generación en curso.
  bool _generationCancelled = false;
  // Timer de carga de modelo: cancelable para que solo el último
  // modelo seleccionado pueda transicionar a ready.
  Timer? _loadTimer;
  int _modelSelectionRevision = 0;
  // Flush periódico del texto streaming: agrupa tokens (~32ms) para evitar
  // un rebuild de la lista de mensajes por cada token del motor.
  Timer? _flushTimer;
  bool _historyTouched = false;
  final ChatHistoryStore _historyStore;
  String _sessionId = _newSessionId();

  /// Contador monótono: garantiza unicidad entre sesiones generadas en el
  /// mismo microsegundo (rotación inmediata al cambiar de modelo).
  static int _sessionSeq = 0;

  static String _newSessionId() =>
      'chat-${DateTime.now().microsecondsSinceEpoch}-${++_sessionSeq}';

  /// Gate R5 — session_id activa. Visible para tests: verificar que cambiar
  /// de modelo rota la sesión (el KV viejo nunca se reutiliza).
  @visibleForTesting
  String get sessionId => _sessionId;

  /// Tiempo maximo sin tokens antes de abortar el stream como fallo real.
  static const Duration _streamIdleTimeout = Duration(seconds: 45);

  /// Ventana de historial conversacional inteligente multi-turno.
  static const int _maxHistoryMessages = 10;
  static const int _maxHistoryChars = 1200;
  static const int _maxUserChars = 2000;
  static const int _maxAttachmentChars = 1500;
  static const int _maxToolTraceChars = 900;

  /// Máximo de rondas de herramienta por mensaje del usuario: evita bucles
  /// infinitos si el modelo insiste en llamar tools sin concluir.
  static const int _maxToolRounds = 2;

  /// Genera un system prompt dinámico con contexto en tiempo real
  /// y telemetría 100% real del hardware (sin simulación).
  String _buildSystemPrompt() {
    return ChatSystemPrompt.build(
      registry: _tools.registry,
      modelName: state.activeModel,
      now: DateTime.now(),
      device: DeviceInfo.read(),
    );
  }

  /// Ejecutor de herramientas del chat (comandos `@` y tool-calling del LLM).
  final AgentToolDispatcher _tools;

  /// Memoria de flujos verificados (C7) — null = flujo determinista off
  /// (tests sin inyección mantienen el comportamiento actual).
  final ExperienceCache? _experienceCache;

  /// Ejecutor de flujos deterministas (C8) — null = off.
  final NanoFlowExecutor? _flowExecutor;

  /// Único dueño del ciclo de ejecución (policy + cache + flow + dispatcher).
  /// Cacheado: se construye una vez con las dependencias inyectadas.
  AutomationCoordinator? _coordinatorCache;
  AutomationCoordinator get _coordinator =>
      _coordinatorCache ??= AutomationCoordinator(
        dispatcher: _tools,
        mode: () => _ref.read(settingsProvider).agentAutomationMode,
        cache: _experienceCache,
        flowExecutor: _flowExecutor,
        ledger: _ref.read(actionLedgerProvider),
        planner: _ref.read(llmAutomationPlannerProvider),
        verifyGoal: _ref.read(goalVerifierProvider).verify,
        catalog: defaultDeterministicCatalog,
        objectMemory: const NanoObjectMemory(),
        perceptionMux: const PerceptionMux(),
      );

  // ── Confirmación de herramienta (política externalWrite) ──
  // Cuando el tool-calling del LLM pide una escritura externa, la política
  // pausa el turno: se guarda la llamada + contexto de reanudación y la UI
  // muestra el diálogo. approve/reject reanudan la ronda con el resultado.

  /// Llamada pendiente de confirmación (null = nada pendiente).
  ToolCall? _pendingCall;

  /// Contexto para reanudar la ronda tras la decisión del usuario.
  String _pendingUserText = '';
  List<String> _pendingTrace = const [];
  String _pendingCallText = '';

  /// Plan multi-paso pendiente de confirmación (null = no hay plan pausado).
  /// Un paso del plan pidió confirmación humana; al aprobar se reanuda el
  /// plan desde [_pendingPlanIndex] (la confirmación cubre solo ese paso).
  List<ToolCall>? _pendingPlan;
  int? _pendingPlanIndex;

  /// T1.7 — último archivo creado/escrito por voz (contexto para "léelo").
  /// Solo se puebla tras un write VERIFICADO (FileExists + FileContentContains).
  /// null = sin contexto; "léelo" no inventa target.
  String? _lastLinuxFilePath;

  ChatNotifier(
    this._ref, {
    AgentToolDispatcher? toolDispatcher,
    ExperienceCache? experienceCache,
    NanoFlowExecutor? flowExecutor,
    ChatHistoryStore? historyStore,
  }) : _tools = toolDispatcher ?? AgentToolDispatcher(),
       _experienceCache = experienceCache,
       _flowExecutor = flowExecutor,
       _historyStore = historyStore ?? ChatHistoryStore(),
       super(
         ChatState(
           availableModels: [for (final m in NeuralCatalog.models) m.name],
         ),
       ) {
    _restoreModel();
    _restoreMessages();
  }

  /// Test-only: emits a fixed state without IO.
  @visibleForTesting
  ChatNotifier.fixed(
    Ref ref,
    super.initial, {
    AgentToolDispatcher? toolDispatcher,
    ExperienceCache? experienceCache,
    NanoFlowExecutor? flowExecutor,
    ChatHistoryStore? historyStore,
  }) : _ref = ref,
       _tools = toolDispatcher ?? AgentToolDispatcher(),
       _experienceCache = experienceCache,
       _flowExecutor = flowExecutor,
       _historyStore = historyStore ?? ChatHistoryStore();

  /// Restaura la última selección de modelo para que sobreviva al reinicio.
  Future<void> _restoreModel() async {
    final revision = _modelSelectionRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('nanoai_active_model');
      final savedPath = prefs.getString('nanoai_active_model_path');
      if (saved == null || saved.isEmpty) return;
      // Un nombre de catálogo no demuestra que el GGUF esté instalado. Para
      // reanudar inferencia local hace falta una ruta persistida y existente;
      // de lo contrario la UI anunciaría un modelo que no puede arrancar.
      final installedModel =
          savedPath != null &&
          savedPath.trim().isNotEmpty &&
          await File(savedPath).exists();
      if (!installedModel) {
        await prefs.remove('nanoai_active_model');
        await prefs.remove('nanoai_active_model_path');
        return;
      }
      if (!mounted || revision != _modelSelectionRevision) return;
      state = state.copyWith(
        activeModel: saved,
        activeModelPath: savedPath,
        connection: ModelConnectionState.loadingModel,
      );
      await _checkEngine(model: saved, expectedRevision: revision);
    } catch (e) {
      debugPrint(
        '[chat_provider] Persistencia no disponible, usando default: $e',
      );
    }
  }

  Future<void> _persistMessages() => _historyStore.save(state.messages);

  /// Carga el historial desde SharedPreferences. Solo se llaman durante init
  /// para no pisar el estado en vivo con datos stale.
  Future<void> _restoreMessages() async {
    try {
      final messages = await _historyStore.restore();
      if (!mounted || _historyTouched) return;
      state = state.copyWith(messages: messages);
    } catch (_) {
      /* datos corruptos o no disponibles: ignorar */
    }
  }

  /// Consulta el estado real del motor (canal + /health + /api/status) y
  /// transiciona a ready/noModel/error según la evidencia. Degraded (motor
  /// vivo sin GGUF) se muestra honestamente como noModel.
  Future<void> _checkEngine({String? model, int? expectedRevision}) async {
    final engine = _ref.read(runtimeEngineProvider.notifier);
    await engine.refresh();
    if (!mounted ||
        (expectedRevision != null &&
            expectedRevision != _modelSelectionRevision)) {
      return;
    }
    final name = model ?? state.activeModel;
    state = state.copyWith(
      activeModel: name,
      connection: switch (engine.phase) {
        EnginePhase.ready => ModelConnectionState.ready,
        EnginePhase.degraded => ModelConnectionState.noModel,
        _ => ModelConnectionState.error,
      },
      engineOnline: engine.isLive,
    );
  }

  /// Máximo de adjuntos simultáneos en el composer. El cuarto desplaza al
  /// más antiguo (FIFO) — nunca se bloquea el gesto de adjuntar.
  static const int _maxAttachments = 3;

  /// Agrega un adjunto pendiente. Un nombre repetido reemplaza el anterior
  /// (mismo archivo re-elegido = última versión).
  void addAttachment(ChatAttachment attachment) {
    // CORRECCIÓN LEVE: Validar tamaño del contenido antes de aceptar
    const maxAttachmentSizeBytes = 500000; // 500KB límite
    final contentSize = attachment.content.length * 2; // Aproximación UTF-16

    if (contentSize > maxAttachmentSizeBytes) {
      debugPrint(
        '[chat_provider] Adjunto rechazado: demasiado grande ($contentSize bytes)',
      );
      return;
    }

    final current = [...state.attachments]
      ..removeWhere((a) => a.name == attachment.name);
    if (current.length >= _maxAttachments) {
      current.removeAt(0);
    }
    current.add(attachment);
    state = state.copyWith(attachments: current);
  }

  /// Quita un adjunto pendiente por nombre (chip con X en el composer).
  void removeAttachment(String name) {
    state = state.copyWith(
      attachments: state.attachments.where((a) => a.name != name).toList(),
    );
  }

  /// Re-comprueba la conectividad real con el motor llama.cpp y, si hay un
  /// modelo instalado, lo ARRANCA (ensureReady) en lugar de solo sondear:
  /// el botón Reintentar del empty state rompe el deadlock de arranque.
  Future<void> refreshEngine() async {
    final engine = _ref.read(runtimeEngineProvider.notifier);
    if (state.activeModelPath != null) {
      final ready = await engine.ensureReady(modelPath: state.activeModelPath);
      if (!mounted) return;
      state = state.copyWith(
        engineOnline: ready || engine.isLive,
        connection: ready
            ? ModelConnectionState.ready
            : ModelConnectionState.error,
      );
      return;
    }
    await engine.refresh();
    if (!mounted) return;
    state = state.copyWith(engineOnline: engine.isLive);
  }

  // ── Confirmación de herramienta (política §12) ────────────────────────────

  /// El usuario aprobó la herramienta pendiente: se ejecuta con
  /// `confirmed: true` y la ronda continúa con el resultado en el trace.
  /// Si el pendiente era un plan multi-paso, se reanuda DESDE el paso
  /// aprobado (la confirmación cubre solo ese paso; el resto conserva su
  /// política).
  Future<void> approvePendingTool() async {
    final userText = _pendingUserText;
    final trace = _pendingTrace;
    final callText = _pendingCallText;
    final plan = _pendingPlan;

    if (plan != null) {
      // Plan multi-paso en pausa: reanudar desde el paso aprobado.
      final from = _pendingPlanIndex ?? 0;
      final resume = plan.sublist(from);
      _pendingPlan = null;
      _pendingPlanIndex = null;
      _pendingCall = null;
      if (!mounted) return;
      state = state.copyWith(
        generating: true,
        pendingTool: null,
        pendingToolDescription: null,
      );
      final generationId = _beginGeneration();
      final outcome = await _coordinator.runPlan(resume, confirmed: true);
      if (!_isGenerationCurrent(generationId)) return;
      if (outcome.pauseIndex != null && outcome.pauseCall != null) {
        // Otro paso del plan pidió confirmación → nueva pausa.
        _pendingPlan = resume;
        _pendingPlanIndex = outcome.pauseIndex;
        state = state.copyWith(
          generating: false,
          pendingTool: outcome.pauseCall!.tool,
          pendingToolDescription: outcome.summary,
        );
        return;
      }
      await _generateRound(
        userText,
        [...trace, callText, outcome.summary],
        const [],
        generationId,
      );
      return;
    }

    final call = _pendingCall;
    if (call == null || state.pendingTool == null) return;
    _pendingCall = null;

    // CORRECCIÓN CRÍTICA: Verificar mounted antes de actualizar estado
    if (!mounted) return;
    state = state.copyWith(
      generating: true,
      pendingTool: null,
      pendingToolDescription: null,
    );

    final generationId = _beginGeneration();
    final outcome = await _coordinator.runTool(call, confirmed: true);
    if (!_isGenerationCurrent(generationId)) return;

    // CORRECCIÓN CRÍTICA: Verificar mounted nuevamente antes de continuar
    if (!mounted) return;
    await _generateRound(
      userText,
      [...trace, callText, outcome.feedback],
      const [],
      generationId,
    );
  }

  /// El usuario rechazó la herramienta pendiente: nada se ejecuta y la ronda
  /// continúa con el rechazo en el trace (el modelo ve el motivo y cierra).
  Future<void> rejectPendingTool() async {
    final userText = _pendingUserText;
    final trace = _pendingTrace;
    final callText = _pendingCallText;
    final plan = _pendingPlan;
    final call = _pendingCall;
    if ((call == null && plan == null) || state.pendingTool == null) return;
    final toolName = plan != null
        ? (plan[_pendingPlanIndex ?? 0].tool)
        : call!.tool;
    _pendingPlan = null;
    _pendingPlanIndex = null;
    _pendingCall = null;

    // CORRECCIÓN CRÍTICA: Verificar mounted antes de actualizar estado
    if (!mounted) return;
    state = state.copyWith(
      generating: true,
      pendingTool: null,
      pendingToolDescription: null,
    );

    // CORRECCIÓN CRÍTICA: Verificar mounted antes de continuar generación
    if (!mounted) return;
    await _startGenerationRound(userText, [
      ...trace,
      callText,
      '🚫 [policy] $toolName cancelada por el usuario (sin confirmación).',
    ], const []);
  }

  /// Envía [text] al motor como mensaje del usuario.
  /// [setInput] es innecesario: `send` recibe el texto directamente.
  ///
  /// El motor es responsabilidad de RuntimeEngineNotifier: si no está listo
  /// (idle/failed), se arranca aquí con ensureReady() antes de generar. Si
  /// queda degraded (motor vivo sin GGUF), se inserta un error honesto en
  /// el chat en lugar de una generación que siempre fallaría con 503.
  /// A16 — entrada por voz: transcribe y envía como orden (MISMO flujo que un
  /// texto escrito). Usa el VoiceSessionManager (máquina de estados + contexto
  /// conversacional) sobre los backends Android. La voz es I/O del MISMO agente.
  Future<String?> sendVoiceCommand() async {
    final session = voiceSession;
    final turn = await session.pushToTalk();
    if (turn == null || turn.transcript.trim().isEmpty) return null;
    // Respuesta progresiva (sección 42): ack corto antes de ejecutar, para que
    // el usuario sepa que fue escuchado sin esperar el resultado completo.
    unawaited(session.respond('Voy.'));
    await send(turn.transcript);
    return turn.transcript;
  }

  /// A16 — sesión de voz (state machine + referentes). resolveGoal devuelve el
  /// transcript como goal (el MISMO send() lo ejecuta en el coordinador); la voz
  /// NO crea un segundo agente ni llama al dispatcher directamente.
  VoiceSessionManager get voiceSession =>
      _voiceSessionCache ??= VoiceSessionManager(
        recognition: const AndroidSpeechRecognitionBackend(),
        synthesis: const AndroidSpeechSynthesisBackend(),
        resolveGoal: _resolveVoiceGoal,
      );
  VoiceSessionManager? _voiceSessionCache;

  /// A16 — resuelve pronombres y puebla el world state antes de ejecutar la
  /// orden de voz. "respóndele" se resuelve contra la persona activa grounded;
  /// "a Juan" se recuerda como referente para el siguiente turno.
  Future<String> _resolveVoiceGoal(String transcript) async {
    final session = voiceSession;
    final target = _extractExplicitTarget(transcript);
    if (target != null && target.isNotEmpty) {
      session.world.remember(
        target,
        ResolvedReference(
          entity: target,
          source: ReferenceSource.explicit,
          confidence: 1.0,
          evidence: 'utterance',
          timestamp: DateTime.now(),
        ),
      );
      session.world.setActive(person: target);
    } else {
      // Sin target explícito: poblar desde la notificación más reciente
      // (grounding real con evidencia, no adivinar). "respóndele" → sender.
      final sender = await _latestNotificationSender();
      if (sender != null && sender.isNotEmpty) {
        session.world.setActive(person: sender);
        session.world.remember(
          sender,
          ResolvedReference(
            entity: sender,
            source: ReferenceSource.notification,
            confidence: 0.85,
            evidence: 'notification sender',
            timestamp: DateTime.now(),
          ),
        );
      }
    }
    return const TranscriptResolver().resolveTranscript(
      transcript,
      session.world,
    );
  }

  String? _extractExplicitTarget(String transcript) {
    final m = RegExp(
      r'\ba\s+([A-Za-zÁÉÍÓÚÑáéíóúñ]{2,})',
    ).firstMatch(transcript);
    return m?.group(1);
  }

  /// Sender de la notificación activa más reciente (para grounding de voz).
  Future<String?> _latestNotificationSender() async {
    try {
      final rows = await NanoRuntimeApi.instance.listActiveNotifications();
      for (final raw in rows) {
        if (raw is Map && raw['sender'] is String) {
          final s = (raw['sender'] as String).trim();
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.generating) return;
    _historyTouched = true;

    // A16 — cancelación local de máxima prioridad (sin LLM). "para"/"cancela"
    // detiene la tarea activa del coordinador de forma cooperativa.
    final lowerCmd = t.toLowerCase();
    if (lowerCmd == 'para' ||
        lowerCmd == 'cancela' ||
        lowerCmd == 'detente' ||
        lowerCmd == 'detén' ||
        lowerCmd == 'stop') {
      _coordinator.cancelCurrent();
      final cancelMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: 'Tarea cancelada.',
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, cancelMsg]);
      return;
    }
    // Nuevo turno del usuario: resetea el presupuesto de pasos de la
    // política y descarta cualquier confirmación pendiente vieja (tool o
    // plan multi-paso).
    _coordinator.reset();
    _pendingCall = null;
    _pendingPlan = null;
    _pendingPlanIndex = null;
    if (state.pendingTool != null) {
      state = state.copyWith(pendingTool: null, pendingToolDescription: null);
    }
    final generationId = _beginGeneration();
    // Captura y consume los adjuntos pendientes: viajan SOLO con este
    // mensaje y se inyectan al prompt real de la generación.
    final attachments = state.attachments;
    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      text: t,
      timestamp: DateTime.now(),
      attachmentNames: [for (final a in attachments) a.name],
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      input: '',
      generating: true,
      streamingText: '',
      attachments: const [],
    );
    _persistMessages(); // guardar el user msg inmediatamente

    try {
      // Comandos `@`: ejecución determinista sin LLM. Funcionan incluso con
      // el motor degradado (vivo sin GGUF) — no consumen tokens ni ensureReady.
      if (AgentToolDispatcher.isToolCommand(t)) {
        final result = await _coordinator.runCommand(t);
        if (!_isGenerationCurrent(generationId)) return;
        final toolMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: result,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        );
        state = state.copyWith(
          messages: [...state.messages, toolMsg],
          generating: false,
          streamingText: '',
        );
        _persistMessages();
        return;
      }

      // T1.7 — comandos Linux de voz/texto deterministas (list/write/read),
      // SIN LLM. La voz es solo I/O del MISMO motor; el routing tipado evita
      // raw-shell y mantiene gobernanza + verificación (GoalVerifier).
      final linuxCmd = const LinuxVoiceCommandParser().parse(
        t,
        lastFilePath: _lastLinuxFilePath,
      );
      if (linuxCmd != null) {
        if (!_isGenerationCurrent(generationId)) return;
        final String linuxText;
        if (linuxCmd.call.tool == 'linux.writeFile') {
          // WRITE: verificación completa (FileExists + FileContentContains),
          // NO éxito por exitCode == 0.
          final result = await _coordinator.execute(
            AutomationGoal(text: t, expectation: linuxCmd.expectation),
            plan: [linuxCmd.call],
          );
          if (result.isVerifiedSuccess) {
            _lastLinuxFilePath = linuxCmd.call.text;
            linuxText =
                'Creé ${linuxCmd.call.text} y verifiqué su contenido '
                '(existe y contiene el texto).';
          } else {
            linuxText = 'No se pudo crear ${linuxCmd.call.text}: '
                '${result.reason}';
          }
        } else {
          // READ (list/readFile): el stdout factual ES la respuesta.
          final outcome = await _coordinator.runTool(linuxCmd.call);
          linuxText = outcome.feedback;
        }
        if (!_isGenerationCurrent(generationId)) return;
        final linuxMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: linuxText,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          source: MessageSource.device,
        );
        state = state.copyWith(
          messages: [...state.messages, linuxMsg],
          generating: false,
          streamingText: '',
        );
        _persistMessages();
        return;
      }

      // Camino determinista (C7→C8): flujo verificado en cache, sin LLM.
      // Principio: el LLM no hace el trabajo que un flujo puede hacer.
      final deterministic = await _coordinator.tryDeterministic(t);
      if (!_isGenerationCurrent(generationId)) return;
      if (deterministic != null) {
        final flowResult = deterministic.result;
        if (flowResult.plan.pauseIndex != null) {
          // Primer paso sensible del flow → misma pausa de confirmación que
          // el plan del LLM.
          _pendingPlan = deterministic.steps;
          _pendingPlanIndex = flowResult.plan.pauseIndex;
          _pendingUserText = t;
          _pendingTrace = const [];
          _pendingCallText = '';
          state = state.copyWith(
            generating: false,
            pendingTool: flowResult.plan.pauseCall?.tool,
            pendingToolDescription: flowResult.plan.summary,
          );
          return;
        }
        final feedback = [
          'Objetivo resuelto por flujo verificado (sin LLM):',
          flowResult.plan.summary,
          '[goal] ${flowResult.goal.reason}',
        ].join('\n');
        final flowMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: feedback,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          source: MessageSource.device,
        );
        state = state.copyWith(
          messages: [...state.messages, flowMsg],
          generating: false,
          streamingText: '',
        );
        _persistMessages();
        return;
      }

      // Catálogo estático revisado: intenciones conocidas (por ejemplo leer
      // notificaciones) se ejecutan con herramientas reales y nunca pasan por
      // el planner ni por generación libre del GGUF.
      final known = await _coordinator.tryKnownFlow(t);
      if (!_isGenerationCurrent(generationId)) return;
      if (known != null) {
        final result = known.result;
        if (result.isPaused) {
          _pendingPlan = known.steps;
          _pendingPlanIndex = result.pauseIndex;
          _pendingUserText = t;
          _pendingTrace = const [];
          _pendingCallText = '';
          state = state.copyWith(
            generating: false,
            pendingTool: result.pauseTool,
            pendingToolDescription: result.reason,
          );
          return;
        }
        final knownMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: 'Ejecutado en el dispositivo (sin LLM):\n${result.reason}',
          timestamp: DateTime.now(),
          source: MessageSource.device,
          status:
              const {
                AutomationResultStatus.denied,
                AutomationResultStatus.noPlan,
                AutomationResultStatus.failed,
                AutomationResultStatus.cancelled,
              }.contains(result.status)
              ? MessageStatus.error
              : MessageStatus.sent,
        );
        state = state.copyWith(
          messages: [...state.messages, knownMsg],
          generating: false,
          streamingText: '',
        );
        _persistMessages();
        return;
      }

      // Las acciones deterministas anteriores no dependen del GGUF. La
      // ausencia de modelo sólo bloquea la conversación que realmente necesita
      // inferencia, nunca la lectura nativa del dispositivo.
      if (!state.engineOnline && state.activeModelPath == null) {
        final errorMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text:
              'No hay un modelo seleccionado. Por favor, ve a la pestaña Modelos y selecciona uno para poder chatear.',
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        );
        state = state.copyWith(
          messages: [...state.messages, errorMsg],
          generating: false,
          streamingText: '',
        );
        _persistMessages();
        return;
      }

      final engine = _ref.read(runtimeEngineProvider.notifier);
      final ready = await engine.ensureReady(modelPath: state.activeModelPath);
      if (!_isGenerationCurrent(generationId)) return;
      if (!ready) {
        final degraded = engine.phase == EnginePhase.degraded;
        final errMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: degraded
              ? 'El motor está vivo pero no hay modelo GGUF instalado. Descárgalo desde el catálogo de modelos.'
              : 'El motor no pudo arrancar: ${engine.reason ?? "fallo desconocido"}.',
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        );
        state = state.copyWith(
          messages: [...state.messages, errMsg],
          generating: false,
          streamingText: '',
          connection: degraded
              ? ModelConnectionState.noModel
              : ModelConnectionState.error,
          engineOnline: engine.isLive,
        );
        _persistMessages();
        return;
      }
      state = state.copyWith(
        connection: ModelConnectionState.ready,
        engineOnline: true,
      );
      await _generate(t, attachments, generationId);
    } catch (e, stackTrace) {
      if (!_isGenerationCurrent(generationId)) return;
      debugPrint('[chat_provider] Error preparando el turno: $e');
      debugPrintStack(stackTrace: stackTrace);
      final errorMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: 'No se pudo completar la operación solicitada: $e',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        generating: false,
        streamingText: '',
      );
      _persistMessages();
    }
  }

  /// Construye el historial como lista de turnos role/content para el motor.
  ///
  /// El core nanortime aplica el chat template REAL del GGUF y convierte
  /// estos turnos en bloques nativos del template. Antes la app formateaba
  /// ChatML por su cuenta y el core lo re-encapsulaba como contenido del
  /// turno user: template anidado que hacía al modelo responder vacío o
  /// genérico ("El motor terminó sin emitir texto").
  List<Map<String, String>> _buildHistory(
    List<ChatMessage> history,
    List<String> toolTrace,
  ) {
    final result = <Map<String, String>>[];
    final window = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;
    for (final msg in window) {
      result.add({
        'role': msg.sender == MessageSender.user ? 'user' : 'assistant',
        'content': ChatSystemPrompt.promptClip(msg.text, _maxHistoryChars),
      });
    }
    // Trace de herramientas: la llamada JSON como assistant y el resultado
    // real como user, para que el modelo continúe informado del resultado.
    for (var i = 0; i + 1 < toolTrace.length; i += 2) {
      result.add({
        'role': 'assistant',
        'content': ChatSystemPrompt.promptClip(
          toolTrace[i],
          _maxToolTraceChars,
        ),
      });
      result.add({
        'role': 'user',
        'content':
            'Resultado de la herramienta:\n'
            '${ChatSystemPrompt.promptClip(toolTrace[i + 1], _maxToolTraceChars)}',
      });
    }
    return result;
  }

  /// Neutraliza tokens especiales que podrían cerrar/abrir roles del modelo
  /// cuando provienen de usuario, historial, adjuntos o resultados de tools.

  /// Programa el siguiente flush del texto parcial si no hay uno pendiente.
  void _scheduleStreamFlush(StringBuffer buffer) {
    if (_flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 32), () {
      _flushTimer = null;
      // CORRECCIÓN CRÍTICA: Verificar mounted antes de actualizar estado
      // para evitar race conditions cuando el componente se desmonta
      if (mounted && !_generationCancelled) {
        try {
          state = state.copyWith(streamingText: buffer.toString());
        } catch (e) {
          debugPrint('[chat_provider] Error en flush callback: $e');
        }
      }
    });
  }

  /// Cancela cualquier flush pendiente.
  void _cancelStreamFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  bool _requiresAutonomousToolConfirmation(ToolCall call) =>
      _coordinator.requiresConfirmation(call.tool);

  String _toolConfirmationDescription(ToolCall call) =>
      _coordinator.confirmationDescription(call.tool);

  Future<void> _generate(
    String text,
    List<ChatAttachment> attachments,
    int generationId,
  ) => _generateRound(text, const <String>[], attachments, generationId);

  int _beginGeneration() {
    final generationId = ++_generationSequence;
    _activeGenerationId = generationId;
    _generationCancelled = false;
    return generationId;
  }

  Future<void> _startGenerationRound(
    String text,
    List<String> toolTrace,
    List<ChatAttachment> attachments,
  ) {
    final generationId = _beginGeneration();
    return _generateRound(text, toolTrace, attachments, generationId);
  }

  bool _isGenerationCurrent(int generationId) =>
      mounted && !_generationCancelled && _activeGenerationId == generationId;

  /// Devuelve el historial anterior al turno user actual. En rondas con tools,
  /// el estado ya contiene mensajes assistant con llamadas JSON visibles;
  /// esos mensajes pertenecen al turno en curso y se reinyectan vía toolTrace.
  /// Devuelve el historial ANTES del último mensaje user con [text].
  /// Busca de atrás hacia adelante para capturar el turno actual, no uno
  /// anterior con el mismo texto (evita bug con textos duplicados).
  List<ChatMessage> _historyBeforeCurrentUser(String text) {
    // Buscar el último mensaje user (independientemente del texto) que
    // coincida con el texto actual. Si hay duplicados, el último es el actual.
    for (var i = state.messages.length - 1; i >= 0; i--) {
      final msg = state.messages[i];
      if (msg.sender == MessageSender.user && msg.text == text) {
        return state.messages.sublist(0, i);
      }
    }
    // Fallback: si no se encontró (no debería pasar), excluir el último user.
    final lastUserIdx = state.messages.lastIndexWhere(
      (m) => m.sender == MessageSender.user,
    );
    if (lastUserIdx >= 0) return state.messages.sublist(0, lastUserIdx);
    return state.messages;
  }

  /// Una ronda de generación. [toolTrace] contiene pares
  /// (llamadaJSON, resultado) de herramientas ya ejecutadas en este turno;
  /// se inyectan al prompt como turnos assistant/user para que el modelo
  /// continúe informado del resultado real.
  ///
  /// [attachments] se inyecta al prompt base SOLO en la primera ronda:
  /// el contenido ya está en el contexto de las rondas siguientes.
  Future<void> _generateRound(
    String text,
    List<String> toolTrace,
    List<ChatAttachment> attachments,
    int generationId,
  ) async {
    // El historial YA incluye el turno actual y, si hubo tools, sus trazas
    // visibles. Se excluye todo eso para que no se dupliquen turnos.
    // El prompt viaja CRUDO: el motor aplica el chat template real del
    // GGUF. `context` lleva el system prompt dinámico y `history` los
    // turnos previos como role/content (el core los templatea bien).
    final history = _historyBeforeCurrentUser(text);
    final prompt =
        '${toolTrace.isEmpty ? ChatSystemPrompt.attachmentsBlock(attachments, _maxAttachmentChars) : ''}'
        '${ChatSystemPrompt.promptClip(text, _maxUserChars)}';

    _StreamLease? lease;
    try {
      if (!_isGenerationCurrent(generationId)) return;
      // Streaming: cada token actualiza streamingText en tiempo real.
      final settings = _ref.read(settingsProvider);
      final (:stream, :client, :requestId) = _engine.generateStream(
        prompt: prompt,
        temperature: settings.temperature,
        topP: settings.topP,
        maxTokens: settings.maxTokens.clamp(32, 4096),
        sessionId: _sessionId,
        context: _buildSystemPrompt(),
        history: _buildHistory(history, toolTrace),
      );
      lease = _StreamLease(
        generationId: generationId,
        client: client,
        requestId: requestId,
      );
      _activeStream = lease;
      _activeConnections++;
      debugPrint('[chat_provider] Conexión activa: $_activeConnections');

      final buffer = StringBuffer();
      double? finalTps;
      TurnMetrics? turnMetrics;
      await for (final token in stream.timeout(
        _streamIdleTimeout,
        onTimeout: (sink) {
          sink.addError(
            LLMEngineException(
              'Timeout: el motor no emitió tokens durante '
              '${_streamIdleTimeout.inSeconds}s',
            ),
          );
        },
      )) {
        if (!_isGenerationCurrent(generationId)) return;
        // Heartbeat de fase (R3): "model_loading" → chip CARGANDO honesto.
        if (token.phase == 'model_loading') {
          state = state.copyWith(connection: ModelConnectionState.loadingModel);
        }
        if (token.stop) {
          finalTps = token.tps;
          // Gate R10 — timings reales del turno desde el frame final.
          if (token.timings != null) {
            turnMetrics = TurnMetrics.fromJson(token.timings!);
          }
          break;
        }
        buffer.write(token.content);
        // Throttle: UI se actualiza cada ~32ms
        _scheduleStreamFlush(buffer);
      }

      // Flush del texto parcial restante
      _cancelStreamFlush();

      if (!_isGenerationCurrent(generationId)) return;

      final fullText = buffer.toString().trim();
      if (fullText.isEmpty) {
        final emptyMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text:
              'El motor terminó sin emitir texto. Esto suele indicar '
              'modelo no cargado, prompt rechazado por el runtime o falta de '
              'memoria durante la inferencia.',
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        );
        state = state.copyWith(
          messages: [...state.messages, emptyMsg],
          generating: false,
          streamingText: '',
          connection: ModelConnectionState.error,
          engineOnline: true,
        );
        _persistMessages();
        return;
      }

      // Tool-calling: si el modelo respondió llamadas a herramientas,
      // ejecutarlas (bajo política §12) y re-generar con el resultado en el
      // trace. Soporta plan multi-paso (array de tools): los pasos se
      // ejecutan secuencialmente, cada uno con policy + AgentLoop
      // (retry/verificación); si uno falla, el plan se aborta; si uno pide
      // confirmación humana, el turno pausa y se reanuda desde ese paso.
      final toolCalls = AgentToolProtocol.extractToolCalls(fullText);
      if (toolCalls.isNotEmpty && toolTrace.length ~/ 2 < _maxToolRounds) {
        // La llamada queda visible en el chat (trace honesto del agente).
        final toolMsg = ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: fullText,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        );
        state = state.copyWith(
          messages: [...state.messages, toolMsg],
          streamingText: '',
        );
        _persistMessages();

        // Plan multi-paso: ejecutar secuencialmente y re-generar UNA vez con
        // el resumen del plan (evita N rondas LLM para N pasos).
        if (toolCalls.length > 1) {
          final planOutcome = await _coordinator.runPlan(
            toolCalls,
            recordGoal: text,
          );
          if (!_isGenerationCurrent(generationId)) return;
          if (planOutcome.pauseIndex != null && planOutcome.pauseCall != null) {
            // Un paso pidió confirmación → pausar el plan completo.
            _pendingPlan = toolCalls;
            _pendingPlanIndex = planOutcome.pauseIndex;
            _pendingUserText = text;
            _pendingTrace = toolTrace;
            _pendingCallText = fullText;
            state = state.copyWith(
              generating: false,
              pendingTool: planOutcome.pauseCall!.tool,
              pendingToolDescription: planOutcome.summary,
            );
            return;
          }
          _releaseStream(lease, 'entre rondas');
          await _generateRound(
            text,
            [...toolTrace, fullText, planOutcome.summary],
            const [],
            generationId,
          );
          return;
        }

        final toolCall = toolCalls.single;
        if (_requiresAutonomousToolConfirmation(toolCall)) {
          _pendingCall = toolCall;
          _pendingUserText = text;
          _pendingTrace = toolTrace;
          _pendingCallText = fullText;
          state = state.copyWith(
            generating: false,
            pendingTool: toolCall.tool,
            pendingToolDescription: _toolConfirmationDescription(toolCall),
          );
          return;
        }

        final outcome = await _coordinator.runTool(toolCall);
        if (!_isGenerationCurrent(generationId)) return;
        if (outcome.needsConfirmation) {
          // Pausa: guardar contexto de reanudación y exponer el diálogo.
          _pendingCall = toolCall;
          _pendingUserText = text;
          _pendingTrace = toolTrace;
          _pendingCallText = fullText;
          state = state.copyWith(
            generating: false,
            pendingTool: toolCall.tool,
            pendingToolDescription: outcome.feedback,
          );
          return;
        }
        // El stream de esta ronda ya terminó. Libera su cliente ANTES de
        // entrar a la siguiente ronda para que la referencia compartida no
        // sea reemplazada y el finally externo cierre el cliente nuevo.
        _releaseStream(lease, 'entre rondas');
        await _generateRound(
          text,
          [...toolTrace, fullText, outcome.feedback],
          const [],
          generationId,
        );
        return;
      }

      final sanitizedText = fullText
          .replaceAll('<|im_end|>', '')
          .replaceAll('<|im_start|>', '')
          .replaceAll('<|endoftext|>', '')
          .replaceAll('<\uFF5Cend\u2581of\u2581sentence\uFF5C>', '')
          .replaceAll('<\uFF5Cbegin\u2581of\u2581sentence\uFF5C>', '')
          .trim();

      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: sanitizedText.isEmpty ? fullText : sanitizedText,
        timestamp: DateTime.now(),
        tps: finalTps,
        status: MessageStatus.sent,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        generating: false,
        streamingText: '',
        connection: ModelConnectionState.ready,
        engineOnline: true,
        liveTps: finalTps ?? state.liveTps,
        lastTurnMetrics: turnMetrics,
      );
      _persistMessages();
    } on LLMEngineException catch (e) {
      if (!_isGenerationCurrent(generationId)) return;
      // Distinguir 503 runtime_unavailable (motor vivo sin GGUF) del resto:
      // el mensaje honesto cambia y connection pasa a noModel, no a error.
      final engine = _ref.read(runtimeEngineProvider.notifier);
      final degraded = engine.phase == EnginePhase.degraded;
      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: degraded
            ? 'El motor está vivo pero no hay modelo GGUF instalado. Descárgalo desde el catálogo de modelos. (${state.activeModel})'
            : 'El motor llama.cpp no respondió: ${e.message}. (${state.activeModel})',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        generating: false,
        streamingText: '',
        connection: degraded
            ? ModelConnectionState.noModel
            : ModelConnectionState.error,
        engineOnline: engine.isLive,
      );
      _persistMessages();
    } catch (e, stackTrace) {
      if (!_isGenerationCurrent(generationId)) return;
      debugPrint('[chat_provider] Error inesperado de generación: $e');
      debugPrintStack(stackTrace: stackTrace);
      final aiMsg = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: 'No se pudo iniciar o completar la generación: $e',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        generating: false,
        streamingText: '',
        connection: ModelConnectionState.error,
      );
      _persistMessages();
    } finally {
      if (_activeGenerationId == generationId) {
        _cancelStreamFlush();
        _activeGenerationId = null;
      }
      if (lease != null) _releaseStream(lease, 'finally');
    }
  }

  void _releaseStream(_StreamLease lease, String reason) {
    if (lease.released) return;
    lease.released = true;
    if (identical(_activeStream, lease)) _activeStream = null;
    if (_activeConnections > 0) _activeConnections--;
    try {
      lease.client.close();
      debugPrint(
        '[chat_provider] Cliente HTTP cerrado ($reason). '
        'Activas: $_activeConnections',
      );
    } catch (e) {
      debugPrint('[chat_provider] Error cerrando cliente ($reason): $e');
    }
  }

  /// Gate R6 — cancel cooperativo con manejo de error explícito (sin
  /// catchError: el retorno void del handler rompe el tipo de onError).
  Future<void> _cancelCooperativo(String requestId) async {
    try {
      final ok = await _engine.cancelRequest(requestId);
      debugPrint(
        '[chat_provider] cancel $requestId ${ok ? 'confirmado' : 'no encontrado'}',
      );
    } catch (e) {
      debugPrint('[chat_provider] cancel request error: $e');
    }
  }

  // STOP cancela la respuesta PENDIENTE
  void stop() {
    _generationCancelled = true;
    _activeGenerationId = null;
    // Cancelar el flush pendiente ANTES de cerrar el cliente: evita que un
    // timer de 32ms escriba streamingText residual con generating=false.
    _cancelStreamFlush();

    // Gate R6 — cancel cooperativo: POST /cancel corta el stream en el
    // servidor (incluso durante prefill) e invalida el KV de la sesión.
    // Sin esto, cerrar solo el socket dejaba el worker calculando con KV a
    // medias que el siguiente turno heredaba (estado corrupto).
    final lease = _activeStream;
    if (lease != null) {
      // Fire-and-forget con manejo de error: si /cancel falla, el cierre de
      // socket de abajo sigue como fallback de corte de stream.
      unawaited(_cancelCooperativo(lease.requestId));
      _releaseStream(lease, 'stop');
    }

    state = state.copyWith(generating: false, streamingText: '');
    _persistMessages();
  }

  Future<void> clear() async {
    _historyTouched = true;
    if (state.generating) stop();
    _sessionId = _newSessionId();
    state = state.copyWith(messages: [], input: '', streamingText: '');
    await _historyStore.clear();
  }

  void delete(String id) {
    _historyTouched = true;
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != id).toList(),
    );
    _persistMessages();
  }

  /// Reintenta el envío tras un error
  void retry(String errorMessageId) {
    if (state.generating) return;
    final msgs = state.messages;
    final errIdx = msgs.indexWhere((m) => m.id == errorMessageId);
    if (errIdx < 1) return;

    // Buscar el último mensaje del usuario antes del mensaje de error
    ChatMessage? userMsg;
    for (var i = errIdx - 1; i >= 0; i--) {
      if (msgs[i].sender == MessageSender.user) {
        userMsg = msgs[i];
        break;
      }
    }
    if (userMsg == null) return;
    _historyTouched = true;

    // Eliminar AMBOS: el error y el mensaje del usuario
    final newMsgs = msgs
        .where((m) => m.id != errorMessageId && m.id != userMsg!.id)
        .toList();
    state = state.copyWith(messages: newMsgs);
    _persistMessages();
    // catchError evita que un fallo en send() quede huérfano en un Future
    // sin listener (unawaited + throw → análisis de errores lo pierde).
    unawaited(
      send(userMsg.text).catchError(
        (Object e) => debugPrint('[chat_provider] retry send error: $e'),
      ),
    );
  }

  void selectModel(String name, {String? path, bool confirmedExtreme = false}) {
    // Gate R9 — EXTREME (9B+) requiere confirmación explícita: en móvil el
    // chat quedaría lento (thrashing) y nunca debe seleccionarse por
    // accidente. SOLO aplica a modelos del catálogo: los detectados del
    // storage no están en NeuralCatalog, y entryOf devolvería models[0] como
    // fallback (tier deep/extreme) bloqueando la carga por error.
    final entry = NeuralCatalog.entryOf(name);
    final inCatalog = entry.name == name;
    if (inCatalog && entry.tier == ModelTier.extreme && !confirmedExtreme) {
      debugPrint(
        '[chat_provider] selectModel extreme ($name) sin confirmación — ignorado',
      );
      return;
    }
    // Gate R5 — rotar sesión al cambiar de modelo: garantiza que el KV viejo
    // nunca se reutilice aunque el motor NO se reinicie (el core ya resetea la
    // sesión en load_model, esto es defensa extra en el cliente).
    final modelChanged = name != state.activeModel;
    final pathChanged = path != null && path != state.activeModelPath;
    if (modelChanged || pathChanged) {
      _sessionId = _newSessionId();
      debugPrint('[chat_provider] modelo cambiado → nueva sesión $_sessionId');
    }
    final revision = ++_modelSelectionRevision;
    // SELinux impide que la app rearranque el motor per-selección.
    state = state.copyWith(
      activeModel: name,
      activeModelPath: modelChanged ? path : (path ?? state.activeModelPath),
      connection: ModelConnectionState.loadingModel,
      showModelSelector: false,
    );
    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(milliseconds: 600), () async {
      _loadTimer = null;
      await _checkEngine(model: name, expectedRevision: revision);
      if (!mounted || revision != _modelSelectionRevision) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nanoai_active_model', name);
        if (path != null) {
          await prefs.setString('nanoai_active_model_path', path);
        } else if (modelChanged) {
          await prefs.remove('nanoai_active_model_path');
        }
      } catch (e) {
        debugPrint('[chat_provider] Error en persistencia: $e');
      }
    });
  }

  @override
  void dispose() {
    _generationCancelled = true;
    _activeGenerationId = null;
    _cancelStreamFlush();
    final lease = _activeStream;
    if (lease != null) _releaseStream(lease, 'dispose');

    _loadTimer?.cancel();

    // CORRECCIÓN CRÍTICA: Verificar memory leaks al dispose
    if (_activeConnections > 0) {
      debugPrint(
        '[chat_provider] WARNING: $_activeConnections conexiones activas en dispose()',
      );
    }

    // El client es propiedad de RuntimeEngineNotifier: él lo dispone.
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  // Inyección real (DI): el dispatcher viene del composition root
  // (agent_dependencies.dart) con sus dependencias reales cableadas una vez.
  // El fallback interno de ChatNotifier solo existe para tests que no pasan
  // toolDispatcher.
  (ref) => ChatNotifier(
    ref,
    toolDispatcher: ref.watch(agentDispatcherProvider),
    experienceCache: ref.watch(experienceCacheProvider),
    flowExecutor: ref.watch(nanoFlowExecutorProvider),
  ),
);

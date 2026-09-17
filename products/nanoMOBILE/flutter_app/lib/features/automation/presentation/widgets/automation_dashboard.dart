import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/engine/governance/action_confirmation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_choice_group.dart';
import 'package:nanoai/core/widgets/nano_owl_avatar.dart';
import 'package:nanoai/core/widgets/navigation/nano_glyph.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';
import 'package:nanoai/core/widgets/feather_core_icon.dart';

import '../../application/automation_coordinator_provider.dart'
    show pendingRepliesProvider, ruleRegistryProvider;
import '../../application/automation_diagnostics.dart';
import '../../application/automation_engine.dart';
import '../../application/automation_engine_provider.dart';
import '../../application/automation_feedback_presenter.dart';
import '../../application/rule_creator.dart';
import '../../domain/automation_goal.dart';
import '../../domain/automation_policy.dart';
import '../../domain/automation_result.dart';
import '../../engine/agent_dependencies.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/perception/current_situation.dart';
import '../../engine/scheduling/scheduled_rule.dart';
import '../../engine/scheduling/trigger.dart';
import '../../engine/voice/voice_runtime.dart';

import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import 'engine_status_card.dart';
import 'automation_suggestion_carousel.dart';

part 'automation_dashboard_components.dart';

/// Estado del engine (ligero) para la capa de presentación. Lee el ENDPOINT
/// REAL (http://127.0.0.1:8080) — el motor que realmente responderá generate() —
/// en vez del notifier (que puede quedar idle si su supervisor no lo levantó).
/// Si el endpoint está vivo + tiene modelo → ready (refleja la realidad). Si no
/// → el estado del notifier. Nunca simula.
final engineStatusProvider = FutureProvider<EngineStatus?>((ref) async {
  final notifier = ref.watch(runtimeEngineProvider);
  final state = ref.watch(runtimeEngineProvider);
  try {
    final client = ref.read(runtimeEngineProvider.notifier).client;
    final online = await client.isOnline();
    final hasModel = await client.hasModel();
    if (online && hasModel) {
      return EngineStatus(
        port: state.port,
        phase: EnginePhase.ready,
        modelPath: state.modelPath ?? 'modelo-cargado',
      );
    }
  } catch (_) {
    // endpoint no responde → usar el estado del notifier (honesto).
  }
  return notifier;
});

/// El centro de control del asistente: cabecera de estado, composer de tareas,
/// quick actions, estado de capacidades y ejecuciones recientes.
///
/// Reemplaza la antigua "consola de tests" por un dashboard orientado al
/// usuario. Las herramientas técnicas viven en la pantalla Dev (no acá).
class AutomationDashboard extends ConsumerStatefulWidget {
  const AutomationDashboard({
    super.key,
    this.onSettingsTap,
    this.onMessagesTap,
    this.onRulesTap,
    this.onBusinessTap,
    this.onPersonalAgentTap,
    this.onSkillsMcpTap,
    this.onDevTap,
  });

  /// Abre la configuración visual de Automatización. La lógica y la
  /// persistencia continúan perteneciendo a sus providers actuales.
  final VoidCallback? onSettingsTap;

  /// Abre la pantalla de Mensajes (función de usuario, no Dev).
  final VoidCallback? onMessagesTap;

  /// RULES-CREATE-02 — abre la pantalla de Reglas (lista completa). Antes
  /// solo era alcanzable desde Configuración: acceso directo visible.
  final VoidCallback? onRulesTap;

  /// Acceso directo a WhatsApp Negocio y catálogo comercial.
  final VoidCallback? onBusinessTap;

  /// Acceso directo a la pantalla especializada del Agente Personal de WhatsApp.
  final VoidCallback? onPersonalAgentTap;

  /// Acceso directo al Hub visual de MCP & Skills (grafo, telemetría y tienda).
  final VoidCallback? onSkillsMcpTap;

  /// Abre la pantalla Dev (herramientas del agente) sin pasar por Ajustes.
  /// Solo se conecta en modo debug (misma puerta que el acceso de Ajustes).
  final VoidCallback? onDevTap;

  @override
  ConsumerState<AutomationDashboard> createState() =>
      _AutomationDashboardState();
}

class _AutomationDashboardState extends ConsumerState<AutomationDashboard> {
  final _taskController = TextEditingController();

  late final VoiceSessionManager _voiceSession;
  StreamSubscription<VoiceSessionState>? _voiceStateSubscription;
  StreamSubscription<String>? _confirmationActionSubscription;
  VoiceSessionState _voiceState = VoiceSessionState.idle;
  bool _observingScreen = false;
  String? _senseFeedback;

  AutomationResultStatus? _lastStatus;
  String _lastGoal = '';
  String _lastReason = '';
  bool _running = false;
  bool _composing = false;
  bool _cancelRequested = false;
  String? _activeExecutionId;
  AutomationEngine? _activeEngine;
  ActionConfirmation? _lastConfirmation;

  bool get _voiceBusy =>
      _voiceState == VoiceSessionState.listening ||
      _voiceState == VoiceSessionState.processing;

  bool get _sensing => _voiceBusy || _observingScreen;

  @override
  void initState() {
    super.initState();
    // Reutiliza la sesión conversacional existente. La voz sólo entrega
    // un goal al mismo AutomationEngine que usa el composer escrito.
    _voiceSession = ref.read(chatProvider.notifier).voiceSession;
    _voiceState = _voiceSession.state;
    _voiceStateSubscription = _voiceSession.states.listen((state) {
      if (!mounted) return;
      setState(() => _voiceState = state);
    });
    _confirmationActionSubscription = NanoRuntimeApi
        .instance
        .automationConfirmationActions
        .listen(_handleConfirmationAction);
  }

  @override
  void dispose() {
    _voiceStateSubscription?.cancel();
    _confirmationActionSubscription?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  void _handleConfirmationAction(String action) {
    if (action != 'confirm' || !mounted || _running) return;
    final confirmation = _lastConfirmation;
    if (_lastStatus != AutomationResultStatus.paused || confirmation == null) {
      return;
    }
    // El BroadcastReceiver no abre Nano: WhatsApp permanece al frente y el
    // ContextLock puede revalidar conversación, borrador y botón de envío.
    unawaited(_runTask(_lastGoal, confirmation: confirmation));
  }

  Future<void> _activateVoice() async {
    if (_running || _sensing) return;

    setState(() => _senseFeedback = 'Escuchando una orden…');
    try {
      final turn = await _voiceSession.pushToTalk();
      if (!mounted) return;
      if (turn == null) {
        setState(() => _senseFeedback = 'No se detectó una orden de voz.');
        return;
      }

      final transcript = turn.transcript.trim();
      final goal = (turn.resolvedGoal ?? transcript).trim();
      _taskController
        ..text = transcript
        ..selection = TextSelection.collapsed(offset: transcript.length);
      if (goal.isEmpty) {
        setState(() => _senseFeedback = 'La orden de voz quedó vacía.');
        return;
      }
      if (_running) {
        setState(
          () => _senseFeedback =
              'Orden reconocida · espera a que finalice la tarea actual.',
        );
        return;
      }
      setState(() => _senseFeedback = 'Orden reconocida · ejecutando');
      await _runTask(goal, fromVoice: true);
    } catch (_) {
      // Un fallo del canal nativo no debe dejar la máquina visualmente
      // atrapada en listening/processing ni bloquear el siguiente intento.
      try {
        await _voiceSession.stop();
      } catch (_) {
        // El feedback sigue siendo honesto aunque el canal nativo no responda.
      }
      if (!mounted) return;
      setState(
        () => _senseFeedback = 'No fue posible iniciar el reconocimiento.',
      );
    }
  }

  /// VOICE-NATURAL-01 — conversación continua en la card de chat del módulo:
  /// escucha → ejecuta por el MISMO _runTask → habla el resultado → vuelve a
  /// escuchar. Un turno vacío (silencio) cierra el ciclo; paused rompe para
  /// que el flujo de confirmación existente tome el control.
  bool _conversationActive = false;

  Future<void> _activateConversation() async {
    // Detener siempre responde: la conversación se para en caliente aunque
    // haya una tarea en curso (el loop comprueba _conversationActive).
    if (_conversationActive) {
      _conversationActive = false;
      await _voiceSession.stop();
      if (mounted) setState(() => _senseFeedback = 'Conversación detenida.');
      return;
    }
    if (_running || _observingScreen) return;
    setState(() => _conversationActive = true);
    try {
      // La conversación la abre Nano: saludo hablado antes de escuchar (mismo
      // patrón del chat) — sin él, el modo arranca en silencio y parece roto.
      await _voiceSession.respond('Hola, soy Nano. Dime qué quieres que haga.');
      await _voiceSession.waitForSpeechEnd();
      while (mounted && _conversationActive) {
        setState(() => _senseFeedback = 'Conversación activa · habla…');
        final turn = await _voiceSession.pushToTalk();
        if (!mounted || !_conversationActive) break;
        final transcript = turn?.transcript.trim() ?? '';
        if (transcript.isEmpty) break;
        _taskController
          ..text = transcript
          ..selection = TextSelection.collapsed(offset: transcript.length);
        final result = await _runTask(
          transcript,
          fromVoice: true,
          speakResult: false,
        );
        if (!mounted || !_conversationActive) break;
        if (result == null) continue;
        if (result.status == AutomationResultStatus.paused) {
          // Confirmación pendiente: avisa hablando y cede el control al flujo
          // de confirmación existente (sin re-escuchar en bucle).
          await _voiceSession.respond(_spokenResult(result));
          break;
        }
        await _voiceSession.respondAndListen(_spokenResult(result));
      }
    } finally {
      if (mounted) {
        setState(() {
          _conversationActive = false;
          _senseFeedback = null;
        });
      }
    }
  }

  Future<void> _toggleVoiceOutput() async {
    final enabled = ref.read(settingsProvider).voiceEnabled;
    await ref.read(settingsProvider.notifier).setVoiceEnabled(!enabled);
    if (!mounted) return;
    setState(
      () => _senseFeedback = enabled
          ? 'Audio de Nano apagado · responderá solo con texto.'
          : 'Audio de Nano encendido.',
    );
  }

  Future<void> _observeScreen() async {
    if (_running || _sensing) return;
    setState(() {
      _observingScreen = true;
      _senseFeedback = 'Observando la pantalla…';
    });
    try {
      // Misma fuente factual usada por navegación y verificación. No ejecuta
      // acciones y no convierte una observación en autoridad.
      final situation = await ref.read(currentSituationSourceProvider).call();
      if (!mounted) return;
      setState(() {
        _observingScreen = false;
        _senseFeedback = situation == null
            ? 'Sin lectura de pantalla · comprueba Accesibilidad.'
            : _describeSituation(situation);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _observingScreen = false;
        _senseFeedback = 'La observación de pantalla no está disponible.';
      });
    }
  }

  /// Devuelve el resultado (null si no se ejecutó). [speakResult] permite al
  /// modo conversación hablar el resultado él mismo con re-escucha
  /// (respondAndListen) en lugar del respond simple de un turno único.
  Future<AutomationResult?> _runTask(
    String text, {
    ActionConfirmation? confirmation,
    bool fromVoice = false,
    bool speakResult = true,
  }) async {
    final goal = text.trim();
    if (goal.isEmpty || _running || (_sensing && !fromVoice)) return null;
    // Capturar referencias ANTES de los awaits: el widget puede desmontarse
    // durante una ejecución larga (carga de modelo) y ref.read posterior
    // lanzaría "Cannot use ref after the widget was disposed".
    final voiceEnabled = ref.read(settingsProvider).voiceEnabled;
    final diagnostic = isDiagCommand(goal);
    final engine = diagnostic ? null : ref.read(automationEngineProvider);
    final executionId = diagnostic
        ? null
        : confirmation?.executionId ?? 'dashboard-${UniqueKey()}';
    _activeEngine = engine;
    _activeExecutionId = executionId;
    if (confirmation != null) {
      unawaited(NanoRuntimeApi.instance.dismissAutomationConfirmation());
    }
    _taskController.clear();
    setState(() {
      _running = true;
      _composing = false;
      _cancelRequested = false;
      _lastGoal = goal;
      _lastStatus = null;
      _lastReason = '';
    });
    try {
      // DIAG-01 — comandos de diagnóstico se ejecutan ANTES del planner, por
      // su propia ruta (sin LLM ni WhatsApp en @diag ping; @diag llm prueba
      // solo la ruta del motor). Mismo canal de resultado que el resto.
      final result = diagnostic
          ? await ref.read(automationDiagnosticsProvider).run(goal)
          : await engine!.runGoal(
              AutomationGoal(text: goal),
              options: AutomationOptions(
                executionId: executionId,
                confirmation: confirmation,
                confirmed: confirmation != null,
              ),
            );
      if (fromVoice) {
        _voiceSession.world
          ..lastUserIntent = goal
          ..lastAction = result.status.name
          ..touch();
      }
      if (mounted) {
        setState(() {
          _lastStatus = result.status;
          _lastReason = automationUserFacingReason(result.reason);
          _lastConfirmation = result.confirmation;
          _running = false;
          if (fromVoice) _senseFeedback = 'Orden de voz finalizada.';
        });
      }
      if (result.status == AutomationResultStatus.paused &&
          result.confirmation != null) {
        // WhatsApp u otra app puede estar al frente cuando el motor pausa. El
        // aviso hace visible la gobernanza sin overlays ni permisos nuevos y
        // solo lleva al botón firmado que ya existe dentro de Nano.
        unawaited(NanoRuntimeApi.instance.showAutomationConfirmation());
      } else {
        unawaited(NanoRuntimeApi.instance.dismissAutomationConfirmation());
      }
      if (voiceEnabled && speakResult && !isDiagCommand(goal)) {
        // El resultado hablado es exactamente el resultado del mismo
        // AutomationEngine. "Audio" gobierna tanto órdenes escritas como de
        // micrófono; TTS es solo una salida y nunca cambia el veredicto.
        // Los comandos @diag se informan por la UI (razón legible), no por voz.
        await _voiceSession.respond(_spokenResult(result));
      }
      return result;
    } catch (e, stack) {
      // Nunca tragar una excepción: el usuario necesita la razón real y el
      // logcat la causa para diagnosticar.
      debugPrint('[automation_dashboard] Error al ejecutar tarea: $e\n$stack');
      if (mounted) {
        setState(() {
          _lastStatus = AutomationResultStatus.failed;
          _lastReason = 'Error al ejecutar la tarea: $e';
          _running = false;
        });
      }
      return null;
    } finally {
      if (_activeExecutionId == executionId) {
        _activeExecutionId = null;
        _activeEngine = null;
      }
    }
  }

  void _cancelTask() {
    final executionId = _activeExecutionId;
    if (!_running || _cancelRequested || executionId == null) return;
    final requested = _activeEngine?.cancelExecution(executionId) ?? false;
    setState(() {
      _cancelRequested = requested;
      _conversationActive = false;
      _senseFeedback = requested
          ? 'Deteniendo los pasos pendientes…'
          : 'La tarea ya está finalizando.';
    });
    // Keep _running until the coordinator reports the real final result.
    // Otherwise a second tap can start an overlapping execution.
  }

  void _onComposerChanged(String text) {
    final composing = text.trim().isNotEmpty;
    if (_composing != composing) setState(() => _composing = composing);
  }

  String _spokenResult(AutomationResult result) {
    final prefix = switch (result.status) {
      AutomationResultStatus.completed => 'Tarea completada.',
      AutomationResultStatus.completedUnverified =>
        'La tarea terminó, pero no pude verificar el objetivo final.',
      AutomationResultStatus.paused => 'Necesito tu confirmación.',
      AutomationResultStatus.denied => 'La acción fue denegada.',
      AutomationResultStatus.noPlan => 'No encontré un plan verificable.',
      AutomationResultStatus.failed => 'No pude completar la tarea.',
      AutomationResultStatus.outcomeUnknown =>
        'No pude comprobar el resultado de la acción.',
      AutomationResultStatus.cancelled => 'La tarea fue cancelada.',
    };
    final reason = automationSpokenReason(result.reason);
    return reason.isEmpty ? prefix : '$prefix $reason';
  }

  /// RULES-CREATE-02 — acceso "Por hora": reloj del sistema + mensaje → regla
  /// TimeTrigger+notify creada por el MISMO RuleCreator de la pantalla Reglas.
  /// Mensaje vacío permitido: el dispatcher publica su fallback honesto.
  Future<void> _createTimeRule() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    final messageController = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AutomationVisual.of(context).surface,
        title: Text('Aviso a las ${picked.format(context)}'),
        // UI-REV-13: contenido scrolleable — con teclado abierto en horizontal
        // el dialog jamás hace overflow de píxeles.
        content: SingleChildScrollView(
          child: TextField(
            controller: messageController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Qué avisar (opcional)',
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(messageController.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    messageController.dispose();
    if (message == null || !mounted) return;
    final rule = ref
        .read(ruleCreatorProvider)
        .create(
          trigger: TimeTrigger(hour: picked.hour, minute: picked.minute),
          action: RuleAction.notify,
          message: message,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Regla creada: ${rule.id} — avisará cada día a las '
          '${picked.format(context)}',
        ),
      ),
    );
  }

  Future<void> _pickMode() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NanoSpacing.lg),
            child: Consumer(
              builder: (context, ref, _) {
                final s = ref.watch(settingsProvider);
                final notifier = ref.read(settingsProvider.notifier);
                return ChoiceGroup(
                  label: 'Nivel de autonomía',
                  description: s.agentAutomationMode.description,
                  options: const [
                    ChoiceOption(
                      'manual',
                      'Manual',
                      Icons.pan_tool_alt_rounded,
                    ),
                    ChoiceOption(
                      'assisted',
                      'Asistido',
                      Icons.assistant_rounded,
                    ),
                    ChoiceOption(
                      'autonomous',
                      'Autónomo',
                      Icons.auto_awesome_rounded,
                    ),
                  ],
                  selectedValue: s.agentAutomationMode.name,
                  onSelected: (value) {
                    notifier.setAgentAutomationMode(
                      AgentAutomationMode.fromName(value),
                    );
                    Navigator.of(ctx).pop();
                  },
                  colors: NanoThemeExtension.of(context).colors,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final mode = settings.agentAutomationMode;

    final pendingDraftsAsync = ref.watch(pendingRepliesProvider);
    final pendingDraftsCount = pendingDraftsAsync.maybeWhen(
      data: (list) => list.where((d) => d.isActionable).length,
      orElse: () => 0,
    );
    final rulesCount = ref
        .watch(ruleRegistryProvider)
        .rules
        .where((r) => r.enabled)
        .length;

    // UI-REV-02: composición única estilo Dev — columna centrada de 720
    // con cabecera compacta. Antes había dos jerarquías (wide 2 columnas
    // / narrow) con el mismo contenido duplicado; la 2 columnas estiraba
    // cards y rompía la proporción del resto del módulo.
    final header = _AgentHeader(
      mode: mode,
      onModeTap: _pickMode,
      onDevTap: widget.onDevTap,
      onVoiceOutputTap: _toggleVoiceOutput,
      isVoiceOutputEnabled: settings.voiceEnabled,
      onConversationTap: _activateConversation,
      isConversationActive: _conversationActive,
      isRunning: _running,
    );
    final active = (_running || _lastStatus != null)
        ? _ActiveExecutionCard(
            goal: _lastGoal,
            running: _running,
            status: _lastStatus,
            reason: _lastReason,
            onConfirm: _lastStatus == AutomationResultStatus.paused
                ? () => _runTask(_lastGoal, confirmation: _lastConfirmation)
                : null,
          )
        : null;
    final businessFacts = ref.watch(businessFactsNotifierProvider);
    final businessProductsCount = businessFacts.products.length;

    final quick = QuickAutomationActions(
      onRun: _runTask,
      onMessagesTap: widget.onMessagesTap,
      onSettingsTap: widget.onSettingsTap,
      onRulesTap: widget.onRulesTap,
      onBusinessTap: widget.onBusinessTap,
      onPersonalAgentTap: widget.onPersonalAgentTap,
      onSkillsMcpTap: widget.onSkillsMcpTap,
      onTimeRuleTap: _createTimeRule,
      suppressSuggestions: _running || _sensing || _composing,
      pendingDraftsCount: pendingDraftsCount,
      activeRulesCount: rulesCount,
      businessProductsCount: businessProductsCount,
    );

    return NanoInputScope(
      scopeId: 'automation',
      hint: 'Describe qué quieres automatizar en Nano AI...',
      onSubmit: (text) => _runTask(text),
      onChanged: _onComposerChanged,
      onVoice: _activateVoice,
      onAttach: _observeScreen,
      isGenerating: _running,
      onStop: _running && _activeExecutionId != null ? _cancelTask : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final visual = AutomationVisual.of(context);
          // UI-REV-13: horizontal — DOS columnas para aprovechar el ancho:
          // cabecera y estado activo a la izquierda, accesos/sugerencias a la
          // derecha. Vertical: columna única como siempre.
          // Cero compositores duplicados — la barra cósmica inferior es la
          // única fuente de verdad para comandos y automatizaciones.
          final isDeviceLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final landscape = isDeviceLandscape && constraints.maxWidth >= 560;
          final mainColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (pendingDraftsCount > 0) ...[
                const SizedBox(height: 10),
                _PendingDraftsBanner(
                  count: pendingDraftsCount,
                  onTap: widget.onMessagesTap,
                ),
              ],
              if (_senseFeedback != null) ...[
                const SizedBox(height: NanoSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: visual.accentSoft.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: visual.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: visual.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _senseFeedback!,
                          style: TextStyle(
                            fontSize: 12,
                            color: visual.text,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _senseFeedback = null),
                      ),
                    ],
                  ),
                ),
              ],
              if (active != null) ...[
                const SizedBox(height: NanoSpacing.lg),
                active,
              ],
              if (landscape) ...[
                const SizedBox(height: NanoSpacing.lg),
                const EngineStatusCard(cleanAppearance: true),
              ],
            ],
          );
          final sideColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              quick,
              if (!landscape) ...[
                const SizedBox(height: NanoSpacing.xl),
                const EngineStatusCard(cleanAppearance: true),
              ],
            ],
          );
          final content = landscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: mainColumn),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: sideColumn),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    mainColumn,
                    const SizedBox(height: NanoSpacing.xl),
                    sideColumn,
                  ],
                );
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            // NAV-FLOAT-01 — la barra flota sin reservar layout: el scroll
            // reserva su propio espacio inferior.
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              kNanoBarScrollReserve,
            ),
            child: Center(
              child: ConstrainedBox(
                // UI-REV-13: horizontal aprovecha el espacio (960 en phones, 1080 en tablets)
                // vertical conserva el ancho de 720.
                constraints: BoxConstraints(
                  maxWidth: landscape
                      ? (AutomationLayout.isCompactLandscape(context)
                            ? 960
                            : 1080)
                      : AutomationLayout.contentMaxWidth(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [content],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

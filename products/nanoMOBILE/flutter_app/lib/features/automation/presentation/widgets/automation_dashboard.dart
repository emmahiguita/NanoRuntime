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
import 'package:nanoai/core/widgets/navigation/nano_universal_input.dart';

import '../../application/automation_engine_provider.dart';
import '../../application/automation_feedback_presenter.dart';
import '../../application/rule_creator.dart';
import '../../domain/automation_goal.dart';
import '../../domain/automation_policy.dart';
import '../../domain/automation_result.dart';
import '../../engine/agent_dependencies.dart';
import '../../engine/perception/current_situation.dart';
import '../../engine/scheduling/scheduled_rule.dart';
import '../../engine/scheduling/trigger.dart';
import '../../engine/voice/voice_runtime.dart';

import '../automation_visual_theme.dart';
import 'engine_status_card.dart';

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
    if (confirmation != null) {
      unawaited(NanoRuntimeApi.instance.dismissAutomationConfirmation());
    }
    _taskController.clear();
    setState(() {
      _running = true;
      _lastGoal = goal;
      _lastStatus = null;
      _lastReason = '';
    });
    try {
      final result = await ref
          .read(automationEngineProvider)
          .runGoal(
            AutomationGoal(text: goal),
            options: confirmation != null
                ? AutomationOptions(confirmation: confirmation)
                : null,
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
      if (voiceEnabled && speakResult) {
        // El resultado hablado es exactamente el resultado del mismo
        // AutomationEngine. "Audio" gobierna tanto órdenes escritas como de
        // micrófono; TTS es solo una salida y nunca cambia el veredicto.
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
    }
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
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NanoSpacing.lg),
          child: Consumer(
            builder: (context, ref, _) {
              final s = ref.watch(settingsProvider);
              final notifier = ref.read(settingsProvider.notifier);
              return ChoiceGroup(
                label: 'Nivel de autonomía',
                description: s.agentAutomationMode.description,
                options: const [
                  ChoiceOption('manual', 'Manual', Icons.pan_tool_alt_rounded),
                  ChoiceOption('assisted', 'Asistido', Icons.assistant_rounded),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final mode = settings.agentAutomationMode;

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
    final quick = QuickAutomationActions(
      onRun: _runTask,
      onMessagesTap: widget.onMessagesTap,
      onSettingsTap: widget.onSettingsTap,
      onRulesTap: widget.onRulesTap,
      onTimeRuleTap: _createTimeRule,
    );

    return NanoInputScope(
      scopeId: 'automation',
      hint: 'Describe qué quieres automatizar en Nano AI...',
      onSubmit: (text) => _runTask(text),
      onVoice: _activateVoice,
      onAttach: _observeScreen,
      isGenerating: _running,
      onStop: _running ? () => setState(() => _running = false) : null,
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
          final landscape = isDeviceLandscape && constraints.maxWidth >= 640;
          final mainColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
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
            ],
          );
          final sideColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              quick,
              const SizedBox(height: NanoSpacing.xl),
              const EngineStatusCard(cleanAppearance: true),
            ],
          );
          final content = landscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: mainColumn),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: sideColumn),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
            child: Center(
              child: ConstrainedBox(
                // UI-REV-13: horizontal respira (1280) — vertical conserva el
                // ancho Dev de 720.
                constraints: BoxConstraints(maxWidth: landscape ? 1280 : 720),
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

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({
    required this.mode,
    required this.onModeTap,
    this.onDevTap,
    this.onVoiceOutputTap,
    this.isVoiceOutputEnabled = false,
    this.onConversationTap,
    this.isConversationActive = false,
  });
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final VoidCallback? onDevTap;
  final VoidCallback? onVoiceOutputTap;
  final bool isVoiceOutputEnabled;
  final VoidCallback? onConversationTap;
  final bool isConversationActive;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    // UI-REV-02: cabecera compacta estilo Dev — título de pantalla (18px,
    // mismo patrón de NanoScreenShell) en vez de la marca gigante de 30px.
    // UI-REV-05: fuera el icono de ajustes — el acceso a Configuración vive
    // como tile con texto en Accesos (más visible y profesional). El robot
    // (Dev) queda solo, a la derecha, sin competir con el título.
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Automatización',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: visual.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: visual.accentSoft,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    onTap: onModeTap,
                    borderRadius: BorderRadius.circular(99),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        'Modo ${mode.label}',
                        style: TextStyle(
                          // Naranja crudo sobre accentSoft no pasa AA en claro
                          // (~2.9:1): variante legible de la misma familia.
                          color: NanoTextColors.forText(
                            visual.accent,
                            NanoThemeExtension.of(context).colors,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onVoiceOutputTap != null)
            IconButton(
              tooltip: isVoiceOutputEnabled
                  ? 'Silenciar audio de Nano'
                  : 'Activar audio de Nano',
              visualDensity: VisualDensity.compact,
              onPressed: onVoiceOutputTap,
              icon: Icon(
                isVoiceOutputEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: isVoiceOutputEnabled ? visual.accent : visual.textMuted,
                size: 20,
              ),
            ),
          if (onConversationTap != null)
            IconButton(
              tooltip: isConversationActive
                  ? 'Detener conversación'
                  : 'Conversación manos libres',
              visualDensity: VisualDensity.compact,
              onPressed: onConversationTap,
              icon: Icon(
                isConversationActive
                    ? Icons.record_voice_over_rounded
                    : Icons.voice_chat_outlined,
                color: isConversationActive ? visual.accent : visual.textMuted,
                size: 20,
              ),
            ),
          if (onDevTap != null)
            IconButton(
              tooltip: 'Herramientas del agente',
              visualDensity: VisualDensity.compact,
              onPressed: onDevTap,
              icon: Icon(
                Icons.smart_toy_outlined,
                color: visual.accent,
                size: 21,
              ),
            ),
        ],
      ),
    );
  }
}

String _describeSituation(CurrentSituation situation) {
  final surface = switch (situation.surfaceKind) {
    CurrentSurfaceKind.dialog => 'diálogo',
    CurrentSurfaceKind.search => 'búsqueda',
    CurrentSurfaceKind.editable => 'campo editable',
    CurrentSurfaceKind.picker => 'selección',
    CurrentSurfaceKind.collection => 'lista',
    CurrentSurfaceKind.mediaViewer => 'visor multimedia',
    CurrentSurfaceKind.content => 'contenido',
    CurrentSurfaceKind.unknown => 'superficie sin clasificar',
  };
  final completeness = situation.isComplete ? '' : ' · lectura parcial';
  return 'Ojos activos · $surface · ${situation.packageName}$completeness';
}

/// Presentación HONESTA de un estado de ejecución: la etiqueta es la fuente
/// de verdad. `completed` = Verificado (verde). `completedUnverified` jamás
/// se pinta como éxito: es "Completado sin verificar" (ámbar).
({IconData icon, Color color, String label}) _statusPresentation(
  AutomationResultStatus s,
  NanoColors colors,
) {
  switch (s) {
    case AutomationResultStatus.completed:
      return (
        icon: Icons.check_circle_rounded,
        color: colors.success,
        label: 'Verificado',
      );
    case AutomationResultStatus.completedUnverified:
      return (
        icon: Icons.report_problem_rounded,
        color: colors.warning,
        label: 'Completado sin verificar',
      );
    case AutomationResultStatus.paused:
      return (
        icon: Icons.pause_circle_outline_rounded,
        color: colors.warning,
        label: 'Esperando confirmación',
      );
    case AutomationResultStatus.denied:
      return (
        icon: Icons.block_rounded,
        color: colors.warning,
        label: 'Denegado por política',
      );
    case AutomationResultStatus.noPlan:
      return (
        icon: Icons.error_outline_rounded,
        color: colors.warning,
        label: 'Sin plan',
      );
    case AutomationResultStatus.failed:
      return (
        icon: Icons.cancel_rounded,
        color: colors.error,
        label: 'No completado',
      );
    case AutomationResultStatus.outcomeUnknown:
      return (
        icon: Icons.help_outline_rounded,
        color: colors.warning,
        label: 'Resultado desconocido',
      );
    case AutomationResultStatus.cancelled:
      return (
        icon: Icons.not_interested_rounded,
        color: colors.onSurfaceVariant,
        label: 'Cancelado',
      );
  }
}

class _ActiveExecutionCard extends StatefulWidget {
  const _ActiveExecutionCard({
    required this.goal,
    required this.running,
    required this.status,
    required this.reason,
    this.onConfirm,
  });
  final String goal;
  final bool running;
  final AutomationResultStatus? status;
  final String reason;
  final VoidCallback? onConfirm;

  @override
  State<_ActiveExecutionCard> createState() => _ActiveExecutionCardState();
}

class _ActiveExecutionCardState extends State<_ActiveExecutionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.running) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ActiveExecutionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running && !oldWidget.running) {
      _pulse.repeat(reverse: true);
    } else if (!widget.running && oldWidget.running) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final done = !widget.running && widget.status != null;
    final present = done ? _statusPresentation(widget.status!, colors) : null;
    final activeColor = present?.color ?? AutomationVisual.of(context).accent;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: widget.running
              ? [
                  BoxShadow(
                    color: activeColor.withValues(
                      alpha: 0.10 + _pulse.value * 0.18,
                    ),
                    blurRadius: 14 + _pulse.value * 14,
                    spreadRadius: _pulse.value * 1.5,
                  ),
                ]
              : const [],
        ),
        child: child,
      ),
      child: AutomationSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    present?.icon ?? Icons.auto_awesome_rounded,
                    color: activeColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: NanoSpacing.sm),
                Expanded(
                  child: Text(
                    widget.goal,
                    maxLines: 4,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NanoSpacing.sm),
            AnimatedSwitcher(
              duration: NanoMotionDurations.quick,
              child: Text(
                widget.running
                    ? 'Ejecutando en el dispositivo…'
                    : (present?.label ?? ''),
                key: ValueKey('${widget.running}-${widget.status}'),
                style: NanoType.label(
                  present?.color ?? colors.onSurfaceVariant,
                ),
              ),
            ),
            if (!widget.running && widget.reason.trim().isNotEmpty) ...[
              const SizedBox(height: NanoSpacing.xs),
              Text(
                widget.reason.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: NanoType.caption(colors.onSurfaceVariant),
              ),
            ],
            if (widget.onConfirm != null) ...[
              const SizedBox(height: NanoSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: widget.onConfirm,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Confirmar y continuar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Atajos de tareas comunes → runGoal(preset).
class QuickAutomationActions extends StatelessWidget {
  const QuickAutomationActions({
    super.key,
    required this.onRun,
    this.onMessagesTap,
    this.onSettingsTap,
    this.onRulesTap,
    this.onTimeRuleTap,
  });
  final ValueChanged<String> onRun;

  /// Abre la pantalla de Mensajes (función de usuario, destacada).
  final VoidCallback? onMessagesTap;

  /// Abre la configuración del agente. Vive aquí como tile con TEXTO visible
  /// (UI-REV-05) — el icono suelto de la cabecera estorbaba y era poco claro.
  final VoidCallback? onSettingsTap;

  /// RULES-CREATE-02 — abre la pantalla de Reglas (antes solo desde Ajustes).
  final VoidCallback? onRulesTap;

  /// RULES-CREATE-02 — crea regla por hora con reloj del sistema + mensaje.
  final VoidCallback? onTimeRuleTap;

  static const _actions = [
    ('Abrir Bluetooth', 'abrir Bluetooth', Icons.bluetooth_rounded),
    ('Abrir Chrome', 'abrir Chrome', Icons.public_rounded),
    ('Abrir Linux', 'abrir la terminal Linux', Icons.terminal_rounded),
    (
      'Leer notificaciones',
      'leer las notificaciones',
      Icons.notifications_active_rounded,
    ),
    ('Analizar archivos', 'analizar los archivos', Icons.folder_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onSettingsTap != null ||
            onMessagesTap != null ||
            onRulesTap != null ||
            onTimeRuleTap != null) ...[
          const AutomationSectionLabel('Accesos'),
          // RULES-CREATE-02: las reglas primero — el reloj es el acceso que
          // el usuario busca; antes Reglas quedaba escondido en Configuración.
          if (onTimeRuleTap != null)
            _DashboardEntryTile(
              icon: Icons.schedule_rounded,
              title: 'Aviso por hora',
              subtitle: 'Crear un recordatorio con reloj',
              onTap: onTimeRuleTap!,
            ),
          if (onRulesTap != null)
            _DashboardEntryTile(
              icon: Icons.rule_rounded,
              title: 'Reglas',
              subtitle: 'Todas tus automatizaciones',
              onTap: onRulesTap!,
            ),
          if (onSettingsTap != null)
            _DashboardEntryTile(
              icon: Icons.settings_outlined,
              title: 'Configuración',
              subtitle: 'Modo, razonamiento, audio y permisos',
              onTap: onSettingsTap!,
            ),
          if (onMessagesTap != null)
            _DashboardEntryTile(
              icon: Icons.mark_chat_unread_outlined,
              title: 'Responder mensajes',
              subtitle: 'Ver notificaciones y responderlas',
              onTap: onMessagesTap!,
            ),
          const SizedBox(height: 16),
        ],
        const AutomationSectionLabel('Sugerencias'),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            // Mantiene un ancho táctil/legible real. En vertical estrecho pasa
            // a una columna; en horizontal aprovecha el espacio con 3 o 4 sin
            // reducir cada acción a un icono diminuto.
            final columns = constraints.maxWidth >= 680
                ? 4
                : constraints.maxWidth >= 470
                ? 3
                : constraints.maxWidth >= 330
                ? 2
                : 1;
            final itemWidth =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (label, goal, icon) in _actions)
                  SizedBox(
                    width: itemWidth,
                    child: _QuickActionTile(
                      icon: icon,
                      label: label,
                      onTap: () => onRun(goal),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Tile de acción rápida: glass óptico con icono + etiqueta (profesional,
/// hyperrealista, content-sized — nunca se estira). Ligero (glass estático).
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AutomationSurfaceCard(
    padding: EdgeInsets.zero,
    radius: 16,
    onTap: onTap,
    // UI-REV-02: tile compacto (48px) — el acceso directo ocupa lo justo,
    // sin la losa de 68px que rompía la proporción del dashboard.
    child: SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AutomationVisual.of(context).accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AutomationVisual.of(context).text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Entrada destacada a una pantalla hermana del dashboard (Mensajes, Dev).
/// Un solo widget para todos los accesos: icono + título + subtítulo.
class _DashboardEntryTile extends StatelessWidget {
  const _DashboardEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AutomationSurfaceCard(
      padding: EdgeInsets.zero,
      radius: 16,
      onTap: onTap,
      // UI-REV-02: tile compacto (52px) — mismo lenguaje que Dev.
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: AutomationVisual.of(context).accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AutomationVisual.of(context).text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AutomationVisual.of(context).textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AutomationVisual.of(context).textMuted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

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

import '../../application/automation_engine_provider.dart';
import '../../application/automation_feedback_presenter.dart';
import '../../domain/automation_goal.dart';
import '../../domain/automation_policy.dart';
import '../../domain/automation_result.dart';
import '../../engine/agent_dependencies.dart';
import '../../engine/perception/current_situation.dart';
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
    this.onDevTap,
  });

  /// Abre la configuración visual de Automatización. La lógica y la
  /// persistencia continúan perteneciendo a sus providers actuales.
  final VoidCallback? onSettingsTap;

  /// Abre la pantalla de Mensajes (función de usuario, no Dev).
  final VoidCallback? onMessagesTap;

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
      _voiceSession.state == VoiceSessionState.listening ||
      _voiceSession.state == VoiceSessionState.processing;

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

  Future<void> _runTask(
    String text, {
    ActionConfirmation? confirmation,
    bool fromVoice = false,
  }) async {
    final goal = text.trim();
    if (goal.isEmpty || _running || (_sensing && !fromVoice)) return;
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
      if (voiceEnabled) {
        // El resultado hablado es exactamente el resultado del mismo
        // AutomationEngine. "Audio" gobierna tanto órdenes escritas como de
        // micrófono; TTS es solo una salida y nunca cambia el veredicto.
        await _voiceSession.respond(_spokenResult(result));
      }
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
    );
    final composer = _TaskComposer(
      controller: _taskController,
      running: _running,
      voiceEnabled: settings.voiceEnabled,
      voiceState: _voiceState,
      observingScreen: _observingScreen,
      sensing: _sensing,
      senseFeedback: _senseFeedback,
      onVoice: _activateVoice,
      onVoiceOutputToggle: _toggleVoiceOutput,
      onObserve: _observeScreen,
      onRun: _runTask,
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
    );

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: NanoSpacing.xl),
              composer,
              if (active != null) ...[
                const SizedBox(height: NanoSpacing.lg),
                active,
              ],
              const SizedBox(height: NanoSpacing.xl),
              quick,
              const SizedBox(height: NanoSpacing.xl),
              const EngineStatusCard(cleanAppearance: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({
    required this.mode,
    required this.onModeTap,
    this.onDevTap,
  });
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;

  /// Atajo directo a las herramientas del agente (pantalla Dev). Icono robot,
  /// siempre visible en la cabecera sin necesidad de scroll.
  final VoidCallback? onDevTap;

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

class _TaskComposer extends StatelessWidget {
  const _TaskComposer({
    required this.controller,
    required this.running,
    required this.voiceEnabled,
    required this.voiceState,
    required this.observingScreen,
    required this.sensing,
    required this.senseFeedback,
    required this.onVoice,
    required this.onVoiceOutputToggle,
    required this.onObserve,
    required this.onRun,
  });
  final TextEditingController controller;
  final bool running;
  final bool voiceEnabled;
  final VoiceSessionState voiceState;
  final bool observingScreen;
  final bool sensing;
  final String? senseFeedback;
  final VoidCallback onVoice;
  final VoidCallback onVoiceOutputToggle;
  final VoidCallback onObserve;
  final ValueChanged<String> onRun;

  @override
  Widget build(BuildContext context) {
    final voiceActive =
        voiceState == VoiceSessionState.listening ||
        voiceState == VoiceSessionState.processing;
    final stateLabel = observingScreen
        ? 'Observando'
        : switch (voiceState) {
            VoiceSessionState.listening => 'Escuchando',
            VoiceSessionState.processing => 'Procesando',
            _ => running ? 'Ejecutando' : 'Listo',
          };
    final stateActive = voiceActive || observingScreen || sensing || running;
    // UI-REV-02: paddings y tipografía del composer acotados al lenguaje
    // Dev (card 16, título 16px) — antes 20/20 estiraba la pantalla.
    return AutomationSurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CapabilityHint(active: stateActive),
                    const SizedBox(height: 3),
                    Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          stateLabel,
                          key: ValueKey(stateLabel),
                          style: TextStyle(
                            color: stateActive
                                ? AutomationVisual.of(context).accent
                                : AutomationVisual.of(context).textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NanoAssistantMark(active: sensing || running),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (value) =>
                      !running && !sensing ? onRun(value) : null,
                  decoration: const InputDecoration(
                    hintText: 'Describe una tarea…',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox.square(
                dimension: 46,
                child: FilledButton(
                  onPressed: running || sensing
                      ? null
                      : () => onRun(controller.text),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: running
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AutomationVisual.of(context).onAccent,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ComposerControl(
                  icon: Icons.mic_none_rounded,
                  label: 'Voz',
                  active: voiceActive,
                  busy: voiceActive,
                  enabled: !running && !observingScreen,
                  onTap: onVoice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ComposerControl(
                  icon: voiceEnabled
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  label: 'Audio',
                  active: voiceEnabled,
                  enabled: true,
                  onTap: onVoiceOutputToggle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ComposerControl(
                  icon: Icons.visibility_outlined,
                  label: 'Ojos',
                  active: observingScreen,
                  busy: observingScreen,
                  enabled: !running && !sensing,
                  onTap: onObserve,
                ),
              ),
            ],
          ),
          if (senseFeedback != null && senseFeedback!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: NanoMotionDurations.quick,
              child: Text(
                senseFeedback!,
                key: ValueKey(senseFeedback),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AutomationVisual.of(context).textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Título del composer con los ALCANCES reales del agente. Inactivo: rota
/// frases cortas de lo que puede hacer (invita a pedir tareas reales). En
/// actividad: título fijo "¿Qué quieres que haga?" — el estado debajo ya
/// comunica el resto. Un solo Timer de texto, sin tickers decorativos.
class _CapabilityHint extends StatefulWidget {
  const _CapabilityHint({required this.active});

  /// true cuando escucha/observa/ejecuta: título fijo, sin rotación.
  final bool active;

  @override
  State<_CapabilityHint> createState() => _CapabilityHintState();
}

class _CapabilityHintState extends State<_CapabilityHint> {
  // Alcances verificables del agente — mismos dominios de las quick actions
  // y del pipeline real (apps/ajustes, mensajes, notificaciones, archivos,
  // terminal Linux). Nada que el motor no sepa hacer hoy.
  static const _capabilities = [
    'Abro apps y ajustes del dispositivo',
    'Respondo mensajes y notificaciones',
    'Leo y analizo tus notificaciones',
    'Analizo archivos y carpetas',
    'Ejecuto tareas en la terminal Linux',
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _capabilities.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: NanoMotionDurations.quick,
      child: Text(
        widget.active ? '¿Qué quieres que haga?' : _capabilities[_index],
        key: ValueKey(widget.active ? 'ask' : _capabilities[_index]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AutomationVisual.of(context).text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

class _ComposerControl extends StatelessWidget {
  const _ComposerControl({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // Deshabilitado: alpha 0.6 — visible pero claramente apagado. Antes 0.5
    // fundía el icono con el fondo y parecía roto.
    final color = active
        ? AutomationVisual.of(context).accent
        : enabled
        ? AutomationVisual.of(context).textMuted
        : AutomationVisual.of(context).textMuted.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: NanoMotionDurations.quick,
            // UI-REV-04: control mínimo (44px) — fila de 3 capacidades
            // ligera, sin competir con el composer ni el dashboard.
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? AutomationVisual.of(context).accentSoft
                  : AutomationVisual.of(context).inputFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? AutomationVisual.of(
                        context,
                      ).accent.withValues(alpha: 0.38)
                    : AutomationVisual.of(context).line,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(icon, color: color, size: 19),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NanoAssistantMark extends StatelessWidget {
  const _NanoAssistantMark({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      // UI-REV-04: marca compacta (44px) — acompaña al título sin dominar.
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [visual.accentSoft, visual.surface],
        ),
        border: Border.all(color: visual.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AutomationVisual.of(
              context,
            ).accent.withValues(alpha: active ? 0.24 : 0.10),
            blurRadius: active ? 14 : 8,
          ),
        ],
      ),
      child: Icon(
        Icons.smart_toy_outlined,
        color: AutomationVisual.of(context).accent,
        size: 22,
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
  });
  final ValueChanged<String> onRun;

  /// Abre la pantalla de Mensajes (función de usuario, destacada).
  final VoidCallback? onMessagesTap;

  /// Abre la configuración del agente. Vive aquí como tile con TEXTO visible
  /// (UI-REV-05) — el icono suelto de la cabecera estorbaba y era poco claro.
  final VoidCallback? onSettingsTap;

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
        if (onSettingsTap != null || onMessagesTap != null) ...[
          const AutomationSectionLabel('Accesos'),
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

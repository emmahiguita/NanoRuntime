import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_breakpoint.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_choice_group.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import '../../application/automation_engine_provider.dart';
import '../../domain/automation_goal.dart';
import '../../domain/automation_policy.dart';
import '../../domain/automation_result.dart';
import '../../ledger/action_ledger_provider.dart';
import '../../ledger/automation_trace.dart';

import 'engine_status_card.dart';
import 'package:nanoai/core/widgets/interactive_glass_card.dart';

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
  const AutomationDashboard({super.key, this.onDevTap, this.onMessagesTap});

  /// Abre la pantalla Dev (herramientas técnicas). null = no mostrar icono.
  final void Function(BuildContext context)? onDevTap;

  /// Abre la pantalla de Mensajes (función de usuario, no Dev).
  final VoidCallback? onMessagesTap;

  @override
  ConsumerState<AutomationDashboard> createState() =>
      _AutomationDashboardState();
}

class _AutomationDashboardState extends ConsumerState<AutomationDashboard> {
  final _taskController = TextEditingController();

  AutomationResultStatus? _lastStatus;
  String _lastGoal = '';
  bool _running = false;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _runTask(String text) async {
    final goal = text.trim();
    if (goal.isEmpty || _running) return;
    _taskController.clear();
    setState(() {
      _running = true;
      _lastGoal = goal;
      _lastStatus = null;
    });
    try {
      final result = await ref
          .read(automationEngineProvider)
          .runGoal(AutomationGoal(text: goal));
      if (mounted) setState(() {
        _lastStatus = result.status;
        _running = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _lastStatus = AutomationResultStatus.failed;
        _running = false;
      });
    }
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
                      'autonomous', 'Autónomo', Icons.auto_awesome_rounded),
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
    final mode = ref.watch(settingsProvider).agentAutomationMode;

    // Responsive: en wide (landscape/tablet) divide en 2 columnas para
    // APROVECHAR el ancho (composer+quick a la izquierda, estado+recientes a la
    // derecha). En portrait una columna compacta que encaja en pantalla.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= NanoBreakpoints.mediumMax;

        final header = _AgentHeader(
          mode: mode,
          onModeTap: _pickMode,
          onDevTap: widget.onDevTap,
        );
        final composer = _TaskComposer(
          controller: _taskController,
          running: _running,
          onRun: _runTask,
        );
        final active = (_running || _lastStatus != null)
            ? _ActiveExecutionCard(
                goal: _lastGoal,
                running: _running,
                status: _lastStatus,
              )
            : null;
        final quick = QuickAutomationActions(
          onRun: _runTask,
          onMessagesTap: widget.onMessagesTap,
        );

        final left = <Widget>[
          composer,
          if (active != null) ...[
            const SizedBox(height: NanoSpacing.sm),
            active,
          ],
          const SizedBox(height: NanoSpacing.sm),
          quick,
        ];
        final right = <Widget>[
          const EngineStatusCard(),
          const SizedBox(height: NanoSpacing.sm),
          const RecentExecutionsCard(),
        ];

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            NanoSpacing.sm, NanoSpacing.sm, NanoSpacing.sm, NanoSpacing.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 1100 : 720),
              child: wide
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: NanoSpacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Columnas acotadas (máx 520) → las cards NO se
                            // estiran a todo el ancho en horizontal.
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 520),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: left,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: NanoSpacing.xl),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 520),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: right,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: NanoSpacing.sm),
                        ...left,
                        const SizedBox(height: NanoSpacing.sm),
                        ...right,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _AgentHeader extends ConsumerWidget {
  const _AgentHeader({
    required this.mode,
    required this.onModeTap,
    this.onDevTap,
  });
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final void Function(BuildContext context)? onDevTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    // La cabecera se deriva del MISMO engineStatusProvider que la card Estado:
    // nunca puede contradecir el estado real del motor. No hay "Listo" verde
    // si el runtime no lo está.
    final engine = ref.watch(engineStatusProvider).valueOrNull;
    final ready = engine?.phase == EnginePhase.ready;
    final dotColor = ready ? colors.success : colors.warning;
    final modelName = engine?.modelPath == null
        ? 'Modelo no cargado'
        : _friendlyModelName(engine!.modelPath!);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: NanoSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NANO AGENT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colors.textPrimary,
                  )),
              Text(
                ready ? 'Listo · $modelName' : 'Motor detenido · $modelName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NanoType.label(
                  ready ? colors.onSurfaceVariant : colors.warning,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onModeTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Modo: ${mode.label.toUpperCase()} ›',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.accentCyan,
                    )),
              ],
            ),
          ),
        ),
        if (onDevTap != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Dev',
            visualDensity: VisualDensity.compact,
            onPressed: () => onDevTap!(context),
            icon: Icon(Icons.build_circle_rounded,
                size: 20, color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Nombre de modelo amigable a partir de la ruta/archivo real. Nunca muestra
/// el path técnico completo; si no se puede derivar, cae al nombre corto.
String _friendlyModelName(String path) {
  var s = path.split('/').last;
  s = s.replaceAll(RegExp(r'\.gguf$'), '');
  s = s.replaceAll(RegExp(r'_Q[0-9]_[A-Za-z0-9]+$'), '');
  s = s.replaceAll(RegExp(r'-instruct$'), '');
  // qwen2.5-1.5b -> "Qwen 2.5 1.5B"
  final m = RegExp(r'^([a-z0-9]+?)[-.]?(\d+(?:\.\d+)?b)').firstMatch(s);
  if (m != null) {
    final fam = m.group(1)!.replaceAllMapped(
      RegExp(r'[a-z]+'),
      (mm) => mm.group(0)![0].toUpperCase() + mm.group(0)!.substring(1),
    );
    return '$fam ${m.group(2)!.toUpperCase()}';
  }
  return s;
}

class _TaskComposer extends StatelessWidget {
  const _TaskComposer({
    required this.controller,
    required this.running,
    required this.onRun,
  });
  final TextEditingController controller;
  final bool running;
  final ValueChanged<String> onRun;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    // Composer = GLASS ESTÁTICO (surface, sin tilt ni shimmer): en una
    // pantalla operativa el input no debe tener movimiento permanente.
    return NanoOpticalSurface(
      accent: colors.accentCyan,
      blurSigma: 20,
      borderStrength: 0.7,
      child: Padding(
          padding: const EdgeInsets.all(NanoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Qué quieres que haga?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: colors.textPrimary)),
              const SizedBox(height: NanoSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (v) =>
                          !running ? onRun(v) : null,
                      decoration: InputDecoration(
                        hintText: 'Describe una tarea…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colors.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: NanoSpacing.sm),
                  FilledButton(
                    onPressed: running
                        ? null
                        : () => onRun(controller.text),
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: running
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ],
          ),
      ),
    );
  }
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
    case AutomationResultStatus.cancelled:
      return (
        icon: Icons.not_interested_rounded,
        color: colors.onSurfaceVariant,
        label: 'Cancelado',
      );
  }
}

class _ActiveExecutionCard extends StatelessWidget {
  const _ActiveExecutionCard({
    required this.goal,
    required this.running,
    required this.status,
  });
  final String goal;
  final bool running;
  final AutomationResultStatus? status;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final done = !running && status != null;
    final present = done ? _statusPresentation(status!, colors) : null;
    return InteractiveGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  present?.icon ?? Icons.auto_awesome_rounded,
                  color: present?.color ?? colors.accentLavender,
                  size: 20,
                ),
                const SizedBox(width: NanoSpacing.sm),
                Expanded(
                  child: Text(goal,
                      maxLines: 4,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: colors.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: NanoSpacing.sm),
            Text(
              running
                  ? 'Ejecutando…'
                  : (present?.label ?? ''),
              style: NanoType.label(
                present?.color ?? colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atajos de tareas comunes → runGoal(preset).
class QuickAutomationActions extends StatelessWidget {
  const QuickAutomationActions({required this.onRun, this.onMessagesTap});
  final ValueChanged<String> onRun;

  /// Abre la pantalla de Mensajes (función de usuario, destacada).
  final VoidCallback? onMessagesTap;

  static const _actions = [
    ('Activar Bluetooth', 'activar Bluetooth', Icons.bluetooth_rounded),
    ('Abrir Chrome', 'abrir Chrome', Icons.public_rounded),
    ('Abrir Linux', 'abrir la terminal Linux', Icons.terminal_rounded),
    ('Leer notificaciones', 'leer las notificaciones', Icons.notifications_active_rounded),
    ('Analizar archivos', 'analizar los archivos', Icons.folder_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Sugerencias', Icons.bolt_rounded, colors: colors),
        const SizedBox(height: NanoSpacing.xs),
        if (onMessagesTap != null) ...[
          // Función de USUARIO destacada (no una tarea técnica).
          _MessagesEntryTile(onTap: onMessagesTap!),
        ],
        Wrap(
          spacing: NanoSpacing.sm,
          runSpacing: NanoSpacing.sm,
          children: [
            for (final (label, goal, icon) in _actions)
              _QuickActionTile(
                icon: icon,
                label: label,
                onTap: () => onRun(goal),
              ),
          ],
        ),
      ],
    );
  }
}

/// Tile de acción rápida: glass óptico con icono + etiqueta (profesional,
/// hyperrealista, content-sized — nunca se estira). Ligero (glass estático).
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    // Tile de acción = superficie estática con feedback táctil (press-scale
    // vía onTap). Sin tilt ni shimmer: no es el protagonista.
    return NanoOpticalSurface(
      borderStrength: 0.4,
      reflectionStrength: 0.28,
      blurSigma: 12,
      accent: colors.accentCyan,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: NanoSpacing.md, vertical: NanoSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: colors.accentCyan),
                const SizedBox(width: NanoSpacing.sm),
                Text(label, style: NanoType.label(colors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrada destacada a la función de usuario "Responder mensajes".
class _MessagesEntryTile extends StatelessWidget {
  final VoidCallback onTap;
  const _MessagesEntryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: NanoSpacing.sm),
      child: NanoOpticalSurface(
        accent: colors.accentLavender,
        borderStrength: 0.6,
        blurSigma: 14,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: NanoSpacing.md, vertical: NanoSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.forward_to_inbox_rounded,
                  color: colors.accentLavender, size: 20),
              const SizedBox(width: NanoSpacing.sm),
              Expanded(
                child: Text(
                  'Responder mensajes',
                  style: NanoType.body(colors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: NanoSpacing.sm),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Últimas ejecuciones reales (del ledger), recientes primero.
class RecentExecutionsCard extends ConsumerWidget {
  const RecentExecutionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final traces = ref.watch(actionLedgerProvider).entries;
    // Card ESTÁTICA (surface, sin shimmer/tilt): el historial no es el
    // protagonista; solo la ejecución activa anima.
    return NanoOpticalSurface(
      borderStrength: 0.45,
      reflectionStrength: 0.28,
      blurSigma: 12,
      padding: const EdgeInsets.all(NanoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader('Ejecuciones recientes', Icons.history_rounded,
              colors: colors),
          const SizedBox(height: NanoSpacing.xs),
          if (traces.isEmpty)
            Text('Sin ejecuciones todavía.',
                style: NanoType.body(colors.onSurfaceVariant))
          else ...[
            for (final t in traces.take(3))
              _HistoryTile(trace: t, colors: colors),
            const SizedBox(height: NanoSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showFullHistory(context, traces, colors),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('Ver historial'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullHistory(
    BuildContext context,
    List<AutomationTrace> traces,
    NanoColors colors,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                NanoSpacing.lg, 0, NanoSpacing.lg, NanoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Historial completo', Icons.history_rounded,
                    colors: colors),
                const SizedBox(height: NanoSpacing.sm),
                Expanded(
                  child: ListView.builder(
                    controller: scroll,
                    itemCount: traces.length,
                    itemBuilder: (_, i) => _HistoryTile(
                      trace: traces[i],
                      colors: colors,
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

/// Una fila del historial: estado honesto + objetivo (2 líneas) + tiempo
/// relativo. Tap → detalles completos (sin truncar).
class _HistoryTile extends StatelessWidget {
  final AutomationTrace trace;
  final NanoColors colors;

  const _HistoryTile({
    required this.trace,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final p = _statusPresentation(trace.status, colors);
    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(p.icon, size: 16, color: p.color),
            const SizedBox(width: NanoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trace.goal,
                      maxLines: 2,
                      style: NanoType.body(colors.textPrimary)),
                  Text(p.label,
                      style: NanoType.label(p.color)),
                ],
              ),
            ),
            const SizedBox(width: NanoSpacing.sm),
            Text(_relativeTime(
                trace.endedAt.difference(trace.startedAt)),
                style: NanoType.label(colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final p = _statusPresentation(trace.status, colors);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final c = NanoThemeExtension.of(ctx).colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                NanoSpacing.lg, 0, NanoSpacing.lg, NanoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Detalle de ejecución', p.icon,
                    colors: c, iconColor: p.color),
                const SizedBox(height: NanoSpacing.sm),
                Text(trace.goal,
                    style: NanoType.body(c.onSurface).copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: NanoSpacing.sm),
                Text('Estado: ${p.label}',
                    style: NanoType.body(p.color)),
                if (trace.summary.isNotEmpty) ...[
                  const SizedBox(height: NanoSpacing.sm),
                  SelectableText(trace.summary,
                      style: NanoType.body(c.onSurfaceVariant)),
                ],
                const SizedBox(height: NanoSpacing.sm),
                Text(
                  'Duración: ${_relativeTime(trace.endedAt.difference(trace.startedAt))}',
                  style: NanoType.label(c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Tiempo relativo humano ("hace 3 min"), honesto y legible.
String _relativeTime(Duration d) {
  if (d.inSeconds < 60) return 'hace ${d.inSeconds}s';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

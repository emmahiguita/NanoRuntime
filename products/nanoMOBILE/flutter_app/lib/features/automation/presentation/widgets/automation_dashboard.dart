import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_breakpoint.dart';
import 'package:nanoai/core/theme/nano_type.dart';
import 'package:nanoai/core/widgets/nano_choice_group.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import '../../application/automation_engine_provider.dart';
import '../../domain/automation_goal.dart';
import '../../domain/automation_policy.dart';
import '../../domain/automation_result.dart';
import '../../ledger/action_ledger_provider.dart';

import 'engine_status_card.dart';
import 'interactive_glass_card.dart';

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
  const AutomationDashboard({super.key, this.onDevTap});

  /// Abre la pantalla Dev (herramientas técnicas). null = no mostrar icono.
  final void Function(BuildContext context)? onDevTap;

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
        final quick = QuickAutomationActions(onRun: _runTask);

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

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({
    required this.mode,
    required this.onModeTap,
    this.onDevTap,
  });
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final void Function(BuildContext context)? onDevTap;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colors.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.success.withValues(alpha: 0.5),
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
              Text('Listo · Local · 1.5B',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NanoType.label(colors.onSurfaceVariant)),
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
    return InteractiveGlassCard(
      accent: colors.accentCyan,
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
    final ok = status == AutomationResultStatus.completed ||
        status == AutomationResultStatus.completedUnverified;
    return NanoCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  done
                      ? (ok ? Icons.check_circle_rounded : Icons.error_rounded)
                      : Icons.auto_awesome_rounded,
                  color: done
                      ? (ok ? colors.success : colors.error)
                      : colors.accentLavender,
                  size: 20,
                ),
                const SizedBox(width: NanoSpacing.sm),
                Expanded(
                  child: Text(goal,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: colors.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: NanoSpacing.sm),
            Text(
              running
                  ? 'Ejecutando…'
                  : (ok ? 'Verificado · ${status!.name}' : 'Resultado: ${status!.name}'),
              style: NanoType.label(colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atajos de tareas comunes → runGoal(preset).
class QuickAutomationActions extends StatelessWidget {
  const QuickAutomationActions({required this.onRun});
  final ValueChanged<String> onRun;

  static const _actions = [
    ('Bluetooth', 'activar Bluetooth'),
    ('Chrome', 'abrir Chrome'),
    ('Linux', 'abrir la terminal Linux'),
    ('Notificaciones', 'leer las notificaciones'),
    ('Archivos', 'analizar los archivos'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Sugerencias', Icons.bolt_rounded, colors: colors),
        const SizedBox(height: NanoSpacing.xs),
        Wrap(
          spacing: NanoSpacing.sm,
          runSpacing: NanoSpacing.sm,
          children: [
            for (final (label, goal) in _actions)
              ActionChip(
                label: Text(label),
                onPressed: () => onRun(goal),
                backgroundColor: colors.surfaceVariant,
                side: BorderSide.none,
                labelStyle: TextStyle(color: colors.textPrimary),
              ),
          ],
        ),
      ],
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
    return InteractiveGlassCard(
      borderStrength: 0.45,
      reflectionStrength: 0.28,
      blurSigma: 12,
      glassOpacityScale: 0.78,
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Ejecuciones recientes', Icons.history_rounded, colors: colors),
            const SizedBox(height: NanoSpacing.xs),
            if (traces.isEmpty)
              Text('Sin ejecuciones todavía.',
                  style: NanoType.body(colors.onSurfaceVariant))
            else
              // Bounded: máximo 4 + altura límite con scroll interno → la card
              // no empuja el resto del dashboard en pantallas verticales.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 132),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final t in traces.take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _statusIcon(t.status),
                                size: 16,
                                color: _statusColor(t.status, colors),
                              ),
                              const SizedBox(width: NanoSpacing.sm),
                              Expanded(
                                child: Text(t.goal,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: NanoType.body(colors.textPrimary)),
                              ),
                              const SizedBox(width: NanoSpacing.sm),
                              Text('${t.duration.inMilliseconds}ms',
                                  style: NanoType.label(
                                      colors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(AutomationResultStatus s) => switch (s) {
        AutomationResultStatus.completed ||
        AutomationResultStatus.completedUnverified =>
          Icons.check_circle_rounded,
        AutomationResultStatus.denied => Icons.block_rounded,
        AutomationResultStatus.failed => Icons.error_rounded,
        AutomationResultStatus.cancelled => Icons.cancel_rounded,
        _ => Icons.pending_rounded,
      };

  dynamic _statusColor(AutomationResultStatus s, dynamic colors) => switch (s) {
        AutomationResultStatus.completed ||
        AutomationResultStatus.completedUnverified =>
          colors.success,
        AutomationResultStatus.denied => colors.warning,
        AutomationResultStatus.failed => colors.error,
        _ => colors.onSurfaceVariant,
      };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_choice_group.dart';
import 'package:nanoai/core/widgets/nano_components.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/core/widgets/nano_section.dart';

import '../../application/automation_engine_provider.dart';
import '../../domain/automation_goal.dart';
import '../../domain/automation_policy.dart';
import '../../domain/automation_result.dart';
import '../../ledger/action_ledger_provider.dart';

/// El centro de control del asistente: cabecera de estado, composer de tareas,
/// quick actions, estado de capacidades y ejecuciones recientes.
///
/// Reemplaza la antigua "consola de tests" por un dashboard orientado al
/// usuario. Las herramientas técnicas viven en la pantalla Dev (no acá).
class AutomationDashboard extends ConsumerStatefulWidget {
  const AutomationDashboard({super.key});

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

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        NanoSpacing.md, NanoSpacing.md, NanoSpacing.md, NanoSpacing.xxxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AgentHeader(mode: mode, onModeTap: _pickMode),
              const SizedBox(height: NanoSpacing.lg),
              _TaskComposer(
                controller: _taskController,
                running: _running,
                onRun: _runTask,
              ),
              if (_running || _lastStatus != null) ...[
                const SizedBox(height: NanoSpacing.lg),
                _ActiveExecutionCard(
                  goal: _lastGoal,
                  running: _running,
                  status: _lastStatus,
                ),
              ],
              const SizedBox(height: NanoSpacing.lg),
              QuickAutomationActions(onRun: _runTask),
              const SizedBox(height: NanoSpacing.lg),
              const CapabilitiesCard(),
              const SizedBox(height: NanoSpacing.lg),
              const RecentExecutionsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({required this.mode, required this.onModeTap});
  final AgentAutomationMode mode;
  final VoidCallback onModeTap;

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
              Text('Listo para trabajar · Local · 1.5B',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
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
    return NanoOpticalSurface(
      borderRadius: NanoRadius.large,
      borderStrength: 0.7,
      reflectionStrength: 0.4,
      blurSigma: 14,
      glassOpacityScale: 0.85,
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
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (v) => !running ? onRun(v) : null,
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
                  onPressed: running ? null : () => onRun(controller.text),
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
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
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

/// Estado de las capacidades (runtime/accesibilidad/Linux) — de forma compacta.
class CapabilitiesCard extends ConsumerWidget {
  const CapabilitiesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NanoThemeExtension.of(context).colors;
    final engine = ref.watch(runtimeEngineProvider);
    return NanoCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Estado', Icons.monitor_heart_rounded, colors: colors),
            const SizedBox(height: NanoSpacing.xs),
            _row(context, 'Agente', engine.isLive),
            _row(context, 'Runtime', engine.phase.name),
            _row(context, 'Modelo', engine.modelPath?.split('/').last ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, dynamic value) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
          ),
        ],
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
    return NanoCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(NanoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Ejecuciones recientes', Icons.history_rounded, colors: colors),
            const SizedBox(height: NanoSpacing.xs),
            if (traces.isEmpty)
              Text('Sin ejecuciones todavía.',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13))
            else
              for (final t in traces.take(6))
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
                            style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                      ),
                      const SizedBox(width: NanoSpacing.sm),
                      Text('${t.duration.inMilliseconds}ms',
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant)),
                    ],
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

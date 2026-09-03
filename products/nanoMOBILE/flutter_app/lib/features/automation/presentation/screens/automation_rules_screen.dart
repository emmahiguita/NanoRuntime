import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/engine/scheduling/scheduled_rule.dart';
import 'package:nanoai/features/automation/engine/scheduling/trigger.dart';

import '../automation_visual_theme.dart';

/// Gestión de reglas de automatización (listar / activar / desactivar / borrar).
///
/// Solo lee y muta el [RuleRegistry] — la MISMA fuente que consulta el pipeline
/// de notificaciones. La ejecución sigue en el AutomationCoordinator: esta
/// pantalla jamás ejecuta nada. El borrado pide confirmación (irreversible);
/// el switch activa/desactiva directo (reversible).
class AutomationRulesScreen extends ConsumerStatefulWidget {
  const AutomationRulesScreen({super.key});

  @override
  ConsumerState<AutomationRulesScreen> createState() =>
      _AutomationRulesScreenState();
}

class _AutomationRulesScreenState
    extends ConsumerState<AutomationRulesScreen> {
  List<ScheduledRule> _rules = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// El provider dispara `load()` al crearse; re-leer aquí garantiza que la
  /// lista no se muestre vacía por la carrera de hidratación.
  Future<void> _refresh() async {
    final registry = ref.read(ruleRegistryProvider);
    await registry.load();
    if (mounted) {
      setState(() {
        _rules = registry.rules;
        _loaded = true;
      });
    }
  }

  void _toggle(ScheduledRule rule, bool enabled) {
    ref.read(ruleRegistryProvider).setEnabled(rule.id, enabled);
    setState(() => _rules = ref.read(ruleRegistryProvider).rules);
  }

  Future<void> _confirmDelete(ScheduledRule rule) async {
    final visual = AutomationVisual.of(context);
    final danger = NanoThemeExtension.of(context).colors.danger;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: visual.surface,
        title: const Text('Borrar regla'),
        content: Text(
          'Se eliminará la regla "${rule.id}". Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: danger,
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(ruleRegistryProvider).remove(rule.id);
      setState(() => _rules = ref.read(ruleRegistryProvider).rules);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Scaffold(
      backgroundColor: visual.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const AutomationBackHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Reglas',
                            style: TextStyle(
                              color: visual.text,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cuándo y cómo Nano responde por ti. Las reglas '
                            'activas se evalúan con cada notificación.',
                            style: TextStyle(
                              color: visual.textMuted,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (!_loaded)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_rules.isEmpty)
                            _EmptyState(visual: visual)
                          else
                            for (final rule in _rules) ...[
                              _RuleCard(
                                rule: rule,
                                onToggle: (v) => _toggle(rule, v),
                                onDelete: () => _confirmDelete(rule),
                              ),
                              const SizedBox(height: 12),
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
  });

  final ScheduledRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  static String _actionLabel(RuleAction action) => switch (action) {
    RuleAction.reply => 'Responder',
    RuleAction.notify => 'Avisar',
    RuleAction.draft => 'Borrador',
  };

  static String _triggerLabel(Trigger trigger) {
    if (trigger is NotificationTrigger) {
      final package = trigger.packageName ?? 'cualquier app';
      final sender = trigger.senderMatch;
      if (sender == null || sender.isEmpty) return package;
      return '$package · contacto "$sender"';
    }
    if (trigger is ConnectivityTrigger) return 'wifi';
    if (trigger is BatteryTrigger) {
      return 'batería < ${trigger.belowPercent}%';
    }
    return trigger.runtimeType.toString();
  }

  static String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final danger = NanoThemeExtension.of(context).colors.danger;
    final actionDetail = rule.action == RuleAction.reply && !rule.dynamicReply
        ? (rule.message.isEmpty ? 'sin texto (fail-closed)' : '"${rule.message}"')
        : rule.dynamicReply
        ? 'respuesta dinámica (LLM local)'
        : null;
    final lastFired = rule.lastFiredAt;
    return AutomationSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: rule.enabled ? visual.accentSoft : visual.inputFill,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.rule_rounded,
                  color: rule.enabled ? visual.accent : visual.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_actionLabel(rule.action)} · ${_triggerLabel(rule.trigger)}',
                      style: TextStyle(
                        color: visual.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (actionDetail != null)
                      Text(
                        actionDetail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: visual.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        rule.id,
                        'creada ${_hhmm(rule.createdAt)}',
                        if (lastFired != null) 'última ${_hhmm(lastFired)}',
                      ].join(' · '),
                      style: TextStyle(
                        color: visual.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.enabled,
                onChanged: onToggle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Borrar'),
              style: TextButton.styleFrom(
                foregroundColor: danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.visual});

  final AutomationVisualPalette visual;

  @override
  Widget build(BuildContext context) {
    return AutomationSurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(Icons.rule_rounded, color: visual.textMuted, size: 32),
            const SizedBox(height: 10),
            Text(
              'Sin reglas todavía',
              style: TextStyle(
                color: visual.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pídele a Nano en el chat: "responde X a Y" y la regla '
              'aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: visual.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

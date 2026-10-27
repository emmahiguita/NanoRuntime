part of 'automation_rules_screen.dart';

extension _AutomationRulesDialogs on _AutomationRulesScreenState {
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
            style: FilledButton.styleFrom(backgroundColor: danger),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      if (rule.action == RuleAction.sendMessage) {
        await ScheduledWhatsAppMessageService().cancel(rule.id);
        if (!mounted) return;
      }
      ref.read(ruleRegistryProvider).remove(rule.id);
      setState(() => _rules = ref.read(ruleRegistryProvider).rules);
    }
  }

  Future<void> _editRule(ScheduledRule rule) async {
    final updated = await showNanoGlassWindow<ScheduledRule>(
      context: context,
      builder: (context) => RuleEditSheet(rule: rule),
    );
    if (updated == null || !mounted) return;
    if (rule.action == RuleAction.sendMessage ||
        updated.action == RuleAction.sendMessage) {
      final scheduler = ScheduledWhatsAppMessageService();
      if (updated.action == RuleAction.sendMessage && updated.enabled) {
        final scheduled = await scheduler.schedule(updated);
        if (!mounted) return;
        if (!scheduled.scheduled) {
          setState(() => _createError = scheduled.reason);
          return;
        }
      } else if (rule.action == RuleAction.sendMessage) {
        await scheduler.cancel(rule.id);
      }
    }
    if (!mounted) return;
    ref.read(ruleRegistryProvider).update(rule.id, updated);
    setState(() => _rules = ref.read(ruleRegistryProvider).rules);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Regla actualizada: ${rule.id}')));
  }
}

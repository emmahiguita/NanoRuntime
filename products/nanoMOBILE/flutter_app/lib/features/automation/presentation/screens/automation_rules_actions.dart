part of 'automation_rules_screen.dart';

// automation_rules_actions.dart
//
// QUÉ HACE:
// Acciones, parsing de reglas en lenguaje natural, selección de multimedia y organización de secciones.
//
// CÓMO FUNCIONA:
// - Parsea disparadores mediante TriggerParser (notificaciones, horarios, remitentes).
// - Maneja el selector de archivos multimedia con FilePicker y copiado seguro al catálogo.
// - Agrupa reglas visualmente por canal (WhatsApp por contacto, Horarios y Otras).
// - Gestiona el diálogo de confirmación de borrado y el editor inferior (RuleEditSheet).
//
// POR QUÉ:
// Aplica Single Responsibility Principle (SRP) separando la lógica interactiva del árbol visual (< 200 líneas).

extension _AutomationRulesActions on _AutomationRulesScreenState {
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

  Future<void> _createRule() => _createRuleFromText(_createController.text);

  Future<void> _createRuleFromText(String raw) async {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return;
    final parsed = const TriggerParser().parse(text);
    if (parsed == null) {
      setState(() => _createError =
          'No entendí el disparo. Prueba «a las 8:30 avísame que es hora», '
          '«cuando Juan me escriba, respóndele...» o «si dice noche, respóndele...».');
      return;
    }
    final goal = parsed.goal.trim();
    final String message;
    final RuleAction action;
    var dynamicReply = false;
    if (_AutomationRulesScreenState._replyVerbs.hasMatch(goal)) {
      action = RuleAction.reply;
      message = goal.replaceFirst(_AutomationRulesScreenState._replyVerbs, '').trim();
      dynamicReply = message.isEmpty;
    } else if (_AutomationRulesScreenState._sendVerbs.hasMatch(goal)) {
      action = RuleAction.sendMedia;
      message = goal.replaceFirst(_AutomationRulesScreenState._sendVerbs, '').trim();
    } else {
      action = RuleAction.notify;
      message = goal.replaceFirst(_AutomationRulesScreenState._notifyVerbs, '').trim();
    }
    final needsSender = action == RuleAction.reply || action == RuleAction.sendMedia;
    if (parsed.trigger is TimeTrigger && needsSender) {
      setState(() => _createError =
          'Responder y enviar archivos necesitan un remitente: usa un trigger de notificación. Con hora solo puedo avisarte.');
      return;
    }
    if (action == RuleAction.sendMedia && _pendingMediaPath == null) {
      setState(() => _createError = 'Elige un archivo antes de crear la regla de envío.');
      return;
    }

    String? mediaPath;
    if (action == RuleAction.sendMedia) {
      mediaPath = await const WhatsAppMediaShare().copyToCatalog(_pendingMediaPath!);
      if (mediaPath == null) {
        if (!mounted) return;
        setState(() => _createError = 'No se pudo copiar el archivo al catálogo.');
        return;
      }
    }

    final rule = ref.read(ruleCreatorProvider).create(
          trigger: parsed.trigger,
          action: action,
          message: message,
          dynamicReply: dynamicReply,
          mediaPath: mediaPath,
        );
    if (!mounted) return;
    setState(() {
      _rules = ref.read(ruleRegistryProvider).rules;
      _createError = null;
      _pendingMediaPath = null;
      _pendingMediaName = null;
    });
    _createController.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Regla creada: ${rule.id}')));
  }

  Future<void> _pickMedia() async {
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final file = picked?.files.single;
    if (file == null || file.path == null) return;
    setState(() {
      _pendingMediaPath = file.path;
      _pendingMediaName = file.name;
      _createError = null;
    });
  }

  void _toggle(ScheduledRule rule, bool enabled) {
    ref.read(ruleRegistryProvider).setEnabled(rule.id, enabled);
    setState(() => _rules = ref.read(ruleRegistryProvider).rules);
  }

  List<Widget> _buildSections(AutomationVisualPalette visual) {
    final whatsapp = _rules.where(_isMessagingRule).toList();
    final timed = _rules.where((r) => r.trigger is TimeTrigger && !_isMessagingRule(r)).toList();
    final others = _rules.where((r) => !_isMessagingRule(r) && r.trigger is! TimeTrigger).toList();

    final sections = <Widget>[];
    if (whatsapp.isNotEmpty) {
      sections.add(const _SectionHeader(title: 'WhatsApp', imageAsset: 'assets/automation/icons/icon_respuestas_wpp.png'));
      final byContact = <String, List<ScheduledRule>>{};
      for (final rule in whatsapp) {
        final trigger = rule.trigger as NotificationTrigger;
        final contact = trigger.senderMatch?.trim() ?? 'Cualquier contacto';
        byContact.putIfAbsent(contact, () => []).add(rule);
      }
      final contacts = byContact.keys.toList()..sort();
      for (final contact in contacts) {
        sections.add(_ContactLabel(contact: contact, visual: visual));
        sections.addAll(byContact[contact]!.map((rule) => _ruleCard(rule)));
      }
    }
    if (timed.isNotEmpty) {
      sections.add(const _SectionHeader(title: 'Horarios', imageAsset: 'assets/automation/icons/icon_horarios.png'));
      sections.addAll(timed.map((rule) => _ruleCard(rule)));
    }
    if (others.isNotEmpty) {
      sections.add(const _SectionHeader(title: 'Otras automatizaciones', imageAsset: 'assets/automation/icons/icon_reglas.png'));
      sections.addAll(others.map((rule) => _ruleCard(rule)));
    }
    return sections;
  }

  Widget _ruleCard(ScheduledRule rule) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _RuleCard(
          rule: rule,
          onToggle: (v) => _toggle(rule, v),
          onDelete: () => _confirmDelete(rule),
          onEdit: () => _editRule(rule),
        ),
      );

  Future<void> _confirmDelete(ScheduledRule rule) async {
    final visual = AutomationVisual.of(context);
    final danger = NanoThemeExtension.of(context).colors.danger;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: visual.surface,
        title: const Text('Borrar regla'),
        content: Text('Se eliminará la regla "${rule.id}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: danger),
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

  Future<void> _editRule(ScheduledRule rule) async {
    final updated = await showModalBottomSheet<ScheduledRule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RuleEditSheet(rule: rule),
    );
    if (updated == null || !mounted) return;
    ref.read(ruleRegistryProvider).update(rule.id, updated);
    setState(() => _rules = ref.read(ruleRegistryProvider).rules);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Regla actualizada: ${rule.id}')));
  }

  bool _isMessagingRule(ScheduledRule rule) {
    final trigger = rule.trigger;
    if (trigger is! NotificationTrigger) return false;
    final package = trigger.packageName?.toLowerCase() ?? '';
    return trigger.senderMatch != null || trigger.textMatch != null || package.contains('whatsapp');
  }
}

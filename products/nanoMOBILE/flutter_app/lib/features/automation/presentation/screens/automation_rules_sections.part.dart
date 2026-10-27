part of 'automation_rules_screen.dart';

// automation_rules_sections.part.dart
//
// QUÉ HACE:
// Organización de secciones, edición, activación y borrado de reglas de automatización.

extension _AutomationRulesSections on _AutomationRulesScreenState {
  Widget _buildRulesLayout(AutomationVisualPalette visual) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDeviceLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final isLandscape = isDeviceLandscape && constraints.maxWidth >= 600;

        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reglas',
              style: TextStyle(
                color: visual.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Automatiza acciones cuando ocurran eventos.',
              style: TextStyle(color: visual.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _RuleCreatorCard(
              controller: _createController,
              error: _createError,
              pendingMediaName: _pendingMediaName,
              onCreate: _createRule,
              onPickMedia: _pickMedia,
            ),
          ],
        );

        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLandscape) ...[
              Text(
                'REGLAS ACTIVAS',
                style: NanoType.label(
                  visual.textMuted,
                ).copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),
            ],
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_rules.isEmpty)
              _EmptyState(visual: visual)
            else
              ..._buildSections(visual),
          ],
        );

        final content = isLandscape
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: leftColumn),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: rightColumn),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [leftColumn, const SizedBox(height: 16), rightColumn],
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: content,
        );
      },
    );
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

  Future<void> _toggle(ScheduledRule rule, bool enabled) async {
    final scheduledService = ScheduledWhatsAppMessageService();
    if (rule.action == RuleAction.sendMessage) {
      if (enabled) {
        final scheduled = await scheduledService.schedule(
          rule.copyWith(enabled: true),
        );
        if (!mounted) return;
        if (!scheduled.scheduled) {
          setState(() => _createError = scheduled.reason);
          return;
        }
      } else {
        await scheduledService.cancel(rule.id);
      }
    }
    ref.read(ruleRegistryProvider).setEnabled(rule.id, enabled);
    setState(() => _rules = ref.read(ruleRegistryProvider).rules);
  }

  List<Widget> _buildSections(AutomationVisualPalette visual) {
    final whatsapp = _rules.where(_isMessagingRule).toList();
    final timed = _rules
        .where((r) => r.trigger is TimeTrigger && !_isMessagingRule(r))
        .toList();
    final others = _rules
        .where((r) => !_isMessagingRule(r) && r.trigger is! TimeTrigger)
        .toList();

    final sections = <Widget>[];
    if (whatsapp.isNotEmpty) {
      sections.add(
        const _SectionHeader(
          title: 'WhatsApp',
          imageAsset: 'assets/automation/icons/icon_respuestas_wpp.png',
        ),
      );
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
      sections.add(
        const _SectionHeader(
          title: 'Horarios',
          imageAsset: 'assets/automation/icons/icon_horarios.png',
        ),
      );
      sections.addAll(timed.map((rule) => _ruleCard(rule)));
    }
    if (others.isNotEmpty) {
      sections.add(
        const _SectionHeader(
          title: 'Otras automatizaciones',
          imageAsset: 'assets/automation/icons/icon_reglas.png',
        ),
      );
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

  bool _isMessagingRule(ScheduledRule rule) {
    final trigger = rule.trigger;
    if (trigger is! NotificationTrigger) return false;
    final package = trigger.packageName?.toLowerCase() ?? '';
    return trigger.senderMatch != null ||
        trigger.textMatch != null ||
        package.contains('whatsapp');
  }
}

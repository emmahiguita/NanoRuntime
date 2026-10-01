// business_profile_edit_dialog.dart
//
// QUÉ HACE: edita todos los campos operativos del perfil activo.
// CÓMO: usa campos guiados y formatos de línea validados antes de guardar.
// POR QUÉ: el contrato debe ser mantenible sin editar código ni JSON manual.

import 'package:flutter/material.dart';
import 'package:nanoai/features/automation/engine/business/business_dialogue.dart';
import 'package:nanoai/features/automation/engine/business/business_faq.dart';
import 'package:nanoai/features/automation/engine/business/business_profile.dart';
import 'package:nanoai/features/automation/engine/business/business_rule.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'dialog_container_shell.dart';

part 'business_profile_edit_fields.dart';
part 'business_profile_edit_parsers.dart';

class BusinessProfileEditDialog extends StatefulWidget {
  final BusinessProfile initial;

  const BusinessProfileEditDialog({super.key, required this.initial});

  @override
  State<BusinessProfileEditDialog> createState() =>
      _BusinessProfileEditDialogState();
}

class _BusinessProfileEditDialogState extends State<BusinessProfileEditDialog> {
  late final TextEditingController _locale;
  late final TextEditingController _timezone;
  late final TextEditingController _currency;
  late final TextEditingController _intents;
  late final TextEditingController _tools;
  late final TextEditingController _blocked;
  late final TextEditingController _faq;
  late final TextEditingController _dialogues;
  late final TextEditingController _rules;
  late final TextEditingController _handoff;
  late final TextEditingController _confidence;
  late final TextEditingController _maxSteps;
  late final TextEditingController _approval;
  late bool _autoReply;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final profile = widget.initial;
    _locale = TextEditingController(text: profile.locale);
    _timezone = TextEditingController(text: profile.timezone);
    _currency = TextEditingController(text: profile.currency);
    _intents = TextEditingController(text: profile.intents.join(', '));
    _tools = TextEditingController(text: profile.tools.join(', '));
    _blocked = TextEditingController(
      text: profile.blockedAutomation.join(', '),
    );
    _faq = TextEditingController(text: _formatFaq(profile.faq));
    _dialogues = TextEditingController(
      text: _formatDialogues(profile.dialogues),
    );
    _rules = TextEditingController(text: _formatRules(profile.rules));
    _handoff = TextEditingController(text: profile.handoffMessage);
    _confidence = TextEditingController(
      text: profile.handoffConfidence.toStringAsFixed(2),
    );
    _maxSteps = TextEditingController(text: '${profile.maxToolSteps}');
    _approval = TextEditingController(text: '${profile.approvalAmount}');
    _autoReply = profile.autoReply;
  }

  @override
  void dispose() {
    for (final controller in [
      _locale,
      _timezone,
      _currency,
      _intents,
      _tools,
      _blocked,
      _faq,
      _dialogues,
      _rules,
      _handoff,
      _confidence,
      _maxSteps,
      _approval,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    try {
      Navigator.of(context).pop(_parseProfile());
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final size = MediaQuery.sizeOf(context);
    return DialogContainerShell(
      child: SizedBox(
        width: size.width.clamp(320, 680).toDouble(),
        height: size.height * (size.width > size.height ? 0.92 : 0.82),
        child: Column(
          children: [
            _buildHeader(visual),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildFields(visual),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('Guardar')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AUTOMATION-DASHBOARD-DIALOGS — Diálogos de creación de regla y modo.
///
/// QUÉ HACE:
/// Muestra los modales para programar aviso por hora y cambiar modo de autonomía.
///
/// CÓMO FUNCIONA:
/// Usa [showTimePicker] y [showModalBottomSheet] con restricciones seguras.
///
/// POR QUÉ:
/// Modulariza la presentación de diálogos manteniendo los archivos < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_choice_group.dart';
import '../../application/rule_creator.dart';
import '../../domain/automation_policy.dart';
import '../../engine/scheduling/scheduled_rule.dart';
import '../../engine/scheduling/trigger.dart';
import '../automation_visual_theme.dart';

class AutomationDashboardDialogs {
  static Future<void> createTimeRule({
    required BuildContext context,
    required RuleCreator ruleCreator,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !context.mounted) return;

    final messageController = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final visual = AutomationVisual.of(ctx);
        return AlertDialog(
          backgroundColor: visual.surface,
          title: Text('Aviso a las ${picked.format(ctx)}'),
          content: SingleChildScrollView(
            child: TextField(
              controller: messageController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Qué avisar (opcional)',
              ),
              onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(messageController.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
    messageController.dispose();
    if (message == null || !context.mounted) return;

    final rule = ruleCreator.create(
      trigger: TimeTrigger(hour: picked.hour, minute: picked.minute),
      action: RuleAction.notify,
      message: message,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Regla creada: ${rule.id} — avisará a las ${picked.format(context)}',
        ),
      ),
    );
  }

  static Future<void> pickMode({
    required BuildContext context,
    required AgentAutomationMode currentMode,
    required ValueChanged<AgentAutomationMode> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NanoSpacing.lg),
          child: ChoiceGroup(
            label: 'Nivel de autonomía',
            description: currentMode.description,
            options: const [
              ChoiceOption('manual', 'Manual', Icons.pan_tool_alt_rounded),
              ChoiceOption('assisted', 'Asistido', Icons.assistant_rounded),
              ChoiceOption('autonomous', 'Autónomo', Icons.auto_awesome_rounded),
            ],
            selectedValue: currentMode.name,
            onSelected: (value) {
              onSelected(AgentAutomationMode.fromName(value));
              Navigator.of(ctx).pop();
            },
            colors: NanoThemeExtension.of(context).colors,
          ),
        ),
      ),
    );
  }
}

// business_preset_apply_dialog.dart
//
// QUÉ HACE: confirma y aplica el contrato y tono de una plantilla comercial.
// CÓMO: guarda el perfil versionado mediante Riverpod y mantiene intactos los
// productos, horarios, pagos, ubicación y entregas configurados por el dueño.
// POR QUÉ: una plantilla visual nunca debe introducir datos comerciales falsos.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/business/business_presets.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Muestra una confirmación explícita antes de cambiar el estilo del agente.
Future<void> applyBusinessPreset({
  required BuildContext context,
  required WidgetRef ref,
  required BusinessPreset preset,
  required bool isLandscape,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) {
      final visual = AutomationVisual.of(dialogContext);
      return AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isLandscape ? 8 : 20,
        ),
        backgroundColor: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Aplicar "${preset.title}"',
          style: TextStyle(
            color: visual.text,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tono: ${preset.tone.sales == ToneSales.persuasivo ? "Persuasivo" : "Natural"}, '
              '${preset.tone.warmth == ToneWarmth.cercano ? "Cercano" : "Formal"}.',
              style: TextStyle(color: visual.text, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              '${preset.profile.intents.length} intenciones, '
              '${preset.profile.tools.length} herramientas declaradas y '
              '${preset.profile.dialogues.length} flujo(s) editables.\n\n'
              'No reemplaza ni inventa productos, horarios, pagos, '
              'ubicación o entregas.',
              style: TextStyle(fontSize: 11, color: visual.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: visual.textMuted, fontSize: 12),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: visual.accent),
            child: const Text('Aplicar'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final stored = await ref
      .read(businessFactsNotifierProvider.notifier)
      .setProfile(preset.profile);
  if (!context.mounted) return;
  if (!stored) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No fue posible guardar la plantilla.')),
    );
    return;
  }
  await ref
      .read(businessToneProfileNotifierProvider.notifier)
      .update(preset.tone);
  if (!context.mounted) return;

  navigator.pop();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Plantilla "${preset.title}" aplicada. Completa tus datos reales en '
        'Negocio, Productos y Pagos.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

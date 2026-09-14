import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/features/automation/engine/business/business_presets.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';

/// Hoja modal para previsualizar y cargar plantillas de negocio predefinidas.
class BusinessPresetsSheet extends ConsumerWidget {
  const BusinessPresetsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BusinessPresetsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: visual.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.dashboard_customize_outlined, color: visual.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plantillas de Negocio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: visual.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Configura estrategia, tono y políticas con 1 toque.',
                        style: TextStyle(fontSize: 12.5, color: visual.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: BusinessPresetsCatalog.presets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final preset = BusinessPresetsCatalog.presets[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: visual.isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: visual.isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: visual.accentSoft,
                        child: Icon(preset.icon, color: visual.accent, size: 20),
                      ),
                      title: Text(
                        preset.title,
                        style: TextStyle(
                          color: visual.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: Text(
                        preset.description,
                        style: TextStyle(color: visual.textMuted, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: visual.textMuted),
                      onTap: () => _applyPresetDialog(context, ref, preset),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyPresetDialog(
    BuildContext context,
    WidgetRef ref,
    BusinessPreset preset,
  ) async {
    bool loadBaseFacts = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (context, setDlgState) {
          final visual = AutomationVisual.of(dlgContext);
          return AlertDialog(
            backgroundColor: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Aplicar plantilla "${preset.title}"',
              style: TextStyle(color: visual.text, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Se configurará el tono comercial (${preset.tone.sales == ToneSales.persuasivo ? "Persuasivo" : "Natural"}, trato ${preset.tone.warmth == ToneWarmth.cercano ? "Cercano" : "Formal"}).',
                    style: TextStyle(color: visual.text, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: loadBaseFacts,
                    activeColor: visual.accent,
                    onChanged: (v) {
                      setDlgState(() => loadBaseFacts = v ?? true);
                    },
                    title: Text(
                      'Cargar políticas y datos recomendados',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: visual.text),
                    ),
                    subtitle: Text(
                      'Aplica horarios, políticas de pago y logística recomendadas para este rubro (conservando tus productos actuales).',
                      style: TextStyle(fontSize: 11.5, color: visual.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgContext).pop(false),
                child: Text('Cancelar', style: TextStyle(color: visual.textMuted)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dlgContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: visual.accent),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(toneProfileNotifierProvider.notifier).update(preset.tone);

      if (loadBaseFacts) {
        final currentFacts = ref.read(businessFactsNotifierProvider);
        await ref.read(businessFactsNotifierProvider.notifier).loadPreset(
          BusinessFacts(
            products: currentFacts.products.isNotEmpty ? currentFacts.products : preset.facts.products,
            hours: preset.facts.hours,
            delivery: preset.facts.delivery,
            payments: preset.facts.payments,
            location: preset.facts.location,
          ),
        );
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plantilla "${preset.title}" aplicada con éxito.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

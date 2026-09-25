import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/engine/business/business_presets.dart';
import 'package:nanoai/features/automation/presentation/automation_visual_theme.dart';
import 'package:nanoai/features/automation/presentation/widgets/dialogs/business_preset_apply_dialog.dart';

// business_presets_sheet.dart
//
// QUÉ HACE:
// Hoja modal adaptada con Material Expressive para previsualizar y aplicar plantillas de negocio predefinidas.
//
// CÓMO FUNCIONA:
// - Despliega catálogo de plantillas comerciales con selección rápida y diálogo confirmatorio.
// - Aplica restricciones de altura y márgenes proporcionales en Landscape y Portrait.
//
// POR QUÉ:
// Facilita la configuración del asistente con un toque sin sobrepasar el límite de 200 líneas (SOLID).

class BusinessPresetsSheet extends ConsumerWidget {
  const BusinessPresetsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BusinessPresetsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = AutomationVisual.of(context);
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: size.height * (isLandscape ? 0.92 : 0.85),
          ),
          decoration: BoxDecoration(
            color: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            MediaQuery.of(context).viewInsets.bottom + (isLandscape ? 8 : 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: visual.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.dashboard_customize_outlined,
                      color: visual.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plantillas de Negocio',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: visual.text,
                          ),
                        ),
                        Text(
                          'Configura estrategia y tono con 1 toque.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: visual.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: BusinessPresetsCatalog.presets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final preset = BusinessPresetsCatalog.presets[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: visual.isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: visual.isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: visual.accentSoft,
                          child: Icon(
                            preset.icon,
                            color: visual.accent,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          preset.title,
                          style: TextStyle(
                            color: visual.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          preset.description,
                          style: TextStyle(
                            color: visual.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: visual.textMuted,
                          size: 18,
                        ),
                        onTap: () => applyBusinessPreset(
                          context: context,
                          ref: ref,
                          preset: preset,
                          isLandscape: isLandscape,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';

import 'package:nanoai/core/widgets/feather_core_icon.dart';

/// Categorías temáticas de la configuración de automatización.
enum AutomationSettingsCategory {
  general('General', Icons.bolt_rounded),
  whatsapp('WhatsApp', Icons.chat_bubble_outline_rounded),
  brain('Memoria', Icons.psychology_outlined),
  system('Sistema', Icons.tune_rounded);

  final String label;
  final IconData icon;
  const AutomationSettingsCategory(this.label, this.icon);
}

/// Contenedor de tarjeta de configuración con bordes y divisores internos.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AutomationSurfaceCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            const Divider(height: 1, indent: 74),
        ],
      ],
    ),
  );
}

/// Fila de configuración adaptable con icono estilizado FeatherCore, título, subtítulo
/// y widget secundario (trailing o chevron).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.imageAsset,
    this.featherType,
    this.customIcon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  }) : assert(icon != null || imageAsset != null || featherType != null || customIcon != null);

  final IconData? icon;
  final String? imageAsset;
  final FeatherCoreType? featherType;
  final Widget? customIcon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  Widget _buildLeading(AutomationVisualPalette visual) {
    if (customIcon != null) return customIcon!;
    if (featherType != null) {
      return FeatherCoreIcon(type: featherType!, size: 42, accentColor: visual.accent);
    }
    if (imageAsset != null) {
      if (imageAsset!.contains('whatsapp_business')) {
        return FeatherCoreIcon(
          type: FeatherCoreType.whatsappBusiness,
          size: 42,
          accentColor: visual.accent,
        );
      }
      return Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: visual.accentSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: visual.accent.withValues(
              alpha: visual.isDark ? 0.28 : 0.20,
            ),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: visual.accent.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imageAsset!,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return FeatherCoreIcon.custom(
      icon: icon!,
      size: 42,
      accentColor: visual.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330 && trailing != null;
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeading(visual),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              softWrap: true,
                              style: TextStyle(
                                color: visual.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!compact && trailing != null) ...[
                            const SizedBox(width: 10),
                            trailing!,
                          ] else if (showChevron)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: visual.textMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        softWrap: true,
                        style: TextStyle(
                          color: visual.isDark
                              ? const Color(0xFFE2E8F0)
                              : visual.textMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (compact && trailing != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Etiqueta de valor para indicar estados o selecciones actuales en las filas.
class ValueBadge extends StatelessWidget {
  const ValueBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: visual.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: visual.accent.withValues(alpha: visual.isDark ? 0.65 : 0.40),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: visual.isDark ? const Color(0xFFFFD6A4) : visual.accent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Indicador semántico de estado activo de solo lectura.
class ReadonlyStatus extends StatelessWidget {
  const ReadonlyStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final success = AutomationVisual.of(context).success;
    return Semantics(
      label: 'Activo',
      child: Tooltip(
        message: 'Activo',
        child: Icon(Icons.check_circle_rounded, color: success, size: 18),
      ),
    );
  }
}

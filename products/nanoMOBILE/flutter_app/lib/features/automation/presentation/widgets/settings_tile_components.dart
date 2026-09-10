import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import '../automation_visual_theme.dart';

/// Categorías temáticas de la configuración de automatización.
enum AutomationSettingsCategory {
  general('General', Icons.bolt_rounded),
  whatsapp('WhatsApp', Icons.chat_bubble_outline_rounded),
  brain('Cerebro', Icons.psychology_outlined),
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

/// Fila de configuración adaptable con icono estilizado, título, subtítulo
/// y widget secundario (trailing o chevron).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

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
                Container(
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
                  child: Icon(icon, color: visual.accent, size: 22),
                ),
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
                          color: visual.textMuted,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: AutomationVisual.of(context).accent),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: NanoTextColors.forText(
          AutomationVisual.of(context).accent,
          NanoThemeExtension.of(context).colors,
        ),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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

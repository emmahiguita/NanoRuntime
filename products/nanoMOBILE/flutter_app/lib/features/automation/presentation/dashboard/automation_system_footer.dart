/// Footer compacto de control con superficies iOS compartidas.
library;

import 'package:flutter/material.dart';

import '../automation_visual_theme.dart';

class AutomationSystemFooter extends StatelessWidget {
  final String automationModeLabel;
  final int activeRulesCount;
  final VoidCallback onRulesTap;
  final VoidCallback onSystemTap;

  const AutomationSystemFooter({
    super.key,
    required this.automationModeLabel,
    required this.activeRulesCount,
    required this.onRulesTap,
    required this.onSystemTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final rulesLabel =
        'Modo $automationModeLabel · $activeRulesCount regla${activeRulesCount == 1 ? '' : 's'} activa${activeRulesCount == 1 ? '' : 's'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SystemGlassRow(
          icon: Icons.auto_mode_rounded,
          iconColor: visual.accent,
          title: 'Automatización y Reglas',
          subtitle: rulesLabel,
          trailingLabel: 'Gestionar',
          onTap: onRulesTap,
        ),
        const SizedBox(height: 10),
        _SystemGlassRow(
          icon: Icons.tune_rounded,
          iconColor: visual.textMuted,
          title: 'Sistema y Herramientas',
          subtitle: 'Modelos locales, permisos y opciones del sistema',
          onTap: onSystemTap,
        ),
      ],
    );
  }
}

class _SystemGlassRow extends StatelessWidget {
  const _SystemGlassRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: AutomationSurfaceCard(
        radius: 18,
        blurSigma: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visual.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visual.textMuted,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: TextStyle(
                  color: visual.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 3),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: trailingLabel == null ? visual.textMuted : visual.accent,
            ),
          ],
        ),
      ),
    );
  }
}

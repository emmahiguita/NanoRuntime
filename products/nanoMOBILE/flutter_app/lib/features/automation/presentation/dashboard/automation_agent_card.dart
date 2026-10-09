// QUÉ: tarjeta compacta del agente con cristal iOS y respuesta física.
// CÓMO: usa la superficie compartida del módulo, semántica y toque háptico.
// POR QUÉ: evita tarjetas blancas opacas y mantiene una jerarquía consistente.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../automation_visual_theme.dart';

class AutomationAgentCard extends StatelessWidget {
  const AutomationAgentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.iconWidget,
    required this.channels,
    this.metricLabel,
    required this.onTap,
    this.showStatus = false,
  });

  final String title;
  final String subtitle;
  final bool isActive;
  final bool showStatus;
  final Widget iconWidget;
  final List<String> channels;
  final String? metricLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = AutomationVisual.of(context);

    return Semantics(
      button: true,
      label: '$title. $subtitle.',
      child: AutomationSurfaceCard(
        radius: 22,
        blurSigma: 15,
        padding: const EdgeInsets.all(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: visual.accentSoft.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: visual.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: SizedBox(width: 32, height: 32, child: iconWidget),
                ),
                const Spacer(),
                if (showStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? visual.success : visual.textMuted)
                          .withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive ? visual.success : visual.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isActive ? 'Activo' : 'Pausado',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, maxLines: 2, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              metricLabel ?? channels.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

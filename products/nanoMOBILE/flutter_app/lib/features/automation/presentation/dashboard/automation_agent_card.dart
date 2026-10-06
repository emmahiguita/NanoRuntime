// QUÉ: tarjeta compacta del agente; icono, descripción y accesos reales.
// CÓMO: Material + InkWell con tipografía del tema y altura según el contenido.
// POR QUÉ: sin escalado del origen Hero, halos redundantes ni texto diminuto.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String title, subtitle;
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
    return Semantics(
      button: true,
      label: '$title. $subtitle.',
      child: Material(
        // El color y radio son los mismos que utiliza el origen de la expansión.
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(width: 38, height: 38, child: iconWidget),
                    const Spacer(),
                    // No afirma que el agente personal esté activo por una constante.
                    // En negocio el dato procede de la regla; es información, no botón.
                    if (showStatus)
                      Text(
                        isActive ? 'Activo' : 'Pausado',
                        style: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title, maxLines: 2, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  metricLabel ?? channels.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

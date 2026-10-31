// conversation_link_footer.dart
// QUÉ HACE: Renderiza la fila de enlace y acción rápida conectada al tema del sistema (< 85 líneas).
// CÓMO FUNCIONA: Despliega la URL con subrayado táctil y un botón estilo cápsula con acento de AutomationVisualPalette.
// POR QUÉ: Extrae la responsabilidad del pie de enlace para cumplir estrictamente SRP y límite < 200 líneas.
library;

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'conversation_media_viewer.dart';

/// Pie interactivo para tarjetas de enlace web.
class ConversationLinkFooter extends StatelessWidget {
  final String url;
  final String domain;

  const ConversationLinkFooter({
    super.key,
    required this.url,
    required this.domain,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => ConversationMediaViewer.openInAppWeb(
              context,
              url,
              title: domain,
            ),
            child: Text(
              url,
              style: TextStyle(
                color: visual.accent,
                fontSize: 11,
                decoration: TextDecoration.underline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => ConversationMediaViewer.openInAppWeb(
            context,
            url,
            title: domain,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: visual.accent.withValues(alpha: 0.35),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_browser_rounded,
                  color: visual.accent,
                  size: 12,
                ),
                const SizedBox(width: 3),
                Text(
                  'Abrir',
                  style: TextStyle(
                    color: visual.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

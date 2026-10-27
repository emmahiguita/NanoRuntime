// meta_inbox_shortcut.dart
//
// QUÉ HACE:
// Provee acceso directo en el Centro de Mensajería a la API Oficial de WhatsApp
// Business (Meta Cloud API / Nano Gateway + MCP Oficial) y al gestor de Plantillas.
//
// CÓMO FUNCIONA:
// - Renderiza una tarjeta compacta adaptable con acceso a MetaInboxScreen
//   (bandeja de webhook y diálogo de conexión segura) y a MetaTemplatesScreen.
//
// POR QUÉ:
// Restaura la opción del API Oficial en el panel principal sin mezclar el canal
// Cloud con el puente de WhatsApp Web ni las notificaciones (< 200 líneas).

import 'package:flutter/material.dart';
import '../business/meta_business_lines_screen.dart';

class MetaInboxShortcut extends StatelessWidget {
  const MetaInboxShortcut({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.52)
        : Colors.white.withValues(alpha: 0.68);
    final border = isDark
        ? const Color(0xFF38BDF8).withValues(alpha: 0.28)
        : const Color(0xFF0284C7).withValues(alpha: 0.24);
    final accent = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_done_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MetaBusinessLinesScreen(),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'API Oficial WhatsApp (Meta Cloud)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Conectar Gateway, MCP oficial y bandeja Cloud',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MetaBusinessLinesScreen(),
              ),
            ),
            icon: Icon(Icons.description_outlined, size: 15, color: accent),
            label: Text(
              'Líneas',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Abrir API Oficial de WhatsApp',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MetaBusinessLinesScreen(),
              ),
            ),
            icon: Icon(Icons.chevron_right_rounded, color: accent),
          ),
        ],
      ),
    );
  }
}

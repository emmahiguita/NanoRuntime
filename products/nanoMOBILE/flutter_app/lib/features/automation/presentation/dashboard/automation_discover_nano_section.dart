// automation_discover_nano_section.dart — Cuadrícula 2x2 para capacidades nucleares de Nano AI.
//
// QUÉ HACE:
// Presenta las 4 herramientas clave (Sesiones IA, Navegador, Chat IA y Terminal Linux) con estética iOS Metallic Glass.
//
// CÓMO FUNCIONA:
// - Distribuye los 4 pilares en un grid responsive de 2 columnas usando AutomationDiscoverTile.
// - Asigna a cada herramienta un gradiente líquido distintivo y un borde especular metálico brillante.
//
// POR QUÉ:
// Proporciona una interfaz moderna, limpia y profesional estilo Apple iOS (< 140 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'automation_discover_tile.dart';

/// Sección de descubrimiento en cuadrícula 2x2 con estética Apple iOS Metallic Glass.
class AutomationDiscoverNanoSection extends StatelessWidget {
  final VoidCallback? onAiWebTap;
  final VoidCallback? onBrowserTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onTerminalTap;

  const AutomationDiscoverNanoSection({
    super.key,
    this.onAiWebTap,
    this.onBrowserTap,
    this.onChatTap,
    this.onTerminalTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 330 || textScale > 1.35;
        final tileWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // 1. Sesiones IA (Multi-Proveedor) — Púrpura Iridiscente & Celeste
            SizedBox(
              width: tileWidth,
              child: AutomationDiscoverTile(
                visual: visual,
                category: 'Multi-Proveedor',
                title: 'Sesiones IA',
                description: 'ChatGPT, DeepSeek, Kimi y Qwen en ventana flotante',
                icon: CupertinoIcons.sparkles,
                badgeGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF38BDF8)],
                ),
                specularColor: const Color(0xFFC084FC),
                onTap: onAiWebTap,
              ),
            ),

            // 2. Navegador Web (Navegación Asistida) — Azul Zafiro & Aqua
            SizedBox(
              width: tileWidth,
              child: AutomationDiscoverTile(
                visual: visual,
                category: 'Navegación Asistida',
                title: 'Navegador Web',
                description: 'Navega por internet con integración y asistencia IA',
                icon: CupertinoIcons.compass,
                badgeGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                ),
                specularColor: const Color(0xFF38BDF8),
                onTap: onBrowserTap,
              ),
            ),

            // 3. Chat IA (Modelos Locales y Nube) — Esmeralda Menta & Verde Cibernético
            SizedBox(
              width: tileWidth,
              child: AutomationDiscoverTile(
                visual: visual,
                category: 'Modelos Locales y Nube',
                title: 'Chat IA',
                description: 'Conversación directa con LLMs integrados y remotos',
                icon: CupertinoIcons.chat_bubble_2_fill,
                badgeGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
                ),
                specularColor: const Color(0xFF6EE7B7),
                onTap: onChatTap,
              ),
            ),

            // 4. Terminal Linux (Consola Bash Nativa) — Ámbar Neón & Titanio
            SizedBox(
              width: tileWidth,
              child: AutomationDiscoverTile(
                visual: visual,
                category: 'Consola Bash Nativa',
                title: 'Terminal Linux',
                description: 'Entorno Linux directo con comandos root y paquetes',
                icon: Icons.terminal_rounded,
                badgeGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFF97316)],
                ),
                specularColor: const Color(0xFFFDE047),
                onTap: onTerminalTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

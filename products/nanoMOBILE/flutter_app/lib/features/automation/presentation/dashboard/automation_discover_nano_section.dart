// automation_discover_nano_section.dart — Cuadrícula responsiva de capacidades nucleares.
//
// QUÉ HACE:
// Presenta las 6 herramientas y atajos clave de Nano AI con estética Apple iOS Metallic Glass:
// 1. MCP y Claves API (Atajo a Hub de Servidores y Proveedores OpenAI, Claude, Gemini, DeepSeek).
// 2. Sesiones IA (Multi-proveedor flotante).
// 3. Chat IA (Conversación directa con agentes y modelos).
// 4. Navegador Web (Navegación asistida).
// 5. Terminal Linux (Consola Bash nativa).
// 6. Modelos Locales (Catálogo y motores on-device).
//
// CÓMO FUNCIONA:
// - Distribuye los 6 pilares en un grid responsive de 2 columnas usando AutomationDiscoverTile.
// - Asigna a cada herramienta un gradiente líquido distintivo y un borde especular metálico brillante.
//
// POR QUÉ:
// Proporciona acceso inmediato, ordenado y visualmente equilibrado a todas las herramientas (< 170 líneas).
library;

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'automation_discover_tile.dart';

/// Sección de descubrimiento y atajos en cuadrícula 2x3 estilo Apple iOS Metallic Glass.
class AutomationDiscoverNanoSection extends StatelessWidget {
  final VoidCallback? onAiWebTap;
  final VoidCallback? onBrowserTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onTerminalTap;
  final VoidCallback? onMcpTap;
  final VoidCallback? onModelsTap;

  const AutomationDiscoverNanoSection({
    super.key,
    this.onAiWebTap,
    this.onBrowserTap,
    this.onChatTap,
    this.onTerminalTap,
    this.onMcpTap,
    this.onModelsTap,
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

        final items = [
          (
            'Ecosistema & APIs',
            'MCP y Claves API',
            'OpenAI, Claude, Gemini, DeepSeek y Skills MCP',
            Icons.hub_rounded,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF38BDF8)],
            ),
            const Color(0xFFC084FC),
            onMcpTap,
          ),
          (
            'Multi-Proveedor',
            'Sesiones IA',
            'ChatGPT, DeepSeek y Qwen en ventana flotante',
            Icons.auto_awesome_rounded,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF3B82F6), Color(0xFF38BDF8)],
            ),
            const Color(0xFF38BDF8),
            onAiWebTap,
          ),
          (
            'Chat Autónomo',
            'Chat IA',
            'Conversación directa con LLMs y agentes',
            Icons.forum_rounded,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
            ),
            const Color(0xFF6EE7B7),
            onChatTap,
          ),
          (
            'Navegación Asistida',
            'Navegador Web',
            'Navega por internet con integración y asistencia IA',
            Icons.explore_rounded,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF38BDF8)],
            ),
            const Color(0xFF38BDF8),
            onBrowserTap,
          ),
          (
            'Consola Bash',
            'Terminal Linux',
            'Entorno Linux directo con comandos root y paquetes',
            Icons.terminal_rounded,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFF97316)],
            ),
            const Color(0xFFFDE047),
            onTerminalTap,
          ),
          (
            'Silicio On-Device',
            'Modelos Locales',
            'Qwen, Gemma y motores sin conexión a internet',
            Icons.memory_rounded,
            const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6), Color(0xFF2DD4BF)],
            ),
            const Color(0xFF5EEAD4),
            onModelsTap,
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (cat, title, desc, icon, grad, spec, tap) in items)
              SizedBox(
                width: tileWidth,
                child: AutomationDiscoverTile(
                  visual: visual,
                  category: cat,
                  title: title,
                  description: desc,
                  icon: icon,
                  badgeGradient: grad,
                  specularColor: spec,
                  onTap: tap,
                ),
              ),
          ],
        );
      },
    );
  }
}

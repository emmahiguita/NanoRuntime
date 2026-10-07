// automation_discover_nano_section.dart — Cuadrícula 2x2 para capacidades nucleares de Nano AI.
// QUÉ HACE: Presenta las 4 herramientas clave (Sesiones IA, Navegador, Chat IA y Terminal) en un grid 2x2.
// CÓMO FUNCIONA: Usa filas adaptables con Expanded y delega el renderizado en AutomationDiscoverTile.
// POR QUÉ: Implementa el diseño estético de cuadrícula 2x2 con badges orgánicos (< 200 líneas).
library;

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';
import 'automation_discover_tile.dart';

/// Sección de descubrimiento en cuadrícula 2x2 con badges de forma orgánica.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fila 1: Sesiones IA y Navegador Web
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AutomationDiscoverTile(
                  visual: visual,
                  category: 'Multi-Proveedor',
                  title: 'Sesiones IA',
                  description: 'ChatGPT, DeepSeek, Kimi y Qwen en ventana flotante',
                  badgeColor: visual.accent,
                  badgeBorderRadius: BorderRadius.circular(12),
                  icon: Icons.auto_awesome_rounded,
                  onTap: onAiWebTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AutomationDiscoverTile(
                  visual: visual,
                  category: 'Navegación Asistida',
                  title: 'Navegador Web',
                  description: 'Navega por internet con integración y asistencia IA',
                  badgeColor: visual.accent,
                  badgeBorderRadius: BorderRadius.circular(12),
                  icon: Icons.travel_explore_rounded,
                  onTap: onBrowserTap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Fila 2: Chat IA y Terminal Linux
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AutomationDiscoverTile(
                  visual: visual,
                  category: 'Modelos Locales y Nube',
                  title: 'Chat IA',
                  description: 'Conversación directa con LLMs integrados y remotos',
                  badgeColor: visual.accent,
                  badgeBorderRadius: BorderRadius.circular(12),
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: onChatTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AutomationDiscoverTile(
                  visual: visual,
                  category: 'Consola Bash Nativa',
                  title: 'Terminal Linux',
                  description: 'Entorno Linux directo con comandos root y paquetes',
                  badgeColor: visual.accent,
                  badgeBorderRadius: BorderRadius.circular(12),
                  icon: Icons.terminal_rounded,
                  onTap: onTerminalTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
                  badgeColor: const Color(0xFFE11D48),
                  badgeGradient: const LinearGradient(
                    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
                  ),
                  badgeBorderRadius: BorderRadius.circular(99),
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
                  badgeColor: const Color(0xFF10B981),
                  badgeGradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                  ),
                  badgeBorderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(22),
                  ),
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
                  badgeColor: const Color(0xFF3B82F6),
                  badgeGradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  ),
                  badgeBorderRadius: BorderRadius.circular(14),
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
                  badgeColor: const Color(0xFFF59E0B),
                  badgeGradient: const LinearGradient(
                    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                  ),
                  badgeBorderRadius: BorderRadius.circular(16),
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

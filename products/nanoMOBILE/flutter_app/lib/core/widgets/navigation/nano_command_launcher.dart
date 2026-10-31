// nano_command_launcher.dart — Barra de escritura y reconocimiento de accesos compacta.
//
// QUÉ HACE:
// Presenta el acceso rápido a escritura contextual, botón de adjuntos (+),
// reconocimiento de accesos/ejecutor activo (NanoInputToolButton) y buscador.
//
// CÓMO FUNCIONA:
// - Despliega una cápsula flotante Liquid Glass con altura compacta (38dp).
// - Si hay una herramienta/acceso activo, muestra su icono semántico y estado.
// - Al pulsar el campo o el icono de búsqueda, expande el editor completo.
// - El botón (+) despliega las opciones y complementos del ejecutor.
//
// POR QUÉ:
// Inyecta la lógica de órdenes y accesos respetando el diseño flotante (< 115 líneas, SOLID).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'nano_input_tool_controls.dart';
import 'nano_input_tool_context.dart';
import 'nano_nav_bar_container.dart';

class NanoCommandLauncher extends StatelessWidget {
  const NanoCommandLauncher({
    super.key,
    required this.controls,
    required this.onWrite,
    required this.onNavigate,
    required this.maxWidth,
    this.tool,
    this.brightness,
  });

  final NanoInputToolControls controls;
  final NanoInputToolContext? tool;
  final VoidCallback onWrite, onNavigate;
  final double maxWidth;
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = (brightness ?? theme.brightness) == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth.clamp(0, 480)),
      child: NanoNavBarContainer(
        brightness: brightness,
        compact: true,
        showHandle: false,
        radius: 20,
        child: SizedBox(
          height: 38,
          child: Row(
            children: [
              // 1. Botón (+) de adjuntos y complementos
              Builder(
                builder: (anchor) => IconButton(
                  tooltip: 'Adjuntos y complementos',
                  onPressed: () => (controls.onAdd ?? controls.onOptions)(anchor),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    CupertinoIcons.plus,
                    size: 18,
                    color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
                  ),
                ),
              ),

              // 2. Reconocimiento de acceso/ejecutor activo (WhatsApp, Linux, Telegram, etc.)
              if (controls.selected) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: NanoInputToolButton(controls: controls),
                ),
              ],

              // 3. Campo de orden/escritura con tipografía nítida
              Expanded(
                child: InkWell(
                  onTap: onWrite,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tool?.status ?? 'Escribir una orden…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Acceso rápido a búsqueda / dictado
              IconButton(
                tooltip: 'Escribir o buscar',
                onPressed: onWrite,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                icon: Icon(
                  CupertinoIcons.search,
                  size: 17,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

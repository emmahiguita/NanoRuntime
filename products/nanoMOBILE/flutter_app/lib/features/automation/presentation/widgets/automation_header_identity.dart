// automation_header_identity.dart — Identidad ejecutiva de la cabecera de Automatización.
//
// QUÉ HACE:
// Presenta el título principal 'Automatización' y el selector interactivo de nivel
// de autonomía (Autónomo, Asistido, Manual) con indicador LED de estado del agente.
//
// CÓMO FUNCIONA:
// - Elimina la mascota redundante (que ya vive en el teclado/asistente flotante).
// - Incorpora un micro-indicador LED de estado en tiempo real (verde esmeralda al ejecutar,
//   índigo cósmico en reposo autónomo).
// - Ofrece tipografía limpia Inter con alineación natural a la izquierda y área táctil accesible.
//
// POR QUÉ:
// Diseño original estilo iOS/Material Expressive: elegante, sobrio y sin redundancias (< 110 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../domain/automation_policy.dart';
import '../automation_visual_theme.dart';

class AutomationHeaderIdentity extends StatelessWidget {
  const AutomationHeaderIdentity({
    super.key,
    required this.mode,
    required this.onModeTap,
    required this.running,
  });

  final AgentAutomationMode mode;
  final VoidCallback onModeTap;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);

    // Color del micro-indicador LED de estado del agente:
    // Verde esmeralda si está ejecutando tareas, índigo/lavanda en autónomo, o neutro en asistido/manual.
    final statusColor = running
        ? const Color(0xFF10B981)
        : (mode == AgentAutomationMode.autonomous
            ? const Color(0xFF6366F1)
            : visual.textMuted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Título principal limpio con jerarquía tipográfica iOS
        Text(
          'Automatización',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: visual.text,
            letterSpacing: -0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // 2. Selector de autonomía estilo Liquid Glass Pill con indicador LED
        Semantics(
          button: true,
          label: 'Nivel de autonomía: . Cambiar nivel',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onModeTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: visual.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: visual.cardBorder.withValues(alpha: 0.70),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Micro-indicador LED de estado inteligente
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                        boxShadow: running
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.60),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 5.5),
                    Flexible(
                      child: Text(
                        mode.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          color: visual.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 3.5),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 11,
                      color: visual.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

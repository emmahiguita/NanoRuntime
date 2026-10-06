// nano_floating_orb.dart — Componente de orbe flotante interactivo para el asistente Búho.
// QUÉ HACE: Renderiza la esfera animada del Búho con anillo orbital y botón de cierre rápido.
// CÓMO FUNCIONA: Captura gestos de arrastre (Pan) y toques (Tap) para reposicionar o desplegar el panel.
// POR QUÉ: Desacopla la lógica gestual del orbe cerrado de la ventana expandida, respetando Single Responsibility (<200 líneas).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_ai_models.dart';
import 'nano_owl_alive.dart';
import 'nano_owl_orbital_ring.dart';

class NanoFloatingOrb extends StatelessWidget {
  const NanoFloatingOrb({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onDismiss,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
  });

  final NanoActivity activity;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onPanStart: onPanStart,
          onPanCancel: onPanCancel,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: NanoOwlOrbitalRing(
            size: 76,
            activity: activity,
            child: NanoOwlAlive(
              size: 64,
              activity: activity,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xEE090D16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

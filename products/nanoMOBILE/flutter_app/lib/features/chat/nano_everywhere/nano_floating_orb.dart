// nano_floating_orb.dart — Botón Búho flotante iOS Liquid Glass con personaje 3D interactivo.
// QUÉ HACE: Renderiza la esfera interactiva del Búho con cristal líquido, halo orbital y rotación 3D.
// CÓMO FUNCIONA: Captura gestos (tap, pan, long-press) con respuesta háptica y micro-escala táctil.
// POR QUÉ: Diseño unificado iOS profesional con experiencia volumétrica de producto.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_ai_models.dart';
import 'nano_animation_policy.dart';
import 'nano_owl_3d_turntable.dart';
import 'nano_owl_orbital_ring.dart';

class NanoFloatingOrb extends StatefulWidget {
  const NanoFloatingOrb({
    super.key,
    required this.activity,
    required this.onTap,
    required this.onDismiss,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    this.size = 76,
  });

  final NanoActivity activity;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;
  final double size;

  @override
  State<NanoFloatingOrb> createState() => _NanoFloatingOrbState();
}

class _NanoFloatingOrbState extends State<NanoFloatingOrb>
    with NanoAnimationPolicy {
  bool _isPressed = false;

  /// Keeps press feedback but settles it immediately when motion is disabled.
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Asistente Búho AI flotante 3D',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onDismiss();
        },
        onPanStart: (details) {
          setState(() => _isPressed = true);
          widget.onPanStart(details);
        },
        onPanCancel: () {
          setState(() => _isPressed = false);
          widget.onPanCancel();
        },
        onPanUpdate: widget.onPanUpdate,
        onPanEnd: (details) {
          setState(() => _isPressed = false);
          widget.onPanEnd(details);
        },
        child: AnimatedScale(
          key: ValueKey(motionEnabled),
          scale: _isPressed ? 0.92 : 1.0,
          duration: motionEnabled
              ? const Duration(milliseconds: 160)
              : Duration.zero,
          curve: Curves.easeOutBack,
          child: NanoOwlOrbitalRing(
            size: widget.size,
            activity: widget.activity,
            child: NanoOwl3dTurntable(
              size: widget.size - 14,
              activity: widget.activity,
              interactive: false,
            ),
          ),
        ),
      ),
    );
  }
}

// Perspectiva e inclinacion acotada del sprite, con arrastre e inercia.
// Conserva los angulos y tiempos originales. No utiliza giroscopio ni permite
// inspeccionar una geometria 3D completa de 360 grados.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'nano_ai_models.dart';
import 'nano_animation_policy.dart';
import 'nano_owl_alive.dart';
part 'nano_owl_3d_turntable_view.dart';
part 'nano_owl_3d_turntable_gestures.dart';

class NanoOwl3dTurntable extends StatefulWidget {
  const NanoOwl3dTurntable({
    super.key,
    required this.activity,
    this.size = 72,
    this.interactive = true,
    this.onTap,
  });

  final NanoActivity activity;
  final double size;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  State<NanoOwl3dTurntable> createState() => _NanoOwl3dTurntableState();
}

class _NanoOwl3dTurntableState extends State<NanoOwl3dTurntable>
    with TickerProviderStateMixin, NanoAnimationPolicy {
  // Ángulos de rotación 3D
  double _yaw = 0.0; // Rotación en eje Y (horizontal spin)
  double _pitch = 0.0; // Inclinación en eje X (vertical tilt)

  // Inercia y física
  late final AnimationController _inertiaController;
  late final AnimationController _ambientController;
  late final AnimationController _returnController;
  double _returnYaw = 0, _returnPitch = 0;
  double _angularVelocity = 0.0;
  bool _isDragging = false;

  /// Owns the original drift, inertia and return clocks without changing their timing.
  @override
  void initState() {
    super.initState();

    // Animación de respiración / deriva giroscópica ambiental
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    )..addListener(_restoreCenter);

    // Controlador de inercia y desaceleración física
    _inertiaController = AnimationController.unbounded(vsync: this)
      ..addListener(_handleInertiaTick);
  }

  /// Accessibility and visibility stop every autonomous turn immediately.
  @override
  void onMotionPolicyChanged() => _syncMotion();

  /// Activity changes only alter the existing ambient-animation policy.
  @override
  void didUpdateWidget(covariant NanoOwl3dTurntable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  /// Conserva la interacción 3D y reserva la deriva continua para actividad
  /// real. El estado idle/sleep no mantiene un renderizado de 60 FPS.
  void _syncMotion() {
    final busy = switch (widget.activity) {
      NanoActivity.thinking ||
      NanoActivity.acting ||
      NanoActivity.listening ||
      NanoActivity.comparing ||
      NanoActivity.debating => true,
      _ => false,
    };
    if (!motionEnabled) {
      _inertiaController.stop();
      _returnController.stop();
      _angularVelocity = 0;
      _yaw = 0;
      _pitch = 0;
      _isDragging = false;
    }
    if (busy && motionEnabled) {
      if (!_ambientController.isAnimating) {
        _ambientController.repeat(reverse: true);
      }
    } else {
      _ambientController.stop();
    }
  }

  /// Retains the existing bounded friction; disabled gestures cannot restart it.
  void _handleInertiaTick() {
    if (_isDragging || !motionEnabled) return;
    if (_angularVelocity.abs() > 0.001) {
      setState(() {
        _yaw = (_yaw + _angularVelocity).clamp(-1.08, 1.08);
        _angularVelocity *= 0.91; // Fricción física natural
        _pitch *= 0.88;
      });
      if (_yaw.abs() >= 1.07) {
        // Rebote elástico en el extremo
        _angularVelocity = -_angularVelocity * 0.4;
      }
    } else {
      _inertiaController.stop();
      _angularVelocity = 0.0;
      _springBackToCenter();
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _inertiaController.dispose();
    _returnController.dispose();
    super.dispose();
  }

  /// Draws the same perspective and sprite child using the owned controllers.
  @override
  Widget build(BuildContext context) => buildView(context);
}

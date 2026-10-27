// nano_3d_flip_transition.dart — Transición 3D Card Flip con perspectiva y Shared Element.
// QUÉ HACE: Transición volumétrica que voltea el orbe 3D y lo despliega como el panel de cristal líquido.
// CÓMO FUNCIONA: Matrix4 con rotación de 180° en el eje Y, corte de cara (culling), destello especular y perspectiva.
// POR QUÉ: Reemplaza transiciones planas 2D por una experiencia de producto premium iOS / VisionOS.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_animation_policy.dart';

class Nano3dFlipTransition extends StatefulWidget {
  const Nano3dFlipTransition({
    super.key,
    required this.expanded,
    required this.orbChild,
    required this.panelChild,
    this.duration = const Duration(milliseconds: 480),
  });

  final bool expanded;
  final Widget orbChild;
  final Widget panelChild;
  final Duration duration;

  @override
  State<Nano3dFlipTransition> createState() => _Nano3dFlipTransitionState();
}

class _Nano3dFlipTransitionState extends State<Nano3dFlipTransition>
    with SingleTickerProviderStateMixin, NanoAnimationPolicy {
  late final AnimationController _flipController;
  late final Animation<double> _animation;

  /// Keeps the existing flip curve and duration when motion is allowed.
  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.expanded ? 1.0 : 0.0,
    );

    _animation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  /// Settles immediately when hidden or reduced; visible flips keep their curve.
  @override
  void onMotionPolicyChanged() => _syncFlip();

  /// Uses the latest expansion and duration, including changes during a flip.
  @override
  void didUpdateWidget(covariant Nano3dFlipTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _flipController.duration = widget.duration;
    if (oldWidget.expanded != widget.expanded) _syncFlip();
  }

  /// A disabled flip renders its destination instead of retaining a half turn.
  void _syncFlip() {
    if (!motionEnabled) {
      _flipController.value = widget.expanded ? 1 : 0;
    } else if (widget.expanded) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  /// Builds the unchanged perspective and highlight from the owned flip.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final val = _animation.value;
        final isUnder = (val > 0.5);
        final angle = val * math.pi;

        // Destello especular de luz durante el punto medio del flip (0.4 a 0.6)
        final flashOpacity = (1.0 - (val - 0.5).abs() * 5).clamp(0.0, 1.0);

        // Matriz de perspectiva 3D
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle);

        // Compensación de orientación para la cara trasera
        final displayMatrix = isUnder
            ? (Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle - math.pi))
            : matrix;

        return Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              ignoring: _flipController.isAnimating,
              child: Transform(
                alignment: Alignment.center,
                transform: displayMatrix,
                child: isUnder ? widget.panelChild : widget.orbChild,
              ),
            ),

            // Destello de refracción óptica en el giro
            if (flashOpacity > 0.02)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: flashOpacity * 0.45,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

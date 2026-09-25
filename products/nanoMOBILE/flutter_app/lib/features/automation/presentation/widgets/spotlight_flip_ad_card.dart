/// SPOTLIGHT-FLIP-AD-CARD — Tarjeta 3D interactiva 360° con inercia y foco teatral.
///
/// QUÉ HACE:
/// Proporciona rotación física en eje Y (Yaw) continua (0° a 720°+), inercia táctil,
/// doble cara reversible (anverso/reverso independientes), doble toque para flip 180°,
/// iluminación teatral cenital fija y transición Hero hacia el destino.
///
/// CÓMO FUNCIONA:
/// Combina [AnimationController.unbounded] con [FrictionSimulation], [Ticker] para
/// giro turntable cinemático y [Matrix4] con perspectiva 0.0012 delegando a [SpotlightCardMesh].
///
/// POR QUÉ:
/// Ofrece una experiencia hiperrealista premium M3 Expressive, altamente táctil
/// y sin simulación estática, cumpliendo la regla de menos de 200 líneas.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'spotlight_card_mesh.dart';
import 'theater_spotlight_painter.dart';

class SpotlightFlipAdCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final VoidCallback? onOpen;
  final String? heroTag;
  final double aspectRatio;

  const SpotlightFlipAdCard({
    super.key,
    required this.front,
    required this.back,
    this.onOpen,
    this.heroTag,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<SpotlightFlipAdCard> createState() => _SpotlightFlipAdCardState();
}

class _SpotlightFlipAdCardState extends State<SpotlightFlipAdCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _rotation;
  Ticker? _turntableTicker;
  Timer? _resumeTurntableTimer;
  static const double _perspective = 0.0012;
  static const double _friction = 0.135;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController.unbounded(vsync: this);
    _startTurntable();
    WidgetsBinding.instance.addObserver(this);
  }

  void _startTurntable() {
    _turntableTicker ??= createTicker((_) { if (mounted) _rotation.value += 0.005; });
    if (!_turntableTicker!.isActive) _turntableTicker!.start();
  }

  void _stopTurntable() {
    _resumeTurntableTimer?.cancel();
    if (_turntableTicker?.isActive ?? false) _turntableTicker!.stop();
  }

  void _scheduleTurntableResume() {
    _resumeTurntableTimer?.cancel();
    _resumeTurntableTimer = Timer(const Duration(seconds: 4), () { if (mounted) _startTurntable(); });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _startTurntable();
    } else {
      _stopTurntable();
      if (_rotation.isAnimating) _rotation.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTurntable();
    _turntableTicker?.dispose();
    _rotation.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (_opening) return;
    _stopTurntable();
    _rotation.stop();
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    if (_opening || width <= 0) return;
    _rotation.value += ((details.primaryDelta ?? 0) / width) * math.pi * 2;
  }

  void _onDragEnd(DragEndDetails details, double width) {
    if (_opening || width <= 0 || MediaQuery.of(context).disableAnimations) return;
    final vel = details.primaryVelocity ?? 0;
    final angVel = (vel / width) * math.pi * 2;
    if (angVel.abs() < 0.05) { _scheduleTurntableResume(); return; }
    _rotation.animateWith(FrictionSimulation(_friction, _rotation.value, angVel))
        .whenComplete(() { if (mounted) _scheduleTurntableResume(); });
  }

  void _flipCard() {
    if (_opening) return;
    HapticFeedback.selectionClick();
    _stopTurntable();
    _rotation.stop();
    _rotation.animateTo(_rotation.value + math.pi, duration: const Duration(milliseconds: 650), curve: Curves.easeOutCubic)
        .whenComplete(() { if (mounted) _scheduleTurntableResume(); });
  }

  void _openCard() {
    if (_opening || widget.onOpen == null) return;
    HapticFeedback.lightImpact();
    _stopTurntable();
    _rotation.stop();
    _opening = true;
    widget.onOpen!();
    if (mounted) _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final stage = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
            onHorizontalDragEnd: (d) => _onDragEnd(d, width),
            onDoubleTap: _flipCard,
            onTap: _openCard,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: TheaterSpotlightPainter())),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) {
                      final angle = _rotation.value;
                      final matrix = Matrix4.identity()..setEntry(3, 2, _perspective)..rotateY(angle);
                      return Transform(
                        alignment: Alignment.center,
                        transform: matrix,
                        child: RepaintBoundary(
                          child: SpotlightCardMesh(
                            front: widget.front,
                            back: widget.back,
                            frontVisible: math.cos(angle) >= 0,
                            angle: angle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (widget.heroTag == null) return stage;
    return Hero(tag: widget.heroTag!, child: Material(type: MaterialType.transparency, child: stage));
  }
}

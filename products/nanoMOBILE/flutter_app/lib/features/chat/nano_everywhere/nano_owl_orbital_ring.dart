// Halo del búho: conserva su pintura y reloj originales; la lente reutiliza
// GlassSurface para respetar el contraste y las preferencias globales de Nano.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_ai_models.dart';
import '../../../core/widgets/glass_surface.dart';
part 'nano_owl_orbital_ring_view.dart';
part 'nano_owl_orbital_painter.dart';

class NanoOwlOrbitalRing extends StatefulWidget {
  final Widget child;
  final double size;
  final NanoActivity activity;

  const NanoOwlOrbitalRing({
    super.key,
    required this.child,
    this.size = 72,
    this.activity = NanoActivity.idle,
  });

  @override
  State<NanoOwlOrbitalRing> createState() => _NanoOwlOrbitalRingState();
}

class _NanoOwlOrbitalRingState extends State<NanoOwlOrbitalRing>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _foreground = true;

  bool get _isBusy => switch (widget.activity) {
    NanoActivity.thinking ||
    NanoActivity.acting ||
    NanoActivity.comparing ||
    NanoActivity.debating => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant NanoOwlOrbitalRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  /// El brillo permanece estático en reposo. Un giro perpetuo obligaba a
  /// recomponer también la lente con blur aunque no hubiera ninguna tarea.
  void _syncMotion() {
    final active =
        _isBusy &&
        _foreground &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (active) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildView(context);
}

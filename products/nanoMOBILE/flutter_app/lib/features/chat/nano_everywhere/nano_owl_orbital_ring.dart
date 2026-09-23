// nano_owl_orbital_ring.dart — Aro orbital profesional animado para el Búho Nano.
// QUÉ: Halo cósmico interactivo con gradiente giratorio, pulso respirable y brillo.
// CÓMO: Un controlador activo solo al trabajar; rotación continua de una vuelta.
// POR QUÉ: Dota al búho de un aro estético premium sin procesos zombis ni fugas de RAM.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_ai_models.dart';

class NanoOwlOrbitalRing extends StatefulWidget {
  final Widget child;
  final double size;
  final NanoActivity activity;

  const NanoOwlOrbitalRing({
    super.key,
    required this.child,
    this.size = 76,
    this.activity = NanoActivity.idle,
  });

  @override
  State<NanoOwlOrbitalRing> createState() => _NanoOwlOrbitalRingState();
}

class _NanoOwlOrbitalRingState extends State<NanoOwlOrbitalRing>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _anim;
  bool _foreground = true;
  bool _reduceMotion = false;

  bool get _isBusy => switch (widget.activity) {
    NanoActivity.thinking ||
    NanoActivity.acting ||
    NanoActivity.comparing ||
    NanoActivity.debating => true,
    _ => false,
  };

  bool get _shouldAnimate => _foreground && !_reduceMotion && _isBusy;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    WidgetsBinding.instance.addObserver(this);
    _syncMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context);
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant NanoOwlOrbitalRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity) _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (_shouldAnimate) {
      if (!_anim.isAnimating) _anim.repeat();
    } else {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _anim.dispose();
    super.dispose();
  }

  Color get _glowColor => switch (widget.activity) {
    NanoActivity.listening => const Color(0xFF10B981),
    NanoActivity.thinking => const Color(0xFF38BDF8),
    NanoActivity.acting => const Color(0xFFF59E0B),
    NanoActivity.comparing || NanoActivity.debating => const Color(0xFFA855F7),
    NanoActivity.success => const Color(0xFF059669),
    NanoActivity.error => const Color(0xFFEF4444),
    NanoActivity.sleep => const Color(0xFF6366F1),
    _ => const Color(0xFF22D3EE),
  };

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.size;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final phase = _shouldAnimate ? _anim.value * 2 * math.pi : 0.0;
        final angle = phase; // Una vuelta exacta evita el salto entre ciclos.
        final pulse = _shouldAnimate ? math.sin(phase) * 0.10 + 0.90 : 0.82;

        return SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Resplandor exterior difuso (glow)
              Container(
                width: ringSize - 4,
                height: ringSize - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _glowColor.withValues(alpha: 0.35 * pulse),
                      blurRadius: 16 * pulse,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // 2. Aro orbital con degradado giratorio
              Transform.rotate(
                angle: angle,
                child: Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _glowColor.withValues(alpha: 0.1),
                        _glowColor.withValues(alpha: 0.9),
                        const Color(0xFF10B981),
                        _glowColor.withValues(alpha: 0.1),
                      ],
                      stops: const [0.0, 0.45, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // 3. Mascara interior oscura para afilar el anillo
              Container(
                width: ringSize - 5,
                height: ringSize - 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF090D16),
                ),
              ),
              // 4. Búho central vivo
              Center(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}

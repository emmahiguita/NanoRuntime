// nano_owl_alive.dart — Búho animado con sprites existentes del proyecto.
// QUÉ: Anima el búho usando assets/owl/{idle,blink,fly} del repositorio.
// CÓMO: Timer para parpadeo aleatorio; Timer.periodic para frames de sprite.
//       AnimationController para respiración/flotación continua.
// POR QUÉ: No modifica los assets — solo los lee. WidgetsBindingObserver pausa
//          la animación cuando la app pasa a background (ahorra batería).
//          Guard 'mounted && enabled' antes de setState previene llamadas zombie.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_ai_models.dart';

class NanoOwlAlive extends StatefulWidget {
  const NanoOwlAlive({super.key, required this.activity, this.size = 110});

  final NanoActivity activity;
  final double size;

  @override
  State<NanoOwlAlive> createState() => _NanoOwlAliveState();
}

class _NanoOwlAliveState extends State<NanoOwlAlive>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _idle = 'assets/owl/idle/owl_neutral.png';
  static const _blink = 'assets/owl/blink/owl_blink_';
  static const _fly = 'assets/owl/fly/owl_fly_';

  late final AnimationController _motion;
  final _rand = math.Random();
  Timer? _nextBlink;
  Timer? _frames;
  int _frame = 0;
  bool _flying = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3300),
    )..repeat();
    _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    _applyPolicy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enabled = state == AppLifecycleState.resumed;
    _applyPolicy();
  }

  @override
  void didUpdateWidget(covariant NanoOwlAlive old) {
    super.didUpdateWidget(old);
    if (old.activity != widget.activity) {
      _flying = widget.activity == NanoActivity.success;
      _cancelTimers();
      _frame = 0;
      if (_flying) { _animateFrames(); } else { _scheduleBlink(); }
    }
  }

  void _applyPolicy() {
    if (_enabled && !_motion.isAnimating) _motion.repeat();
    if (!_enabled) {
      _motion.stop();
      _cancelTimers();
      _frame = 0;
    } else if (_nextBlink == null && _frames == null) {
      _scheduleBlink();
    }
  }

  void _cancelTimers() {
    _nextBlink?.cancel();
    _nextBlink = null;
    _frames?.cancel();
    _frames = null;
  }

  void _scheduleBlink() {
    _nextBlink?.cancel();
    _nextBlink = null;
    if (!_enabled || _flying) return;
    _nextBlink = Timer(
      Duration(milliseconds: 2400 + _rand.nextInt(2800)),
      () { _nextBlink = null; _animateFrames(); },
    );
  }

  void _animateFrames() {
    if (!_enabled || !mounted) return;
    const blinkSeq = [1, 2, 3, 4, 5, 4, 3, 2, 1, 0];
    int step = 0;
    _frames?.cancel();
    _frames = Timer.periodic(const Duration(milliseconds: 58), (timer) {
      if (!mounted || !_enabled) {
        timer.cancel();
        _frames = null;
        return;
      }
      final value = _flying ? step + 1 : blinkSeq[step];
      setState(() => _frame = value);
      step++;
      if (step >= (_flying ? 7 : blinkSeq.length)) {
        timer.cancel();
        _frames = null;
        if (mounted) setState(() => _frame = 0);
        _flying = false;
        _scheduleBlink();
      }
    });
  }

  String get _asset {
    if (_frame == 0) return _idle;
    final pad = _frame.toString().padLeft(2, '0');
    return _flying ? '$_fly$pad.png' : '$_blink$pad.png';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = {NanoActivity.listening, NanoActivity.thinking,
      NanoActivity.debating}.contains(widget.activity);
    final decode = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .round().clamp(80, 550);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (_, __) {
          final p = _motion.value * math.pi * 2;
          final rise = _enabled ? math.sin(p) * 2.2 : 0.0;
          final breath = _enabled ? 1 + math.sin(p) * 0.012 : 1.0;
          final tilt = widget.activity == NanoActivity.listening ? math.sin(p) * 0.026 : 0.0;
          return Transform.translate(
            offset: Offset(0, rise),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                scale: breath,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: active ? [
                      BoxShadow(
                        color: const Color(0xFF34B8FF).withValues(
                          alpha: 0.20 + 0.16 * math.sin(p).abs(),
                        ),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: Image.asset(
                    _asset,
                    fit: BoxFit.contain,
                    cacheWidth: decode,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

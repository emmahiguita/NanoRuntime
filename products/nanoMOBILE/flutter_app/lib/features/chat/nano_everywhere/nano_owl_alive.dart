// nano_owl_alive.dart — Búho animado con secuencias reales de sprites.
// QUÉ: Poses activas y secuencias multi-frame para dormir, volar y parpadear.
// CÓMO: 1° Frames reales de sueño (6 cuadros) y vuelo (7 cuadros) vía AnimationController.
//       2° Parpadeo natural con los 5 cuadros fisiológicos de assets/owl/blink/.
//       3° Inactividad de 22s pasa a sueño profundo y despierta al interactuar.
// POR QUÉ: Sustituye el escalado estático "trucado" por animación biológica real
//          sin procesos zombis ni consumo innecesario de batería.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/nano_owl_state.dart';
import 'nano_ai_models.dart';

class NanoOwlAlive extends StatefulWidget {
  const NanoOwlAlive({super.key, required this.activity, this.size = 106});
  final NanoActivity activity;
  final double size;
  @override
  State<NanoOwlAlive> createState() => _NanoOwlAliveState();
}

class _NanoOwlAliveState extends State<NanoOwlAlive>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController motion;
  final random = math.Random();
  Timer? blinkTimer;
  Timer? sleepInactivityTimer;
  int blinkStep = -1;
  bool foreground = true;
  bool reduced = false;
  bool isAutoSleeping = false;

  bool get animate => foreground && !reduced;
  bool get isSleep => widget.activity == NanoActivity.sleep || isAutoSleeping;
  bool get isFly => widget.activity == NanoActivity.fly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    _applyActivityPolicy();
    _resetInactivityTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context);
    _applyActivityPolicy();
    _resetInactivityTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    _applyActivityPolicy();
    _resetInactivityTimer();
  }

  void _applyActivityPolicy() {
    if (!mounted) return;
    blinkTimer?.cancel();
    blinkTimer = null;
    blinkStep = -1;
    motion.stop();
    if (!animate) return;
    // Reiniciar la simulación aplica la duración nueva, no solo cambia el campo.
    motion.duration = Duration(milliseconds: isSleep ? 2000 : isFly ? 560 : 3200);
    motion.repeat(reverse: isSleep);
    if (!isSleep && !isFly) _scheduleBlink();
  }

  void _resetInactivityTimer() {
    sleepInactivityTimer?.cancel();
    if (!animate || isAutoSleeping || widget.activity != NanoActivity.idle) return;
    sleepInactivityTimer = Timer(const Duration(seconds: 22), () {
      if (!mounted || !animate || widget.activity != NanoActivity.idle) return;
      setState(() { isAutoSleeping = true; _applyActivityPolicy(); });
    });
  }

  void _scheduleBlink() {
    if (!animate || isSleep || isFly) return;
    blinkTimer?.cancel();
    blinkTimer = Timer(Duration(milliseconds: 2400 + random.nextInt(3200)), _runBlink);
  }

  void _runBlink() {
    if (!animate || !mounted || isSleep || isFly) return;
    var idx = 0;
    blinkTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted || !animate || idx >= NanoOwlFrames.blinkFrames.length) {
        t.cancel(); blinkTimer = null;
        if (mounted) { setState(() => blinkStep = -1); _scheduleBlink(); }
        return;
      }
      setState(() => blinkStep = idx++);
    });
  }

  @override
  void didUpdateWidget(covariant NanoOwlAlive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity) {
      if (isAutoSleeping) isAutoSleeping = false;
      _applyActivityPolicy();
      _resetInactivityTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    blinkTimer?.cancel();
    sleepInactivityTimer?.cancel();
    motion.dispose();
    super.dispose();
  }

  String _currentAsset() {
    if (blinkStep >= 0 && blinkStep < NanoOwlFrames.blinkFrames.length) {
      return NanoOwlFrames.blinkFrames[blinkStep];
    }
    if (isSleep) {
      final idx = (motion.value * (NanoOwlFrames.sleepFrames.length - 1)).round();
      return NanoOwlFrames.sleepFrames[idx.clamp(0, NanoOwlFrames.sleepFrames.length - 1)];
    }
    if (isFly) {
      final idx = (motion.value * (NanoOwlFrames.flyFrames.length - 1)).round();
      return NanoOwlFrames.flyFrames[idx.clamp(0, NanoOwlFrames.flyFrames.length - 1)];
    }
    return switch (widget.activity) {
      NanoActivity.listening => 'assets/owl/listening.png',
      NanoActivity.thinking || NanoActivity.debating ||
      NanoActivity.comparing || NanoActivity.acting => 'assets/owl/think.png',
      NanoActivity.success => 'assets/owl/welcome.png',
      NanoActivity.error => 'assets/owl/surprised.png',
      _ => 'assets/owl/idle.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: motion,
        builder: (context, child) {
          final p = animate ? motion.value * 2 * math.pi : 0.0;
          final rise = isFly ? math.sin(p) * 4.2 : (isSleep ? 0.0 : math.sin(p) * 2.6);
          final tilt = widget.activity == NanoActivity.listening ? math.sin(p) * .024 : 0.0;

          return Transform.translate(
            offset: Offset(0, rise),
            // Elegir el sprite en cada tick; como child quedaba congelado.
            child: Transform.rotate(angle: tilt, child: SizedBox(
              width: widget.size, height: widget.size,
              child: Image.asset(_currentAsset(), fit: BoxFit.contain,
                gaplessPlayback: true, filterQuality: FilterQuality.medium,
                cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context)).round().clamp(96, 768)),
            )),
          );
        },
      ),
    );
  }
}

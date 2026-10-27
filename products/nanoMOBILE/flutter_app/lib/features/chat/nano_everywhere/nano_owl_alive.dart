// Personaje basado en sprites: parpadeo, reposo, sueno y vuelo.
// Los relojes pertenecen al State y se suspenden con la politica de visibilidad.
// Los frames son imagenes; no hay un modelo 3D ni sensores en este componente.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/nano_owl_state.dart';
import 'nano_ai_models.dart';
import 'nano_animation_policy.dart';
part 'nano_owl_alive_view.dart';
part 'nano_owl_alive_policy.dart';

class NanoOwlAlive extends StatefulWidget {
  const NanoOwlAlive({super.key, required this.activity, this.size = 106});
  final NanoActivity activity;
  final double size;
  @override
  State<NanoOwlAlive> createState() => _NanoOwlAliveState();
}

class _NanoOwlAliveState extends State<NanoOwlAlive>
    with SingleTickerProviderStateMixin, NanoAnimationPolicy {
  late final AnimationController motion;
  final random = math.Random();
  Timer? blinkTimer;
  Timer? sleepInactivityTimer;
  int blinkStep = -1;
  bool isAutoSleeping = false;

  /// Enters the existing sleep sequence after the owned inactivity timeout.
  void _enterSleep() {
    setState(() {
      isAutoSleeping = true;
      _applyActivityPolicy();
    });
  }

  bool get animate => motionEnabled;
  bool get isSleep => widget.activity == NanoActivity.sleep || isAutoSleeping;
  bool get isFly => widget.activity == NanoActivity.fly;

  /// Owns sprite and inactivity clocks; policy starts them after dependencies.
  @override
  void initState() {
    super.initState();
    motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _applyActivityPolicy();
    _resetInactivityTimer();
  }

  /// Stops every clock offscreen and reapplies the current sprite policy on return.
  @override
  void onMotionPolicyChanged() {
    _applyActivityPolicy();
    _resetInactivityTimer();
  }

  /// Pointer events also reach this listener when an ancestor owns the drag.
  void _wakeOnInteraction(PointerDownEvent event) {
    if (isAutoSleeping) {
      setState(() => isAutoSleeping = false);
      _applyActivityPolicy();
    }
    _resetInactivityTimer();
  }

  void _scheduleBlink() {
    if (!animate || isSleep || isFly) return;
    blinkTimer?.cancel();
    blinkTimer = Timer(
      Duration(milliseconds: 2400 + random.nextInt(3200)),
      _runBlink,
    );
  }

  void _runBlink() {
    if (!animate || !mounted || isSleep || isFly) return;
    var idx = 0;
    blinkTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      // BLINK-RACE-FIX: si el estado cambió a sleep/fly mientras el blink
      // estaba corriendo, cancelar inmediatamente y resetear el step.
      if (!mounted ||
          !animate ||
          isSleep ||
          isFly ||
          idx >= NanoOwlFrames.blinkFrames.length) {
        t.cancel();
        blinkTimer = null;
        if (mounted) {
          setState(() => blinkStep = -1);
          if (!isSleep && !isFly) _scheduleBlink();
        }
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
      final idx = (motion.value * (NanoOwlFrames.sleepFrames.length - 1))
          .round();
      return NanoOwlFrames.sleepFrames[idx.clamp(
        0,
        NanoOwlFrames.sleepFrames.length - 1,
      )];
    }
    if (isFly) {
      final idx = (motion.value * (NanoOwlFrames.flyFrames.length - 1)).round();
      return NanoOwlFrames.flyFrames[idx.clamp(
        0,
        NanoOwlFrames.flyFrames.length - 1,
      )];
    }
    return switch (widget.activity) {
      NanoActivity.listening => NanoOwlFrames.listening,
      NanoActivity.thinking ||
      NanoActivity.debating ||
      NanoActivity.comparing ||
      NanoActivity.acting => NanoOwlFrames.thinking,
      NanoActivity.success => NanoOwlFrames.success,
      NanoActivity.error => NanoOwlFrames.error,
      _ => NanoOwlFrames.idle,
    };
  }

  @override
  Widget build(BuildContext context) => buildView(context);
}

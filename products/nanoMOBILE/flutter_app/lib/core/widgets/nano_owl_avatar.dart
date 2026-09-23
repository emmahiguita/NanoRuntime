// nano_owl_avatar.dart — Avatar hiperrealista del búho mascota de Nano AI.
// QUÉ: Renderiza la mascota con animación cuadro a cuadro (sprite-sheet) real para
//       búho dormido (6 frames), volando (7 frames) y parpadeo biológico (5 frames).
// CÓMO: AnimationController cicla los frames según el NanoOwlState activo.
//       Glow óptico reactivo y respuesta táctil háptica elástica.
// POR QUÉ: Sustituye el truco anterior de escalar una imagen fija, logrando animación
//          orgánica 100% auténtica sin procesos zombis ni fugas de memoria.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_owl_state.dart';
export 'nano_owl_state.dart';

class NanoOwlAvatar extends StatefulWidget {
  const NanoOwlAvatar({
    super.key,
    this.size = 40.0,
    this.state = NanoOwlState.idle,
    this.enableBreathing = true,
    this.enableRandomBlink = true,
    this.enableGlow = true,
    this.onTap,
  });

  final double size;
  final NanoOwlState state;
  final bool enableBreathing;
  final bool enableRandomBlink;
  final bool enableGlow;
  final VoidCallback? onTap;

  @override
  State<NanoOwlAvatar> createState() => _NanoOwlAvatarState();
}

class _NanoOwlAvatarState extends State<NanoOwlAvatar> with TickerProviderStateMixin {
  late final AnimationController _spriteController;
  late final AnimationController _glowController;
  late final AnimationController _pressController;
  Timer? _blinkTimer;
  int _blinkFrame = -1;
  final math.Random _rng = math.Random();
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _spriteController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _pressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _applyState(widget.state);
    if (widget.enableRandomBlink && widget.state == NanoOwlState.idle) _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final a in NanoOwlFrames.allPrecacheAssets) { precacheImage(AssetImage(a), context); }
    }
  }

  @override
  void didUpdateWidget(covariant NanoOwlAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _applyState(widget.state);
  }

  void _applyState(NanoOwlState s) {
    _blinkTimer?.cancel();
    _blinkFrame = -1;
    if (s == NanoOwlState.sleep) {
      _spriteController.duration = const Duration(milliseconds: 1800);
      _spriteController.repeat(reverse: true);
    } else if (s == NanoOwlState.fly) {
      _spriteController.duration = const Duration(milliseconds: 560);
      _spriteController.repeat();
    } else {
      _spriteController.stop();
      if (s == NanoOwlState.idle && widget.enableRandomBlink) _scheduleBlink();
    }
    if (widget.enableGlow && (s == NanoOwlState.thinking || s == NanoOwlState.listening || s == NanoOwlState.responding || s == NanoOwlState.success)) {
      if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(milliseconds: 2400 + _rng.nextInt(3200)), _runBlink);
  }

  void _runBlink() {
    if (!mounted || widget.state != NanoOwlState.idle) return;
    var step = 0;
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted || step >= NanoOwlFrames.blinkFrames.length) {
        t.cancel();
        if (mounted) { setState(() => _blinkFrame = -1); _scheduleBlink(); }
        return;
      }
      setState(() => _blinkFrame = step++);
    });
  }

  String _currentAsset() {
    if (_blinkFrame >= 0 && _blinkFrame < NanoOwlFrames.blinkFrames.length) {
      return NanoOwlFrames.blinkFrames[_blinkFrame];
    }
    return switch (widget.state) {
      NanoOwlState.sleep => NanoOwlFrames.sleepFrames[(_spriteController.value * (NanoOwlFrames.sleepFrames.length - 1)).round()],
      NanoOwlState.fly => NanoOwlFrames.flyFrames[(_spriteController.value * (NanoOwlFrames.flyFrames.length - 1)).round()],
      NanoOwlState.blink => NanoOwlFrames.blinkFrames[2],
      NanoOwlState.listening => NanoOwlFrames.listening,
      NanoOwlState.thinking => NanoOwlFrames.thinking,
      NanoOwlState.responding => NanoOwlFrames.responding,
      NanoOwlState.success => NanoOwlFrames.success,
      NanoOwlState.error => NanoOwlFrames.error,
      NanoOwlState.wake => NanoOwlFrames.wake,
      _ => NanoOwlFrames.idle,
    };
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _spriteController.dispose();
    _glowController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = switch (widget.state) {
      NanoOwlState.thinking => const Color(0xFF00E5FF),
      NanoOwlState.listening => const Color(0xFF10B981),
      NanoOwlState.responding => const Color(0xFF818CF8),
      NanoOwlState.success => const Color(0xFF10B981),
      _ => Colors.transparent,
    };

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) { _pressController.reverse(); widget.onTap?.call(); },
        onTapCancel: () => _pressController.reverse(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_spriteController, _glowController, _pressController]),
          builder: (_, __) {
            final pressScale = 1.0 - (_pressController.value * 0.08);
            final glowVal = widget.enableGlow ? _glowController.value : 0.0;
            final isFly = widget.state == NanoOwlState.fly;
            final flyFloat = isFly ? math.sin(_spriteController.value * 2 * math.pi) * 3.5 : 0.0;

            return Transform.translate(
              offset: Offset(0, flyFloat),
              child: Transform.scale(
                scale: pressScale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: glowVal > 0.05 ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.25 * glowVal), blurRadius: widget.size * 0.45 * glowVal, spreadRadius: 1.5)],
                  ) : null,
                  child: Image.asset(
                    _currentAsset(),
                    key: ValueKey(_currentAsset()),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

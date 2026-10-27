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
part 'nano_owl_avatar_view.dart';
part 'nano_owl_avatar_cache.dart';

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

class _NanoOwlAvatarState extends State<NanoOwlAvatar>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _spriteController;
  late final AnimationController _glowController;
  late final AnimationController _pressController;
  Timer? _blinkTimer;
  int _blinkFrame = -1;
  final math.Random _rng = math.Random();
  bool _precached = false;
  bool _foreground = true, _motionAllowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _spriteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _applyState(widget.state);
    if (widget.enableRandomBlink && widget.state == NanoOwlState.idle) {
      _scheduleBlink();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed =
        TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);
    _applyState(widget.state);
    _precacheSprites();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _applyState(widget.state);
  }

  @override
  void didUpdateWidget(covariant NanoOwlAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _applyState(widget.state);
  }

  void _applyState(NanoOwlState s) {
    _blinkTimer?.cancel();
    _blinkFrame = -1;
    if (!_foreground || !_motionAllowed) {
      _spriteController.stop();
      _glowController.stop();
      return;
    }
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
    if (widget.enableGlow &&
        (s == NanoOwlState.thinking ||
            s == NanoOwlState.listening ||
            s == NanoOwlState.responding ||
            s == NanoOwlState.success)) {
      if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    if (!_foreground || !_motionAllowed || !widget.enableRandomBlink) return;
    _blinkTimer = Timer(
      Duration(milliseconds: 2400 + _rng.nextInt(3200)),
      _runBlink,
    );
  }

  void _runBlink() {
    if (!mounted ||
        !_foreground ||
        !_motionAllowed ||
        widget.state != NanoOwlState.idle) {
      return;
    }
    var step = 0;
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted ||
          !_foreground ||
          !_motionAllowed ||
          widget.state != NanoOwlState.idle ||
          step >= NanoOwlFrames.blinkFrames.length) {
        t.cancel();
        _blinkTimer = null;
        if (mounted) {
          setState(() => _blinkFrame = -1);
          if (widget.state == NanoOwlState.idle && widget.enableRandomBlink) {
            _scheduleBlink();
          }
        }
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
      NanoOwlState.sleep =>
        NanoOwlFrames.sleepFrames[(_spriteController.value *
                (NanoOwlFrames.sleepFrames.length - 1))
            .round()],
      NanoOwlState.fly =>
        NanoOwlFrames.flyFrames[(_spriteController.value *
                (NanoOwlFrames.flyFrames.length - 1))
            .round()],
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
    WidgetsBinding.instance.removeObserver(this);
    _blinkTimer?.cancel();
    _spriteController.dispose();
    _glowController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildView(context);
}

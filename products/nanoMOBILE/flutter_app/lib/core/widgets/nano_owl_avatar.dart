import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/nano_motion.dart';

/// Estados semánticos de la mascota Nano Owl.
enum NanoOwlState {
  /// Estado base: respiración micro-orgánica y parpadeo pseudo-aleatorio.
  idle,

  /// Parpadeo activo (transitorio o forzado).
  blink,

  /// Sueño / reposo: ojos cerrados, respiración lenta y profunda.
  sleep,

  /// Atención enfocada: postura alerta ante interacción del usuario.
  attention,

  /// Escuchando activamente voz/audio: aura de energía cian pulsante.
  listening,

  /// Razonando / ejecutando tarea: resplandor cósmico en rotación suave.
  thinking,

  /// Vuelo / transición dinámica.
  fly,
}

/// Avatar de alta fidelidad del búho mascota de Nano AI.
///
/// Gestiona su máquina de estados visual, precarga de texturas en memoria de GPU,
/// ciclo orgánico de respiración y parpadeo pseudo-aleatorio conforme al
/// Nano Design System v1.
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

  /// Diámetro visual del avatar en puntos lógicos (dp).
  final double size;

  /// Estado actual del búho.
  final NanoOwlState state;

  /// Si es `true`, ejecuta la animación de respiración micro-escalar continua.
  final bool enableBreathing;

  /// Si es `true`, ejecuta parpadeos espontáneos a intervalos fisiológicos (2.5s - 6.5s).
  final bool enableRandomBlink;

  /// Si es `true`, proyecta halos ópticos cuando está en `listening` o `thinking`.
  final bool enableGlow;

  /// Callback al tocar la mascota (reacciona con rebote elástico).
  final VoidCallback? onTap;

  @override
  State<NanoOwlAvatar> createState() => _NanoOwlAvatarState();
}

class _NanoOwlAvatarState extends State<NanoOwlAvatar>
    with TickerProviderStateMixin {
  // Rutas de assets oficiales
  static const String _idleAsset = 'assets/owl/idle/owl_neutral.png';

  static const List<String> _blinkFrames = [
    'assets/owl/blink/owl_blink_01.png',
    'assets/owl/blink/owl_blink_02.png',
    'assets/owl/blink/owl_blink_03.png',
    'assets/owl/blink/owl_blink_04.png',
    'assets/owl/blink/owl_blink_05.png',
  ];

  static const List<String> _sleepFrames = [
    'assets/owl/sleep/owl_sleep_01.png',
    'assets/owl/sleep/owl_sleep_02.png',
    'assets/owl/sleep/owl_sleep_03.png',
    'assets/owl/sleep/owl_sleep_04.png',
    'assets/owl/sleep/owl_sleep_05.png',
    'assets/owl/sleep/owl_sleep_06.png',
  ];

  static const List<String> _flyFrames = [
    'assets/owl/fly/owl_fly_01.png',
    'assets/owl/fly/owl_fly_02.png',
    'assets/owl/fly/owl_fly_03.png',
    'assets/owl/fly/owl_fly_04.png',
    'assets/owl/fly/owl_fly_05.png',
    'assets/owl/fly/owl_fly_06.png',
    'assets/owl/fly/owl_fly_07.png',
  ];

  // Controladores de animación
  late final AnimationController _breathController;
  late final Animation<double> _breathScaleY;
  late final Animation<double> _breathScaleX;

  late final AnimationController _glowPulseController;
  late final Animation<double> _glowPulse;

  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  // Estado de parpadeo y cuadro actual
  Timer? _blinkTimer;
  int _currentBlinkIndex = 0;
  bool _isBlinking = false;
  static const int _sleepFrameIndex = 5; // Por defecto descansando con ojos cerrados
  int _flyFrameIndex = 0;
  Timer? _flyLoopTimer;

  final math.Random _random = math.Random();
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();

    // 1. Respiración micro-orgánica (ciclo de 3.2 segundos)
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _breathScaleY = Tween<double>(begin: 1.0, end: 1.014).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
    _breathScaleX = Tween<double>(begin: 1.0, end: 1.006).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    if (widget.enableBreathing) {
      _breathController.repeat(reverse: true);
    }

    // 2. Halo pulsante para estados activos (listening / thinking)
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _glowPulse = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _glowPulseController, curve: Curves.easeInOutSine),
    );

    if (widget.state == NanoOwlState.listening ||
        widget.state == NanoOwlState.thinking) {
      _glowPulseController.repeat(reverse: true);
    }

    // 3. Respuesta táctil (resorte háptico físico)
    _pressController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.press,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: NanoMotionCurves.press),
    );

    // 4. Temporizador de parpadeo biológico
    if (widget.enableRandomBlink && widget.state == NanoOwlState.idle) {
      _scheduleNextBlink();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      _precacheFrames();
    }
  }

  void _precacheFrames() {
    precacheImage(const AssetImage(_idleAsset), context);
    for (final frame in _blinkFrames) {
      precacheImage(AssetImage(frame), context);
    }
    for (final frame in _sleepFrames) {
      precacheImage(AssetImage(frame), context);
    }
  }

  @override
  void didUpdateWidget(covariant NanoOwlAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.state != oldWidget.state) {
      _handleStateChange(oldWidget.state, widget.state);
    }

    if (widget.enableBreathing != oldWidget.enableBreathing) {
      if (widget.enableBreathing) {
        _breathController.repeat(reverse: true);
      } else {
        _breathController.stop();
        _breathController.value = 0;
      }
    }
  }

  void _handleStateChange(NanoOwlState oldState, NanoOwlState newState) {
    // Halo glow controller
    if (newState == NanoOwlState.listening || newState == NanoOwlState.thinking) {
      if (!_glowPulseController.isAnimating) {
        _glowPulseController.repeat(reverse: true);
      }
    } else {
      _glowPulseController.stop();
    }

    // Fly animation loop
    if (newState == NanoOwlState.fly) {
      _startFlyLoop();
    } else {
      _flyLoopTimer?.cancel();
      _flyLoopTimer = null;
    }

    // Random blink schedule
    if (newState == NanoOwlState.idle && widget.enableRandomBlink) {
      _scheduleNextBlink();
    } else {
      _blinkTimer?.cancel();
      _blinkTimer = null;
      _isBlinking = false;
    }
  }

  void _scheduleNextBlink() {
    _blinkTimer?.cancel();
    // Intervalo fisiológico aleatorio: entre 2.8 y 6.2 segundos
    final delayMs = 2800 + _random.nextInt(3400);
    _blinkTimer = Timer(Duration(milliseconds: delayMs), _triggerBlink);
  }

  void _triggerBlink() {
    if (!mounted || widget.state != NanoOwlState.idle) return;

    setState(() {
      _isBlinking = true;
      _currentBlinkIndex = 0;
    });

    _animateBlinkSequence();
  }

  void _animateBlinkSequence() {
    // Cadencia cinematográfica: ~45ms por frame (225ms total)
    Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentBlinkIndex < _blinkFrames.length - 1) {
        setState(() => _currentBlinkIndex++);
      } else {
        timer.cancel();
        setState(() {
          _isBlinking = false;
          _currentBlinkIndex = 0;
        });
        if (widget.enableRandomBlink && widget.state == NanoOwlState.idle) {
          _scheduleNextBlink();
        }
      }
    });
  }

  void _startFlyLoop() {
    _flyLoopTimer?.cancel();
    _flyLoopTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted || widget.state != NanoOwlState.fly) {
        timer.cancel();
        return;
      }
      setState(() {
        _flyFrameIndex = (_flyFrameIndex + 1) % _flyFrames.length;
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _flyLoopTimer?.cancel();
    _breathController.dispose();
    _glowPulseController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  String _resolveCurrentAsset() {
    if (_isBlinking || widget.state == NanoOwlState.blink) {
      return _blinkFrames[_currentBlinkIndex.clamp(0, _blinkFrames.length - 1)];
    }

    switch (widget.state) {
      case NanoOwlState.idle:
      case NanoOwlState.attention:
      case NanoOwlState.listening:
      case NanoOwlState.thinking:
        return _idleAsset;
      case NanoOwlState.sleep:
        return _sleepFrames[_sleepFrameIndex.clamp(0, _sleepFrames.length - 1)];
      case NanoOwlState.fly:
        return _flyFrames[_flyFrameIndex.clamp(0, _flyFrames.length - 1)];
      case NanoOwlState.blink:
        return _blinkFrames.last;
    }
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    if (!_isBlinking && widget.state == NanoOwlState.idle) {
      _triggerBlink();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _resolveCurrentAsset();
    final isGlowActive = widget.enableGlow &&
        (widget.state == NanoOwlState.listening ||
            widget.state == NanoOwlState.thinking);

    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _breathController,
            _pressController,
            if (isGlowActive) _glowPulseController,
          ]),
          builder: (context, child) {
            final breathScaleY =
                widget.enableBreathing ? _breathScaleY.value : 1.0;
            final breathScaleX =
                widget.enableBreathing ? _breathScaleX.value : 1.0;
            final pressScale = _pressScale.value;

            // Inclinación sutil cuando está en atención o escucha (~1.8 grados)
            final tiltAngle = (widget.state == NanoOwlState.attention ||
                    widget.state == NanoOwlState.listening)
                ? -0.035
                : 0.0;

            return Transform.scale(
              scale: pressScale,
              child: Transform.rotate(
                angle: tiltAngle,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo óptico de energía cósmica si está activo
                      if (isGlowActive)
                        Container(
                          width: widget.size * 0.92,
                          height: widget.size * 0.92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.state == NanoOwlState.thinking
                                    ? const Color(0xFFF97316).withValues(
                                        alpha: 0.35 * _glowPulse.value,
                                      )
                                    : const Color(0xFFFF8C2A).withValues(
                                        alpha: 0.40 * _glowPulse.value,
                                      ),
                                blurRadius: 16.0 * _glowPulse.value + 4.0,
                                spreadRadius: 3.0 * _glowPulse.value,
                              ),
                            ],
                          ),
                        ),

                      // Cuerpo del búho con escalado de respiración
                      Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(
                          breathScaleX,
                          breathScaleY,
                          1.0,
                        ),
                        child: Image.asset(
                          assetPath,
                          width: widget.size,
                          height: widget.size,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ],
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

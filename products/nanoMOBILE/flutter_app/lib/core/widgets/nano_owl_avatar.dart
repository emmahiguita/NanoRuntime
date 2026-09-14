import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/nano_motion.dart';

/// 10 Estados semánticos de la mascota Nano Owl según la guía visual oficial.
enum NanoOwlState {
  /// 1. IDLE: Tranquilo, siempre contigo. Respiración micro-orgánica y parpadeo vivo.
  idle,

  /// 2. PARPADEO: Natural y vivo.
  blink,

  /// 3. ESCUCHANDO: Te presto atención. Aura de energía cian pulsante.
  listening,

  /// 4. PENSANDO: Analizando... Resplandor cósmico orbital.
  thinking,

  /// 5. RESPONDIENDO: Generando tu respuesta con proyección holográfica.
  responding,

  /// 6. ÉXITO: ¡Listo! Alas abiertas y destellos estelares de confirmación.
  success,

  /// 7. DUDA / ERROR: Revisemos... Postura atenta con cabeza inclinada.
  error,

  /// 8. DORMIDO: Descansando plácidamente con ojos cerrados.
  sleep,

  /// 9. DESPERTAR: ¡De vuelta! Guiño de ojo y reactivación.
  wake,

  /// 10. VOLANDO / TRANSICIÓN: Siempre más lejos, con estela estelar.
  fly,
}

/// Avatar de alta fidelidad del búho mascota de Nano AI.
///
/// Gestiona la máquina de 10 estados visuales hiperrealistas, precarga de
/// texturas en GPU, ciclo orgánico de respiración y parpadeo fisiológico.
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

  /// Si es `true`, ejecuta parpadeos espontáneos a intervalos fisiológicos (2.5s - 6.0s).
  final bool enableRandomBlink;

  /// Si es `true`, proyecta halos ópticos cuando está en `listening`, `thinking` o `responding`.
  final bool enableGlow;

  /// Callback al tocar la mascota (reacciona con rebote elástico háptico).
  final VoidCallback? onTap;

  @override
  State<NanoOwlAvatar> createState() => _NanoOwlAvatarState();
}

class _NanoOwlAvatarState extends State<NanoOwlAvatar>
    with TickerProviderStateMixin {
  // Rutas de assets oficiales de los 10 estados
  static const String _stateIdle = 'assets/owl/states/owl_idle.png';
  static const String _stateBlink = 'assets/owl/states/owl_blink.png';
  static const String _stateListening = 'assets/owl/states/owl_listening.png';
  static const String _stateThinking = 'assets/owl/states/owl_thinking.png';
  static const String _stateResponding = 'assets/owl/states/owl_responding.png';
  static const String _stateSuccess = 'assets/owl/states/owl_success.png';
  static const String _stateError = 'assets/owl/states/owl_error.png';
  static const String _stateSleep = 'assets/owl/states/owl_sleep.png';
  static const String _stateWake = 'assets/owl/states/owl_wake.png';
  static const String _stateFly = 'assets/owl/states/owl_fly.png';

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
  bool _isBlinking = false;

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

    _breathScaleY = Tween<double>(begin: 1.0, end: 1.018).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
    _breathScaleX = Tween<double>(begin: 1.0, end: 1.008).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    if (widget.enableBreathing) {
      _breathController.repeat(reverse: true);
    }

    // 2. Halo pulsante para estados activos (listening / thinking / responding)
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _glowPulse = Tween<double>(begin: 0.35, end: 0.90).animate(
      CurvedAnimation(parent: _glowPulseController, curve: Curves.easeInOutSine),
    );

    if (_isGlowState(widget.state)) {
      _glowPulseController.repeat(reverse: true);
    }

    // 3. Respuesta táctil (resorte háptico físico)
    _pressController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.press,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: NanoMotionCurves.press),
    );

    // 4. Temporizador de parpadeo biológico
    if (widget.enableRandomBlink && widget.state == NanoOwlState.idle) {
      _scheduleNextBlink();
    }
  }

  bool _isGlowState(NanoOwlState state) {
    return state == NanoOwlState.listening ||
        state == NanoOwlState.thinking ||
        state == NanoOwlState.responding ||
        state == NanoOwlState.success;
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
    final assets = [
      _stateIdle,
      _stateBlink,
      _stateListening,
      _stateThinking,
      _stateResponding,
      _stateSuccess,
      _stateError,
      _stateSleep,
      _stateWake,
      _stateFly,
    ];
    for (final asset in assets) {
      precacheImage(AssetImage(asset), context);
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
    if (_isGlowState(newState)) {
      if (!_glowPulseController.isAnimating) {
        _glowPulseController.repeat(reverse: true);
      }
    } else {
      _glowPulseController.stop();
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
    // Intervalo fisiológico aleatorio: entre 2.5 y 5.5 segundos
    final delayMs = 2500 + _random.nextInt(3000);
    _blinkTimer = Timer(Duration(milliseconds: delayMs), _triggerBlink);
  }

  void _triggerBlink() {
    if (!mounted || widget.state != NanoOwlState.idle) return;

    setState(() => _isBlinking = true);

    // Duración de parpadeo realista: 180ms
    Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _isBlinking = false);
      if (widget.enableRandomBlink && widget.state == NanoOwlState.idle) {
        _scheduleNextBlink();
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breathController.dispose();
    _glowPulseController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  String _resolveCurrentAsset() {
    if (_isBlinking || widget.state == NanoOwlState.blink) {
      return _stateBlink;
    }

    switch (widget.state) {
      case NanoOwlState.idle:
        return _stateIdle;
      case NanoOwlState.blink:
        return _stateBlink;
      case NanoOwlState.listening:
        return _stateListening;
      case NanoOwlState.thinking:
        return _stateThinking;
      case NanoOwlState.responding:
        return _stateResponding;
      case NanoOwlState.success:
        return _stateSuccess;
      case NanoOwlState.error:
        return _stateError;
      case NanoOwlState.sleep:
        return _stateSleep;
      case NanoOwlState.wake:
        return _stateWake;
      case NanoOwlState.fly:
        return _stateFly;
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
    final isGlowActive = widget.enableGlow && _isGlowState(widget.state);

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

            // Inclinación suave según estado
            final tiltAngle = (widget.state == NanoOwlState.listening ||
                    widget.state == NanoOwlState.error)
                ? -0.04
                : 0.0;

            Color glowColor;
            switch (widget.state) {
              case NanoOwlState.thinking:
                glowColor = const Color(0xFF00E5FF);
                break;
              case NanoOwlState.listening:
                glowColor = const Color(0xFF10B981);
                break;
              case NanoOwlState.responding:
                glowColor = const Color(0xFF818CF8);
                break;
              case NanoOwlState.success:
                glowColor = const Color(0xFF10B981);
                break;
              default:
                glowColor = const Color(0xFF00E5FF);
            }

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
                      // Halo óptico de energía cósmica
                      if (isGlowActive)
                        Container(
                          width: widget.size * 0.90,
                          height: widget.size * 0.90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: glowColor.withValues(
                                  alpha: 0.40 * _glowPulse.value,
                                ),
                                blurRadius: 18.0 * _glowPulse.value + 4.0,
                                spreadRadius: 3.0 * _glowPulse.value,
                              ),
                            ],
                          ),
                        ),

                      // Cuerpo del búho con escalado orgánico de respiración
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

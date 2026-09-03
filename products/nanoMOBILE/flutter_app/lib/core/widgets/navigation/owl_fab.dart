import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Estados del búho.
enum _OwlState { sleeping, idle, takeoff, flying }

/// FAB búho animado — personaje del diseño NanoRuntime (TER-17).
///
/// Sprites reales (assets/owl/, PNG RGBA 256 px, reescalados desde el
/// diseño original 1024 px). Arquitectura de 3 capas del diseño:
/// 1. Burbuja de vidrio iOS transparente (blur real + anillo blanco
///    + brillo especular + glow cian).
/// 2. Personaje con cinemática: respiración en reposo, parpadeo
///    aleatorio, despegue (alas) y aleteo continuo en el aire.
/// 3. Zzz flotantes cuando duerme (panel cerrado).
///
/// Estados ligados al marco de navegación:
/// - `expanded == false` (panel cerrado): dormido, loop de sueño + Zzz.
/// - `expanded == true` (panel abierto): despierto, viendo y parpadea.
/// - Durante el arrastre (onPanStart): despegue con alas y vuela
///   mientras se mueve; al soltar (onPanEnd/Cancel) aterriza y vuelve
///   al estado que corresponde al panel.
///
/// TER-22 coreografía de vuelo al soltar: si [gliding] es true, el
/// búho NO aterriza al soltar — sigue aleteando durante el trayecto
/// animado a la esquina y se posa cuando el marco apaga la señal
/// (llegada del `AnimatedPositioned`). Cinemática 3D sobre los sprites:
/// inclinación direccional ([flightDirection]), squash & stretch en
/// fase con el aleteo, sway secundario, paralaje de sombra y squash de
/// aterrizaje al posarse.
class OwlFloatingActionButton extends StatefulWidget {
  const OwlFloatingActionButton({
    super.key,
    this.size = 56.0,
    this.expanded = false,
    this.gliding = false,
    this.flightDirection = Offset.zero,
    required this.onTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
  });

  /// Diámetro del círculo base del FAB (el personaje asoma ligeramente).
  final double size;
  final bool expanded;

  /// Señal del marco: trayecto animado a la esquina en curso. Mientras
  /// es true el búho no aterriza al soltar; al pasar a false, se posa.
  final bool gliding;

  /// Dirección normalizada del trayecto de vuelo (eje Y hacia abajo).
  /// Inclina al búho hacia donde vuela y desplaza la sombra en contra.
  final Offset flightDirection;

  final VoidCallback onTap;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;
  final VoidCallback? onPanCancel;

  @override
  State<OwlFloatingActionButton> createState() =>
      _OwlFloatingActionButtonState();
}

class _OwlFloatingActionButtonState extends State<OwlFloatingActionButton>
    with TickerProviderStateMixin {
  static const _blinkFrames = [
    'assets/owl/blink/owl_blink_01.png',
    'assets/owl/blink/owl_blink_02.png',
    'assets/owl/blink/owl_blink_03.png',
    'assets/owl/blink/owl_blink_04.png',
    'assets/owl/blink/owl_blink_05.png',
    'assets/owl/blink/owl_blink_01.png',
  ];
  static const _sleepFrames = [
    'assets/owl/sleep/owl_sleep_01.png',
    'assets/owl/sleep/owl_sleep_02.png',
    'assets/owl/sleep/owl_sleep_03.png',
    'assets/owl/sleep/owl_sleep_04.png',
    'assets/owl/sleep/owl_sleep_05.png',
    'assets/owl/sleep/owl_sleep_06.png',
  ];
  static const _takeoffFrames = [
    'assets/owl/takeoff/owl_takeoff_01.png',
    'assets/owl/takeoff/owl_takeoff_02.png',
  ];
  // Bucle de aleteo cerrado en el aire.
  static const _flightFrames = [
    'assets/owl/fly/owl_fly_05.png',
    'assets/owl/fly/owl_fly_03.png',
    'assets/owl/fly/owl_fly_06.png',
    'assets/owl/fly/owl_fly_01.png',
    'assets/owl/fly/owl_fly_02.png',
  ];
  static const _neutralFrame = 'assets/owl/idle/owl_neutral.png';

  _OwlState _state = _OwlState.sleeping;

  late AnimationController _breathController;
  late AnimationController _hoverController;
  late AnimationController _zzzController;
  // TER-22: squash de aterrizaje (pico a mitad: sin(pi * t)).
  late AnimationController _landController;
  // TER-22: multiplicador 0..1 de la inclinación direccional.
  late AnimationController _tiltController;
  // UI-REV-01: opacidad de la burbuja de vidrio. Controller explícito (no
  // AnimatedOpacity): cuando llega a 0 el BackdropFilter sale del árbol —
  // un blur sigma 14 invisible durante el vuelo igual paga GPU en Mali.
  late AnimationController _bubbleController;
  late Animation<double> _breathScaleY;
  late Animation<double> _breathScaleX;
  late Animation<double> _hoverOffsetY;
  late Animation<double> _hoverRotation;

  // TER-22: objetivos de inclinación calculados desde flightDirection.
  double _tiltRotZ = 0;
  double _tiltSkewX = 0;
  Offset _shadowOffset = Offset.zero;

  int _frameIndex = 0;
  bool _blinkedOnce = false;
  Timer? _blinkTimer;
  Timer? _frameTimer;

  String get _asset {
    switch (_state) {
      case _OwlState.sleeping:
        return _sleepFrames[_frameIndex % _sleepFrames.length];
      case _OwlState.takeoff:
        return _takeoffFrames[_frameIndex.clamp(0, _takeoffFrames.length - 1)];
      case _OwlState.flying:
        return _flightFrames[_frameIndex % _flightFrames.length];
      case _OwlState.idle:
        if (_frameIndex > 0 && _frameIndex < _blinkFrames.length) {
          return _blinkFrames[_frameIndex];
        }
        return _neutralFrame;
    }
  }

  @override
  void initState() {
    super.initState();
    _state = widget.expanded ? _OwlState.idle : _OwlState.sleeping;

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _breathScaleY = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
    _breathScaleX = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // TER-19: begin 0 — al pasar a vuelo el valor del controlador es 0,
    // sin salto de 8 px ni rotación seca; la flotación crece suave.
    _hoverOffsetY = Tween<double>(begin: 0.0, end: -9.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOutSine),
    );
    _hoverRotation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOutSine),
    );

    // UI-REV-01: sin repeat() incondicional — el ticker solo corre cuando
    // el búho duerme (Zzz visibles). _startStateLoop lo arranca/para.
    _zzzController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // TER-22: pose física — squash breve al posarse (240 ms). Sin curva:
    // la forma sin(pi * t) ya dibuja el hundimiento y la recuperación.
    _landController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    // TER-22: inclinación direccional entra/sale suave (200 ms).
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // UI-REV-01: burbuja visible en reposo; se desvanece al despegar.
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1.0,
    );

    _startStateLoop();
    // TER-20: precarga de TODOS los sprites — la primera transición de
    // estado ya no decodifica PNGs en el hilo de UI (causa del lag al
    // primer despegue/parpadeo).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheSprites();
    });
  }

  Future<void> _precacheSprites() async {
    const all = [
      ..._sleepFrames,
      ..._blinkFrames,
      ..._takeoffFrames,
      ..._flightFrames,
      _neutralFrame,
    ];
    try {
      await Future.wait(
        all.map((asset) => precacheImage(AssetImage(asset), context)),
      );
    } catch (_) {
      // Precache best-effort: si un asset falla, el Image lo decodifica
      // en demanda. No es crítico.
    }
  }

  @override
  void didUpdateWidget(covariant OwlFloatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El marco cambia expanded al abrir/cerrar el panel: transición
    // dormido <-> despierto. Si está volando no se interrumpe (aterriza
    // al soltar el arrastre).
    if (widget.expanded != oldWidget.expanded && _state != _OwlState.flying) {
      _state = widget.expanded ? _OwlState.idle : _OwlState.sleeping;
      _frameIndex = 0;
      _startStateLoop();
    }
    // TER-22: señal del marco. Arranca el trayecto → entra la
    // inclinación; llega a la esquina → pose.
    if (widget.gliding != oldWidget.gliding) {
      if (widget.gliding) {
        _tiltController.forward(from: 0);
      } else if (_state == _OwlState.flying) {
        _land();
      }
    }
    if (widget.flightDirection != oldWidget.flightDirection) {
      _updateTiltTarget(widget.flightDirection);
      if (widget.gliding) _tiltController.forward(from: 0);
    }
  }

  /// TER-22: traduce la dirección del trayecto a inclinación (banco
  /// lateral en X, pitch simulado en Y) y paralaje de la sombra.
  void _updateTiltTarget(Offset dir) {
    final norm = sqrt(dir.dx * dir.dx + dir.dy * dir.dy);
    if (norm < 0.01) {
      _tiltRotZ = 0;
      _tiltSkewX = 0;
      _shadowOffset = Offset.zero;
      return;
    }
    final nx = dir.dx / norm;
    final ny = dir.dy / norm;
    _tiltRotZ = nx * 0.10;
    _tiltSkewX = ny * 0.05;
    _shadowOffset = Offset(-nx * 5, -ny * 3);
  }

  void _startStateLoop() {
    _frameTimer?.cancel();
    _blinkTimer?.cancel();
    switch (_state) {
      case _OwlState.sleeping:
        // UI-REV-01: el ticker de Zzz solo vive mientras se ven.
        if (!_zzzController.isAnimating) _zzzController.repeat();
        _frameTimer = Timer.periodic(const Duration(milliseconds: 380), (t) {
          if (!mounted || _state != _OwlState.sleeping) {
            t.cancel();
            return;
          }
          setState(() => _frameIndex++);
        });
      case _OwlState.idle:
      case _OwlState.takeoff:
      case _OwlState.flying:
        // UI-REV-01: sin Zzz visibles → sin ticker de Zzz.
        _zzzController
          ..stop()
          ..value = 0;
        if (_state == _OwlState.idle) _scheduleNextBlink();
        break;
    }
  }

  void _scheduleNextBlink() {
    if (!mounted || _state != _OwlState.idle) return;
    // TER-18: primer parpadeo temprano (1.2-2.2 s) al despertar para que
    // el efecto sea visible al abrir el panel; luego cada 2.5-4.5 s.
    final next = _blinkedOnce
        ? Duration(milliseconds: 2500 + Random().nextInt(2000))
        : Duration(milliseconds: 1200 + Random().nextInt(1000));
    _blinkTimer = Timer(next, () {
      _blinkedOnce = true;
      _playBlink();
    });
  }

  void _playBlink() {
    if (!mounted || _state != _OwlState.idle) return;
    var frame = 0;
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 55), (t) {
      if (!mounted || _state != _OwlState.idle) {
        t.cancel();
        return;
      }
      setState(() => _frameIndex = frame);
      frame++;
      if (frame >= _blinkFrames.length) {
        t.cancel();
        setState(() => _frameIndex = 0);
        _scheduleNextBlink();
      }
    });
  }

  /// Despegue: abre las alas (2 fotogramas) y queda aleteando en el aire.
  void _takeoff() {
    if (_state == _OwlState.flying) return;
    _frameTimer?.cancel();
    _blinkTimer?.cancel();
    // TER-20: breath pausado en vuelo — un solo controller repinta el
    // personaje (hover); la respiración queda congelada hasta aterrizar.
    _breathController.stop();
    // UI-REV-01: Zzz fuera (dormido → volando) y burbuja se desvanece.
    _zzzController
      ..stop()
      ..value = 0;
    _bubbleController.reverse();
    setState(() {
      _state = _OwlState.takeoff;
      _frameIndex = 0;
    });
    var takeoffFrame = 0;
    _frameTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted || _state != _OwlState.takeoff) {
        t.cancel();
        return;
      }
      takeoffFrame++;
      if (takeoffFrame >= _takeoffFrames.length) {
        t.cancel();
        setState(() {
          _state = _OwlState.flying;
          _frameIndex = 0;
        });
        _hoverController.repeat(reverse: true);
        _startFlightLoop();
      } else {
        setState(() => _frameIndex = takeoffFrame);
      }
    });
  }

  void _startFlightLoop() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted || _state != _OwlState.flying) {
        t.cancel();
        return;
      }
      setState(() => _frameIndex++);
    });
  }

  /// Aterrizaje: vuelve a dormido o despierto según el panel. TER-22:
  /// pose física con squash de aterrizaje y retorno de la inclinación.
  void _land() {
    if (_state != _OwlState.flying) return;
    _frameTimer?.cancel();
    // TER-19: reset a 0 — el próximo despegue arranca la flotación
    // desde el suelo, sin heredar la altura del vuelo anterior.
    _hoverController
      ..stop()
      ..value = 0;
    _breathController.repeat(reverse: true);
    _tiltController.reverse();
    _landController.forward(from: 0);
    // UI-REV-01: la burbuja de vidrio reaparece al posarse.
    _bubbleController.forward();
    setState(() {
      _state = widget.expanded ? _OwlState.idle : _OwlState.sleeping;
      _frameIndex = 0;
    });
    _startStateLoop();
  }

  @override
  void dispose() {
    _breathController.dispose();
    _hoverController.dispose();
    _zzzController.dispose();
    _landController.dispose();
    _tiltController.dispose();
    _bubbleController.dispose();
    _blinkTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final spriteSize = size * 1.15;
    final sleeping = _state == _OwlState.sleeping;
    // TER-19: airborne = despegue + vuelo. El círculo y la sombra se
    // desvanecen desde el primer fotograma de takeoff — antes solo en
    // vuelo, y en drags cortos el círculo azul quedaba visible detrás.
    final airborne =
        _state == _OwlState.takeoff || _state == _OwlState.flying;

    return Semantics(
      button: true,
      label: widget.expanded
          ? 'Mover o contraer navegación'
          : 'Abrir navegación. Mantén y arrastra para mover.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanStart: (d) {
          _takeoff();
          widget.onPanStart?.call(d);
        },
        onPanUpdate: widget.onPanUpdate,
        onPanEnd: (d) {
          // TER-22: la decisión de aterrizar es del marco (gliding).
          // El marco setea la señal dentro de este mismo callback; se
          // resuelve en el postFrame con el valor ya actualizado.
          widget.onPanEnd?.call(d);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!widget.gliding && _state == _OwlState.flying) _land();
          });
        },
        onPanCancel: () {
          widget.onPanCancel?.call();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!widget.gliding && _state == _OwlState.flying) _land();
          });
        },
        child: SizedBox(
          width: size,
          height: size,
          child: RepaintBoundary(
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // CAPA 0: sombra proyectada en el suelo — se expande y
                // difumina cuando el búho despega o vuela (más altura =
                // sombra más tenue y ancha). TER-22: en vuelo se desplaza
                // contra la dirección del trayecto (paralaje de
                // profundidad). Ultra realista sin tocar el FAB.
                Positioned(
                  bottom: airborne ? -14 : -9,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.translate(
                      offset:
                          _state == _OwlState.flying ? _shadowOffset : Offset.zero,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        width: airborne ? size * 0.92 : size * 0.68,
                        height: airborne ? 12 : 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: airborne ? 0.14 : 0.30,
                              ),
                              blurRadius: airborne ? 14 : 8,
                              spreadRadius: airborne ? 3 : 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // CAPA 1: burbuja de vidrio iOS (TER-20) — el círculo
                // azul sólido desaparece: burbuja transparente con blur
                // real del fondo, anillo blanco y brillo especular. Se
                // desvanece desde el despegue (airborne): nunca flota
                // detrás del personaje en vuelo.
                // UI-REV-01: AnimatedBuilder en vez de AnimatedOpacity —
                // al llegar a 0 el BackdropFilter sale del ÁRBOL (blur
                // sigma 14 invisible durante el vuelo igual paga GPU,
                // visible como lag de arrastre en Mali/Oppo).
                AnimatedBuilder(
                  animation: _bubbleController,
                  builder: (context, child) {
                    final v = _bubbleController.value;
                    if (v <= 0.0) return const SizedBox.shrink();
                    return Opacity(opacity: v, child: child);
                  },
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 14,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color:
                              const Color(0xFF00E5FF).withValues(alpha: 0.22),
                          blurRadius: 18,
                          spreadRadius: -2,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.20),
                                const Color(
                                  0xFF9FC5E8,
                                ).withValues(alpha: 0.08),
                                const Color(
                                  0xFF3B82F6,
                                ).withValues(alpha: 0.06),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.38),
                              width: 1.1,
                            ),
                          ),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: Alignment(-0.35, -0.45),
                                radius: 0.6,
                                colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // CAPA 2: personaje con cinemática (respiración / vuelo).
                // TER-22: en vuelo suma squash & stretch en fase con el
                // aleteo, inclinación direccional y sway secundario; al
                // posarse, squash de aterrizaje (sin(pi * t)).
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _breathController,
                    _hoverController,
                    _landController,
                    _tiltController,
                  ]),
                  builder: (context, child) {
                    final flying = _state == _OwlState.flying;
                    final offsetY = flying ? _hoverOffsetY.value : 0.0;
                    final rot = flying ? _hoverRotation.value : 0.0;
                    // Squash & stretch de aleteo: el cuerpo late con
                    // cada batida de ala (periodo = 5 frames * 80 ms).
                    final wingPhase = sin(
                      2 * pi * (_frameIndex % _flightFrames.length) /
                          _flightFrames.length,
                    );
                    final scaleX = flying ? 1.05 + 0.05 * wingPhase : _breathScaleX.value;
                    final scaleY = flying ? 1.05 - 0.04 * wingPhase : _breathScaleY.value;
                    // Pose física: squash al posarse, recuperación suave.
                    final landT = _landController.isAnimating
                        ? _landController.value
                        : 0.0;
                    final landSquash = sin(pi * landT);
                    final sx = scaleX * (1 + 0.08 * landSquash);
                    final sy = scaleY * (1 - 0.10 * landSquash);
                    // Inclinación direccional (banco + pitch simulado).
                    final tilt = _tiltController.value;
                    final rotZ = rot + tilt * _tiltRotZ;
                    final skew = tilt * _tiltSkewX;
                    // Sway secundario: oscilación lateral suave en fase
                    // con la flotación — movimiento vivo, no rígido.
                    final swayX = flying
                        ? sin(_hoverController.value * 2 * pi * 2) * 1.6
                        : 0.0;
                    return Positioned(
                      bottom:
                          -(spriteSize - size) / 2 + 2 - offsetY,
                      child: Transform(
                        alignment: const FractionalOffset(0.5, 0.88),
                        transform: Matrix4.identity()
                          ..setEntry(1, 0, skew)
                          ..rotateZ(rotZ)
                          ..scaleByDouble(sx, sy, 1, 1)
                          ..translateByDouble(swayX, 0, 0, 1),
                        child: SizedBox(
                          width: spriteSize,
                          height: spriteSize,
                          child: Image.asset(
                            _asset,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            // TER-20: sin flash entre fotogramas —
                            // mantiene el sprite actual hasta que el
                            // siguiente esté listo (precargado:
                            // cambio instantáneo, sincronizado).
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // CAPA 3: Zzz flotantes mientras duerme (panel cerrado).
                if (sleeping)
                  AnimatedBuilder(
                    animation: _zzzController,
                    builder: (context, _) {
                      final t = _zzzController.value;
                      return Positioned(
                        top: -14,
                        right: -6,
                        child: IgnorePointer(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Positioned(
                                  right: i * 8.0,
                                  top: -i * 7.0 - (t * 12),
                                  child: Opacity(
                                    opacity: (0.25 +
                                            0.75 *
                                                ((sin(
                                                          2 * pi * t -
                                                              i * 2.2,
                                                        ) +
                                                        1) /
                                                    2))
                                        .clamp(0.0, 1.0),
                                    child: Text(
                                      'Z',
                                      style: TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                        fontSize: 10.0 + i * 2.0,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.35),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

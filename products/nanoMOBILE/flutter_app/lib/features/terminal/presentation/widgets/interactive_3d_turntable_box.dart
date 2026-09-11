import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import '../../domain/terminal_hub_card.dart';

/// Visor 3D Turntable Interactivo con rotación 360° sobre el eje Y (Yaw)
/// modelado como una **Caja Física de Software / GameCube Case** suspendida en el espacio.
///
/// Características físicas:
/// - Rotación 360° con arrastre gestual e inercia / momento angular suave.
/// - Grosor físico real (frontal, lomo izquierdo, lomo derecho, parte trasera).
/// - Proyección de perspectiva (`setEntry(3, 2, 0.00125)`).
/// - Reflejo holográfico / iridiscente que se desplaza según el ángulo de incidencia.
/// - Estructura exterior con bisel de caja plástica (GameCube case style).
class Interactive3DTurntableBox extends StatefulWidget {
  const Interactive3DTurntableBox({
    super.key,
    required this.card,
    this.width = 190.0,
    this.height = 265.0,
    this.depth = 26.0,
    this.autoRotate = true,
    this.onRotationChanged,
  });

  final TerminalHubCard card;
  final double width;
  final double height;
  final double depth;
  final bool autoRotate;
  final ValueChanged<double>? onRotationChanged;

  @override
  State<Interactive3DTurntableBox> createState() =>
      _Interactive3DTurntableBoxState();
}

class _FaceRender {
  final double z;
  final Widget widget;
  const _FaceRender(this.z, this.widget);
}

class _Interactive3DTurntableBoxState extends State<Interactive3DTurntableBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  // Ángulos en radianes
  double _yaw = 0.0;
  double _pitch = -0.06; // Ligera inclinación hacia adelante (~-3.5°)
  double _roll = -0.0108; // Coherente con pitch * 0.18 desde el primer frame.

  // Físicas de inercia y momento angular
  double _angularVelocity = 0.0;
  bool _isDragging = false;
  Duration? _lastTick;
  double? _targetYaw;
  static const _perspective = 0.00125;
  static const double _borderWidth = 1.6;

  Color _casingBorderColor(double light) {
    return Color.lerp(
      const Color(0xFF162338),
      const Color(0xFF334A6E),
      light,
    )!;
  }

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_onTick)
          ..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTick() {
    final elapsed = _animController.lastElapsedDuration ?? Duration.zero;
    final previous = _lastTick;
    _lastTick = elapsed;
    if (!mounted || _isDragging || previous == null) return;
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, 0.05);
    if (dt == 0) return;

    final target = _targetYaw;
    if (target != null) {
      final distance = target - _yaw;
      setState(() {
        _yaw += distance * (1 - math.exp(-14 * dt));
        if (distance.abs() < 0.002) {
          _yaw = target;
          _targetYaw = null;
        }
      });
      _notifyRotation();
      return;
    }

    if (_angularVelocity.abs() > 0.002) {
      // Inercia con desaceleración amortiguada (friction decay)
      setState(() {
        _yaw += _angularVelocity * dt;
        _angularVelocity *= math.pow(0.94, dt * 60);
      });
      _notifyRotation();
    } else if (widget.autoRotate) {
      // Rotación continua muy suave tipo vitrina de exhibición
      setState(() {
        _yaw = (_yaw + 0.36 * dt) % (2 * math.pi);
      });
      _notifyRotation();
    }
  }

  void _notifyRotation() {
    final double normalized = _yaw % (2 * math.pi);
    widget.onRotationChanged?.call(normalized);
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _angularVelocity = 0.0;
    _targetYaw = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Movimiento horizontal -> Giro Yaw continuo 360°
      _yaw += details.delta.dx * 0.015;
      // Movimiento vertical -> Leve inclinación Pitch (-15° a +15°)
      _pitch = (_pitch + details.delta.dy * 0.007).clamp(-0.25, 0.25);
      _roll = (_pitch * 0.18);
    });
    _notifyRotation();
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    // Captura de momentum al soltar
    final double vx = details.velocity.pixelsPerSecond.dx;
    _angularVelocity = (vx * 0.0026).clamp(-5.0, 5.0);
  }

  void flipTo({required bool showFront}) {
    setState(() {
      _yaw = showFront ? 0.0 : math.pi;
      _targetYaw = null;
      _angularVelocity = 0.0;
    });
    _notifyRotation();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    final cosY = math.cos(_yaw);
    final sinY = math.sin(_yaw);
    final cosP = math.cos(_pitch);
    final sinP = math.sin(_pitch);
    final cosR = math.cos(_roll);
    final sinR = math.sin(_roll);

    final bool isFrontFacing = cosY >= -0.05;

    final double w = widget.width;
    final double h = widget.height;
    final double d = widget.depth;

    // Dirección del brillo especular / holográfico según rotación física
    final Alignment holoAlign = Alignment(
      (sinY * 1.6).clamp(-1.0, 1.0),
      -(sinP * 1.6).clamp(-1.0, 1.0),
    );

    // =======================================================================
    // TRANSFORMACIÓN DE NORMALES 3D EXACTA (Yaw -> Roll -> Pitch)
    // =======================================================================
    // Permite Backface Culling estricto (nz > 0) e iluminación direccional física.
    (double nx, double ny, double nz) transformNormal(
      double x,
      double y,
      double z,
    ) {
      // 1. Rotación Yaw (alrededor de Y)
      final double x1 = x * cosY + z * sinY;
      final double y1 = y;
      final double z1 = -x * sinY + z * cosY;

      // 2. Rotación Roll (alrededor de Z)
      final double x2 = x1 * cosR - y1 * sinR;
      final double y2 = x1 * sinR + y1 * cosR;
      final double z2 = z1;

      // 3. Rotación Pitch (alrededor de X)
      final double x3 = x2;
      final double y3 = y2 * cosP - z2 * sinP;
      final double z3 = y2 * sinP + z2 * cosP;

      return (x3, y3, z3);
    }

    // Iluminación direccional (fuente de luz virtual en top-front-right: [0.35, -0.65, 0.67])
    double computeLighting(double nx, double ny, double nz) {
      final double dot = (nx * 0.35 - ny * 0.65 + nz * 0.67);
      final double diffuse = dot.clamp(0.0, 1.0);
      return 0.40 + 0.60 * diffuse; // Rango [0.40, 1.0]
    }

    final List<_FaceRender> visibleFaces = [];

    // -----------------------------------------------------------------------
    // 1. CARA FRONTAL (Z = +d / 2, normal local [0, 0, 1])
    // -----------------------------------------------------------------------
    final (fnx, fny, fnz) = transformNormal(0.0, 0.0, 1.0);
    // Camera is at +1/p on Z. Test the normal against the vector from the
    // face centre to that camera, not an orthographic nz > 0 test.
    if (fnz > _perspective * d / 2) {
      final double light = computeLighting(fnx, fny, fnz);
      visibleFaces.add(
        _FaceRender(
          (d / 2) * fnz,
          Transform(
            key: const ValueKey('3d_box_face_front'),
            alignment: Alignment.center,
            transform: Matrix4.identity()..setTranslationRaw(0.0, 0.0, d / 2),
            child: _buildFrontFace(colors, isDark, holoAlign, light),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // 2. CARA TRASERA (Z = -d / 2, normal local [0, 0, -1])
    // -----------------------------------------------------------------------
    final (bnx, bny, bnz) = (-fnx, -fny, -fnz);
    if (bnz > _perspective * d / 2) {
      final double light = computeLighting(bnx, bny, bnz);
      visibleFaces.add(
        _FaceRender(
          (d / 2) * bnz,
          Transform(
            key: const ValueKey('3d_box_face_back'),
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setTranslationRaw(0.0, 0.0, -d / 2)
              ..rotateY(math.pi),
            child: _buildBackFace(colors, isDark, holoAlign, light),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // 3. LOMO IZQUIERDO / SPINE (X = -w / 2, normal local [-1, 0, 0])
    // -----------------------------------------------------------------------
    final (lnx, lny, lnz) = transformNormal(-1.0, 0.0, 0.0);
    if (lnz > _perspective * w / 2) {
      final double light = computeLighting(lnx, lny, lnz);
      visibleFaces.add(
        _FaceRender(
          (w / 2) * lnz,
          Transform(
            key: const ValueKey('3d_box_spine_left'),
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setTranslationRaw(-w / 2, 0.0, 0.0)
              ..rotateY(-math.pi / 2),
            child: _buildLeftSpine(colors, isDark, holoAlign, light),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // 4. BORDE DERECHO / OPENING SEAM (X = +w / 2, normal local [1, 0, 0])
    // -----------------------------------------------------------------------
    final (rnx, rny, rnz) = (-lnx, -lny, -lnz);
    if (rnz > _perspective * w / 2) {
      final double light = computeLighting(rnx, rny, rnz);
      visibleFaces.add(
        _FaceRender(
          (w / 2) * rnz,
          Transform(
            key: const ValueKey('3d_box_spine_right'),
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setTranslationRaw(w / 2, 0.0, 0.0)
              ..rotateY(math.pi / 2),
            child: _buildRightOpeningSeam(colors, isDark, holoAlign, light),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // 5. TAPA SUPERIOR (Y = -h / 2, normal local [0, -1, 0] hacia arriba)
    // -----------------------------------------------------------------------
    final (tnx, tny, tnz) = transformNormal(0.0, -1.0, 0.0);
    if (tnz > _perspective * h / 2) {
      final double light = computeLighting(tnx, tny, tnz);
      visibleFaces.add(
        _FaceRender(
          (h / 2) * tnz,
          Transform(
            key: const ValueKey('3d_box_cap_top'),
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setTranslationRaw(0.0, -h / 2, 0.0)
              ..rotateX(math.pi / 2),
            child: _buildCap(isTop: true, light: light),
          ),
        ),
      );
    }

    // -----------------------------------------------------------------------
    // 6. TAPA INFERIOR (Y = +h / 2, normal local [0, 1, 0] hacia abajo)
    // -----------------------------------------------------------------------
    final (dnx, dny, dnz) = (-tnx, -tny, -tnz);
    if (dnz > _perspective * h / 2) {
      final double light = computeLighting(dnx, dny, dnz);
      visibleFaces.add(
        _FaceRender(
          (h / 2) * dnz,
          Transform(
            key: const ValueKey('3d_box_cap_bottom'),
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setTranslationRaw(0.0, h / 2, 0.0)
              ..rotateX(-math.pi / 2),
            child: _buildCap(isTop: false, light: light),
          ),
        ),
      );
    }

    // Ordenar con el algoritmo del pintor (menor Z se pinta primero, mayor Z encima)
    visibleFaces.sort((a, b) => a.z.compareTo(b.z));

    // Escala de escenario estática e invariante para eliminar temblor / pulsación en rotación.
    // Se basa en la envolvente máxima posible sobre el eje vertical y horizontal.
    final double maxRadiusXZ = math.sqrt((w / 2) * (w / 2) + (d / 2) * (d / 2));
    final double maxProjX = maxRadiusXZ / (1.0 - _perspective * maxRadiusXZ);
    final double maxProjY = (h / 2) / (1.0 - _perspective * maxRadiusXZ);
    final double fitScale = math.min(
      1.0,
      math.min((w + 50) / (2 * maxProjX), (h + 36) / (2 * maxProjY)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: () {
              _isDragging = false;
              _angularVelocity = 0;
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // -------------------------------------------------------------
                // SOMBRA DINÁMICA SUSPENDIDA EN EL PISO
                // -------------------------------------------------------------
                Positioned(
                  bottom: 4,
                  child: Builder(
                    builder: (context) {
                      final double shadowScaleX = 0.85 + (cosY.abs() * 0.18);
                      final double shadowOpacity = (0.35 + (cosY.abs() * 0.16))
                          .clamp(0.18, 0.55);

                      return Transform.scale(
                        scaleX: shadowScaleX,
                        scaleY: 0.35,
                        child: Container(
                          width: widget.width * 1.18,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: shadowOpacity,
                                ),
                                blurRadius: 36,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: widget.card.accent.withValues(
                                  alpha: (shadowOpacity * 0.40).clamp(
                                    0.08,
                                    0.28,
                                  ),
                                ),
                                blurRadius: 44,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // -------------------------------------------------------------
                // CAJA FÍSICA GAMECUBE CON PERSPECTIVA Y GROSOR REAL (3D BOX)
                // -------------------------------------------------------------
                SizedBox(
                  width: widget.width + 60,
                  height: widget.height + 40,
                  child: Center(
                    child: Transform.scale(
                      scale: fitScale,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, -_perspective)
                          ..rotateX(_pitch)
                          ..rotateZ(_roll)
                          ..rotateY(_yaw),
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: visibleFaces
                                .map(
                                  (f) => Positioned.fill(
                                    child: Center(
                                      child: OverflowBox(
                                        minWidth: 0,
                                        minHeight: 0,
                                        maxWidth: math.max(w, d),
                                        maxHeight: math.max(h, d),
                                        child: f.widget,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Hint táctil de rotación con botones de volteo instantáneo
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => flipTo(showFront: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isFrontFacing
                        ? widget.card.accent.withValues(
                            alpha: isDark ? 0.18 : 0.12,
                          )
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : colors.surface),
                    border: Border.all(
                      color: isFrontFacing
                          ? widget.card.accent
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : colors.borderSecondaryColor),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rotate_left_rounded,
                        size: 14,
                        color: isFrontFacing
                            ? widget.card.accent
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'FRENTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isFrontFacing
                              ? widget.card.accent
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• Desliza 360° •',
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => flipTo(showFront: false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: !isFrontFacing
                        ? widget.card.accent.withValues(
                            alpha: isDark ? 0.18 : 0.12,
                          )
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : colors.surface),
                    border: Border.all(
                      color: !isFrontFacing
                          ? widget.card.accent
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : colors.borderSecondaryColor),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DORSO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: !isFrontFacing
                              ? widget.card.accent
                              : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.rotate_right_rounded,
                        size: 14,
                        color: !isFrontFacing
                            ? widget.card.accent
                            : colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // =========================================================================
  // CARA FRONTAL (PORTADA FÍSICA ESTILO GAMECUBE CASE CON BISEL METÁLICO)
  // =========================================================================
  Widget _buildFrontFace(
    NanoColors colors,
    bool isDark,
    Alignment holoAlign,
    double light,
  ) {
    final double shadowIntensity = ((1.0 - light) * 0.55).clamp(0.0, 0.55);
    final Color borderColor = _casingBorderColor(light);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF090D18),
        border: Border.all(color: borderColor, width: _borderWidth),
      ),
      child: Stack(
        children: [
          // Arte de fondo con gradientes oscuros obsidian
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF162032), Color(0xFF080C14)],
                ),
              ),
            ),
          ),

          // Halo central con el color de acento
          Positioned(
            top: 45,
            left: 16,
            right: 16,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.card.accent.withValues(alpha: 0.20),
                boxShadow: [
                  BoxShadow(
                    color: widget.card.accent.withValues(alpha: 0.38),
                    blurRadius: 46,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),

          // Marco interior con contenido gráfico escalable
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 184.0,
                  height: 275.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // BANNER SUPERIOR ESTILO GAMECUBE: "NANO RUNTIME"
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 12,
                              color: widget.card.accent,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'NANO RUNTIME',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.card.accent.withValues(alpha: 0.30),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'ARM64',
                                style: TextStyle(
                                  color: widget.card.accent,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),

                      // ILUSTRACIÓN CENTRAL / ICONO PRINCIPAL DEL MÓDULO
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                widget.card.accent.withValues(alpha: 0.32),
                                widget.card.accent.withValues(alpha: 0.05),
                              ],
                            ),
                            border: Border.all(
                              color: widget.card.accent.withValues(alpha: 0.75),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.card.accent.withValues(alpha: 0.45),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.card.icon,
                            size: 48,
                            color: widget.card.accent,
                          ),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // TÍTULO DEL MÓDULO ESTILO PORTADA
                      Text(
                        widget.card.eyebrow,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: widget.card.accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.card.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      // PIE DE PORTADA CON SELLO DE CALIDAD NANO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Badge tipo ESRB "DEV"
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              'DEV',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          // Sello Nano
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.card.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'NANO AI',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // BRILLO ESPECULAR PLÁSTICO CELLOPHANE / SHRINKWRAP GLOSS REALISTA
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1.2, -1.0),
                    end: const Alignment(1.2, 1.0),
                    stops: const [0.0, 0.28, 0.35, 0.42, 0.58, 0.65, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // REFLEJO HOLOGRÁFICO ESPECULAR (IRIDESCENT SHADER)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: holoAlign,
                    end: -holoAlign,
                    colors: [
                      Colors.transparent,
                      Colors.cyanAccent.withValues(alpha: 0.16),
                      Colors.purpleAccent.withValues(alpha: 0.18),
                      Colors.amberAccent.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.50, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // CAPA DE ILUMINACIÓN FÍSICA DIRECCIONAL 3D (SOMBRA ORGÁNICA)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: shadowIntensity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CARA TRASERA (DORSO CON ESPECIFICACIONES Y PINES DE CONTACTO METÁLICOS)
  // =========================================================================
  Widget _buildBackFace(
    NanoColors colors,
    bool isDark,
    Alignment holoAlign,
    double light,
  ) {
    final double shadowIntensity = ((1.0 - light) * 0.55).clamp(0.0, 0.55);
    final Color borderColor = _casingBorderColor(light);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        border: Border.all(color: borderColor, width: _borderWidth),
      ),
      child: Stack(
        children: [
          // Fondo
          Positioned.fill(
            child: Container(
              color: const Color(0xFF070B14),
            ),
          ),

          // Contenido técnico interior escalable
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 180.0,
                  height: 285.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado técnico
                      Row(
                        children: [
                          Icon(
                            Icons.settings_system_daydream_rounded,
                            size: 13,
                            color: widget.card.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'MANUAL TÉCNICO',
                            style: TextStyle(
                              color: widget.card.accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 10),

                      // Mini preview / consola box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: widget.card.accent.withValues(alpha: 0.40),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '# /system/bin/${widget.card.id} --ready\n'
                          'STATUS: ONLINE [LOCAL SOCKET]\n'
                          'ARCH: ARM64-V8A • SANDBOX: OK',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            height: 1.35,
                            color: widget.card.accent.withValues(alpha: 0.95),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        widget.card.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 9.5,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'CARACTERÍSTICAS:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      for (final h in widget.card.highlights.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2.5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: widget.card.accent,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  h,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Spacer(),

                      // Código de barras / pie físico
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MODEL: NANO-${widget.card.id.toUpperCase()}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 7.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'REV: 2026',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: widget.card.accent,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // PINES DE CONTACTO METÁLICOS / HARDWARE CARTRIDGE CONNECTOR EDGE
                      Container(
                        height: 9,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF030509),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                          border: Border.all(color: Colors.white10, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            10,
                            (index) => Container(
                              width: 3.0,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(0.8),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFFDF73),
                                    Color(0xFFB8860B),
                                    Color(0xFF7A5900),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Reflejo iridiscente trasero
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: -holoAlign,
                    end: holoAlign,
                    colors: [
                      Colors.transparent,
                      Colors.cyanAccent.withValues(alpha: 0.12),
                      Colors.purpleAccent.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.40, 0.60, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Sombra direccional 3D
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: shadowIntensity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // LOMO IZQUIERDO FÍSICO (SPINE CON BISEL, TÍTULO VERTICAL Y ESTRÍAS)
  // =========================================================================
  Widget _buildLeftSpine(
    NanoColors colors,
    bool isDark,
    Alignment holoAlign,
    double light,
  ) {
    final double shadowIntensity = ((1.0 - light) * 0.55).clamp(0.0, 0.55);
    final Color borderColor = _casingBorderColor(light);

    return Container(
      width: widget.depth,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0D1424), Color(0xFF1E2B42), Color(0xFF090D18)],
        ),
        border: Border.all(color: borderColor, width: _borderWidth),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Reflejo longitudinal especular en el lomo
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),
          ),

          // Estrías táctiles de agarre superiores
          Positioned(
            top: 14,
            child: Column(
              children: List.generate(
                4,
                (index) => Container(
                  width: widget.depth * 0.70,
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),

          // Estrías táctiles de agarre inferiores
          Positioned(
            bottom: 14,
            child: Column(
              children: List.generate(
                4,
                (index) => Container(
                  width: widget.depth * 0.70,
                  height: 1.5,
                  margin: const EdgeInsets.only(top: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),

          // Título del lomo estilo caja oficial
          Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.card.icon, size: 11, color: widget.card.accent),
                  const SizedBox(width: 8),
                  Text(
                    widget.card.title.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.card.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sombra direccional 3D
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: shadowIntensity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BORDE DERECHO FÍSICO (OPENING SEAM / BORDE DE CIERRE CON HENDIDURA)
  // =========================================================================
  Widget _buildRightOpeningSeam(
    NanoColors colors,
    bool isDark,
    Alignment holoAlign,
    double light,
  ) {
    final double shadowIntensity = ((1.0 - light) * 0.55).clamp(0.0, 0.55);
    final Color borderColor = _casingBorderColor(light);

    return Container(
      width: widget.depth,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF090D18),
        border: Border.all(color: borderColor, width: _borderWidth),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hendidura central de la carcasa de apertura
          Positioned(
            left: (widget.depth / 2) - 0.5,
            top: 0,
            bottom: 0,
            child: Container(
              width: 1.0,
              color: Colors.black.withValues(alpha: 0.85),
            ),
          ),

          // Muesca táctil de apertura en el centro (finger-grip recess)
          Center(
            child: Container(
              width: widget.depth * 0.65,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF050810),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Container(
                  width: 2,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.card.accent.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),

          // Pestañas de cierre superior e inferior
          Positioned(
            top: widget.height * 0.20,
            child: Container(
              width: widget.depth * 0.75,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF141D2D),
                borderRadius: BorderRadius.circular(1.5),
                border: Border.all(color: Colors.white12, width: 0.5),
              ),
            ),
          ),
          Positioned(
            bottom: widget.height * 0.20,
            child: Container(
              width: widget.depth * 0.75,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF141D2D),
                borderRadius: BorderRadius.circular(1.5),
                border: Border.all(color: Colors.white12, width: 0.5),
              ),
            ),
          ),

          // Sombra direccional 3D
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: shadowIntensity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAPAS SUPERIOR E INFERIOR (TOP / BOTTOM CAPS PARA SÓLIDO 3D TOTAL)
  // =========================================================================
  Widget _buildCap({required bool isTop, required double light}) {
    final double shadowIntensity = ((1.0 - light) * 0.55).clamp(0.0, 0.55);
    final Color borderColor = _casingBorderColor(light);

    return Container(
      width: widget.width,
      height: widget.depth,
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        border: Border.all(color: borderColor, width: _borderWidth),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ranura de unión estructural moldeada
          Center(
            child: Container(
              width: widget.width * 0.75,
              height: 1.5,
              decoration: BoxDecoration(
                color: const Color(0xFF162032),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),

          // Detalle de bisagra plástica en el extremo izquierdo
          Positioned(
            left: 8,
            child: Container(
              width: 12,
              height: widget.depth * 0.60,
              decoration: BoxDecoration(
                color: const Color(0xFF1B283D),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
            ),
          ),

          // Sombra direccional 3D
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: shadowIntensity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

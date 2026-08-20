import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Gestor y contenedor de Fragment Shaders con precarga, warm-up y fallback transparente.
class NanoShaderHost {
  static FragmentProgram? _program;
  static bool _isLoaded = false;
  static bool _hasError = false;

  static bool get isSupported => _isLoaded && _program != null && !_hasError;

  /// Precarga del shader en el arranque de la aplicación (warm-up).
  static Future<void> preload() async {
    if (_isLoaded) return;
    try {
      _program = await FragmentProgram.fromAsset('shaders/nano_optical.frag');
      _isLoaded = true;
      _hasError = false;
    } catch (e) {
      _hasError = true;
      _isLoaded = true;
      debugPrint('[NanoShaderHost] Fallback a renderizado por software/Canvas: $e');
    }
  }

  /// Crea una instancia del shader listo para pintar si está soportado.
  static FragmentShader? createShader() {
    if (!isSupported) return null;
    return _program?.fragmentShader();
  }
}

/// CustomPainter que ejecuta el shader óptico pasando uniforms en GPU.
class NanoOpticalShaderPainter extends CustomPainter {
  NanoOpticalShaderPainter({
    required this.shader,
    required this.time,
    required this.pointer,
    required this.colors,
    this.intensity = 1.0,
    this.refraction = 1.0,
    this.fresnel = 1.0,
  });

  final FragmentShader shader;
  final double time;
  final Offset pointer;
  final NanoColors colors;
  final double intensity;
  final double refraction;
  final double fresnel;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = colors is NanoDarkColors;

    // 0: uResolution (vec2)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2: uTime (float)
    shader.setFloat(2, time);

    // 3: uPointer (vec2)
    shader.setFloat(3, pointer.dx);
    shader.setFloat(4, pointer.dy);

    // 5: uIntensity (float)
    shader.setFloat(5, intensity);

    // 6: uRefraction (float)
    shader.setFloat(6, refraction);

    // 7: uFresnel (float)
    shader.setFloat(7, fresnel);

    // 8: uBaseColor (vec4)
    final base = isDark
        ? colors.backgroundPrimary.withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.78);
    shader.setFloat(8, base.r);
    shader.setFloat(9, base.g);
    shader.setFloat(10, base.b);
    shader.setFloat(11, base.a);

    // 12: uAccentCyan (vec4)
    final cyan = colors.accentCyan.withValues(alpha: 0.35);
    shader.setFloat(12, cyan.r);
    shader.setFloat(13, cyan.g);
    shader.setFloat(14, cyan.b);
    shader.setFloat(15, cyan.a);

    // 16: uAccentLavender (vec4)
    final lavender = colors.accentLavender.withValues(alpha: 0.30);
    shader.setFloat(16, lavender.r);
    shader.setFloat(17, lavender.g);
    shader.setFloat(18, lavender.b);
    shader.setFloat(19, lavender.a);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant NanoOpticalShaderPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.pointer != pointer ||
        oldDelegate.intensity != intensity ||
        oldDelegate.colors != colors;
  }
}

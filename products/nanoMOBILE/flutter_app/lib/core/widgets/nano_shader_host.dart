import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Gestor y contenedor de Fragment Shaders con precarga, warm-up y fallback transparente.
class NanoShaderHost {
  static FragmentProgram? _opticalProgram;
  static FragmentProgram? _fluidProgram;
  static FragmentProgram? _livingProgram;
  static bool _isLoaded = false;
  static bool _hasError = false;

  static bool get isSupported => _isLoaded && _opticalProgram != null && !_hasError;
  static bool get isFluidSupported => _isLoaded && _fluidProgram != null && !_hasError;
  static bool get isLivingSupported => _isLoaded && _livingProgram != null && !_hasError;

  /// Precarga de los shaders en el arranque de la aplicación (warm-up).
  static Future<void> preload() async {
    if (_isLoaded) return;
    try {
      final futures = await Future.wait([
        FragmentProgram.fromAsset('shaders/nano_optical.frag'),
        FragmentProgram.fromAsset('shaders/nano_fluid_background.frag'),
        FragmentProgram.fromAsset('shaders/nano_living_background.frag'),
      ]);
      _opticalProgram = futures[0];
      _fluidProgram = futures[1];
      _livingProgram = futures[2];
      _isLoaded = true;
      _hasError = false;
    } catch (e) {
      // Intenta cargar individualmente si uno falla
      try {
        _opticalProgram ??= await FragmentProgram.fromAsset('shaders/nano_optical.frag');
      } catch (_) {}
      try {
        _fluidProgram ??= await FragmentProgram.fromAsset('shaders/nano_fluid_background.frag');
      } catch (_) {}
      try {
        _livingProgram ??= await FragmentProgram.fromAsset('shaders/nano_living_background.frag');
      } catch (_) {}
      _isLoaded = true;
      _hasError = _opticalProgram == null && _fluidProgram == null && _livingProgram == null;
      debugPrint('[NanoShaderHost] Shader preload state: optical=${_opticalProgram != null}, living=${_livingProgram != null} ($e)');
    }
  }

  /// Crea una instancia del shader óptico listo para pintar si está soportado.
  static FragmentShader? createShader() {
    if (!isSupported) return null;
    return _opticalProgram?.fragmentShader();
  }

  /// Crea una instancia del shader de fondo de fluido cósmico en tiempo real.
  static FragmentShader? createFluidShader() {
    if (isLivingSupported) {
      return _livingProgram?.fragmentShader();
    }
    if (isFluidSupported) {
      return _fluidProgram?.fragmentShader();
    }
    return null;
  }

  /// Crea una instancia del shader de fondo Liquid Glass hiperrealista.
  static FragmentShader? createLivingShader() {
    if (!isLivingSupported) return createFluidShader();
    return _livingProgram?.fragmentShader();
  }
}

/// CustomPainter que ejecuta el shader Liquid Glass hiperrealista en GPU.
class NanoLivingBackgroundPainter extends CustomPainter {
  NanoLivingBackgroundPainter({
    required this.shader,
    required this.time,
    required this.pointer,
    required this.pointerVelocity,
    required this.pointerEnergy,
    required this.systemEnergy,
    required this.qualityLevel,
    required this.colors,
    this.accentPrimary,
    this.accentSecondary,
  });

  final FragmentShader shader;
  final double time;
  final Offset pointer;
  final Offset pointerVelocity;
  final double pointerEnergy;
  final double systemEnergy;
  final double qualityLevel;
  final NanoColors colors;
  final Color? accentPrimary;
  final Color? accentSecondary;

  @override
  void paint(Canvas canvas, Size size) {
    // 0: uResolution (vec2)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2: uTime (float)
    shader.setFloat(2, time);

    // 3: uPointer (vec2)
    shader.setFloat(3, pointer.dx);
    shader.setFloat(4, pointer.dy);

    // 5: uPointerVelocity (vec2)
    shader.setFloat(5, pointerVelocity.dx);
    shader.setFloat(6, pointerVelocity.dy);

    // 7: uPointerEnergy (float)
    shader.setFloat(7, pointerEnergy);

    // 8: uSystemEnergy (float)
    shader.setFloat(8, systemEnergy);

    // 9: uQualityLevel (float)
    shader.setFloat(9, qualityLevel);

    // 10: uAccentPrimary (vec4)
    final pAccent = accentPrimary ?? colors.accentCyan;
    shader.setFloat(10, pAccent.r);
    shader.setFloat(11, pAccent.g);
    shader.setFloat(12, pAccent.b);
    shader.setFloat(13, pAccent.a);

    // 14: uAccentSecondary (vec4)
    final sAccent = accentSecondary ?? colors.accentLavender;
    shader.setFloat(14, sAccent.r);
    shader.setFloat(15, sAccent.g);
    shader.setFloat(16, sAccent.b);
    shader.setFloat(17, sAccent.a);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant NanoLivingBackgroundPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.pointer != pointer ||
        oldDelegate.pointerVelocity != pointerVelocity ||
        oldDelegate.pointerEnergy != pointerEnergy ||
        oldDelegate.systemEnergy != systemEnergy ||
        oldDelegate.qualityLevel != qualityLevel ||
        oldDelegate.colors != colors ||
        oldDelegate.accentPrimary != accentPrimary ||
        oldDelegate.accentSecondary != accentSecondary;
  }
}

/// CustomPainter que ejecuta el shader de fluido cósmico / plasma en GPU.
class NanoFluidBackgroundPainter extends CustomPainter {
  NanoFluidBackgroundPainter({
    required this.shader,
    required this.time,
    required this.pointer,
    required this.pointerEnergy,
    required this.colors,
    this.intensity = 1.0,
    this.accentPrimary,
    this.accentSecondary,
  });

  final FragmentShader shader;
  final double time;
  final Offset pointer;
  final double pointerEnergy;
  final NanoColors colors;
  final double intensity;
  final Color? accentPrimary;
  final Color? accentSecondary;

  @override
  void paint(Canvas canvas, Size size) {
    // 0: uResolution (vec2)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2: uTime (float)
    shader.setFloat(2, time);

    // 3: uPointer (vec2)
    shader.setFloat(3, pointer.dx);
    shader.setFloat(4, pointer.dy);

    // 5: uPointerEnergy (float)
    shader.setFloat(5, pointerEnergy);

    // 6: uIntensity (float)
    shader.setFloat(6, intensity);

    // 7: uAccentPrimary (vec4)
    final pAccent = accentPrimary ?? colors.accentCyan;
    shader.setFloat(7, pAccent.r);
    shader.setFloat(8, pAccent.g);
    shader.setFloat(9, pAccent.b);
    shader.setFloat(10, pAccent.a);

    // 11: uAccentSecondary (vec4)
    final sAccent = accentSecondary ?? colors.accentLavender;
    shader.setFloat(11, sAccent.r);
    shader.setFloat(12, sAccent.g);
    shader.setFloat(13, sAccent.b);
    shader.setFloat(14, sAccent.a);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant NanoFluidBackgroundPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.pointer != pointer ||
        oldDelegate.pointerEnergy != pointerEnergy ||
        oldDelegate.intensity != intensity ||
        oldDelegate.colors != colors ||
        oldDelegate.accentPrimary != accentPrimary ||
        oldDelegate.accentSecondary != accentSecondary;
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

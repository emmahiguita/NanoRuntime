/// Componentes vectoriales para logos oficiales de familias de modelos (SRP & White Glass Aesthetic).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/nano_optical_surface.dart';

class ModelBrandLogo extends StatelessWidget {
  final String name;
  final double size;

  const ModelBrandLogo({super.key, required this.name, this.size = 40});

  static (Color, String) familyMetaFor(String name, NanoColors colors) {
    final lower = name.toLowerCase();
    if (lower.contains('gemma')) {
      return (const Color(0xFF4285F4), 'GEMMA');
    } else if (lower.contains('llama')) {
      return (const Color(0xFF0081FB), 'LLAMA');
    } else if (lower.contains('deepseek') || lower.contains('r1')) {
      return (const Color(0xFF336DF2), 'DEEPSEEK');
    } else if (lower.contains('phi')) {
      return (colors.accentMint, 'PHI');
    } else if (lower.contains('mistral')) {
      return (const Color(0xFFF97316), 'MISTRAL');
    } else if (lower.contains('qwen')) {
      return (colors.accentLavender, 'QWEN');
    }
    return (colors.accentSky, 'NEURAL');
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final lower = name.toLowerCase();
    final (tint, _) = familyMetaFor(name, colors);

    final Widget logo;
    if (lower.contains('gemma')) {
      logo = GemmaLogoWidget(size: size * 0.58);
    } else if (lower.contains('llama')) {
      logo = LlamaLogoWidget(size: size * 0.58);
    } else if (lower.contains('deepseek') || lower.contains('r1')) {
      logo = DeepSeekLogoWidget(size: size * 0.60);
    } else if (lower.contains('phi')) {
      logo = PhiLogoWidget(size: size * 0.58);
    } else if (lower.contains('mistral')) {
      logo = MistralLogoWidget(size: size * 0.58);
    } else if (lower.contains('qwen')) {
      logo = QwenLogoWidget(size: size * 0.58);
    } else {
      logo = Icon(Icons.memory_rounded, color: tint, size: size * 0.52);
    }

    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      blurSigma: 8,
      borderStrength: 0.60,
      reflectionStrength: 0.45,
      accent: tint,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: logo),
      ),
    );
  }
}

/// Logo Oficial Gemma (Google Sparkle 4-pointed gem con degradado)
class GemmaLogoWidget extends StatelessWidget {
  final double size;
  const GemmaLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: GemmaLogoPainter()),
    );
  }
}

class GemmaLogoPainter extends CustomPainter {
  const GemmaLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final path = Path()
      ..moveTo(cx, cy - r)
      ..cubicTo(
        cx + 0.15 * r,
        cy - 0.15 * r,
        cx + 0.15 * r,
        cy - 0.15 * r,
        cx + r,
        cy,
      )
      ..cubicTo(
        cx + 0.15 * r,
        cy + 0.15 * r,
        cx + 0.15 * r,
        cy + 0.15 * r,
        cx,
        cy + r,
      )
      ..cubicTo(
        cx - 0.15 * r,
        cy + 0.15 * r,
        cx - 0.15 * r,
        cy + 0.15 * r,
        cx - r,
        cy,
      )
      ..cubicTo(
        cx - 0.15 * r,
        cy - 0.15 * r,
        cx - 0.15 * r,
        cy - 0.15 * r,
        cx,
        cy - r,
      )
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4285F4), Color(0xFF9B72CF), Color(0xFFFBBC05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo Oficial Meta LLaMA (Infinity loop con gradiente azul Meta)
class LlamaLogoWidget extends StatelessWidget {
  final double size;
  const LlamaLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: LlamaLogoPainter()),
    );
  }
}

class LlamaLogoPainter extends CustomPainter {
  const LlamaLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(cx - 0.40 * w, cy)
      ..cubicTo(
        cx - 0.40 * w,
        cy - 0.35 * h,
        cx - 0.10 * w,
        cy - 0.35 * h,
        cx,
        cy,
      )
      ..cubicTo(
        cx + 0.10 * w,
        cy + 0.35 * h,
        cx + 0.40 * w,
        cy + 0.35 * h,
        cx + 0.40 * w,
        cy,
      )
      ..cubicTo(
        cx + 0.40 * w,
        cy - 0.35 * h,
        cx + 0.10 * w,
        cy - 0.35 * h,
        cx,
        cy,
      )
      ..cubicTo(
        cx - 0.10 * w,
        cy + 0.35 * h,
        cx - 0.40 * w,
        cy + 0.35 * h,
        cx - 0.40 * w,
        cy,
      );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF0081FB), Color(0xFF0064E0), Color(0xFF00C6FF)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo Oficial DeepSeek (Silueta anatómica exacta de la ballena azul #336DF2)
class DeepSeekLogoWidget extends StatelessWidget {
  final double size;
  const DeepSeekLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: DeepSeekLogoPainter()),
    );
  }
}

class DeepSeekLogoPainter extends CustomPainter {
  const DeepSeekLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Color oficial DeepSeek Blue (#336DF2)
    final bluePaint = Paint()
      ..color = const Color(0xFF336DF2)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final whaleBody = Path()
      ..moveTo(0.12 * w, 0.48 * h)
      ..cubicTo(0.12 * w, 0.28 * h, 0.28 * w, 0.14 * h, 0.52 * w, 0.14 * h)
      ..cubicTo(0.58 * w, 0.14 * h, 0.62 * w, 0.11 * h, 0.65 * w, 0.12 * h)
      ..cubicTo(0.64 * w, 0.16 * h, 0.66 * w, 0.20 * h, 0.72 * w, 0.24 * h)
      ..cubicTo(0.76 * w, 0.27 * h, 0.78 * w, 0.22 * h, 0.76 * w, 0.14 * h)
      ..cubicTo(0.76 * w, 0.10 * h, 0.82 * w, 0.12 * h, 0.84 * w, 0.18 * h)
      ..cubicTo(0.85 * w, 0.21 * h, 0.88 * w, 0.20 * h, 0.90 * w, 0.16 * h)
      ..cubicTo(0.95 * w, 0.13 * h, 0.97 * w, 0.18 * h, 0.94 * w, 0.24 * h)
      ..cubicTo(0.88 * w, 0.32 * h, 0.82 * w, 0.42 * h, 0.80 * w, 0.50 * h)
      ..cubicTo(0.78 * w, 0.58 * h, 0.72 * w, 0.66 * h, 0.70 * w, 0.68 * h)
      ..cubicTo(0.76 * w, 0.70 * h, 0.84 * w, 0.73 * h, 0.84 * w, 0.77 * h)
      ..cubicTo(0.80 * w, 0.80 * h, 0.74 * w, 0.78 * h, 0.68 * w, 0.74 * h)
      ..cubicTo(0.60 * w, 0.84 * h, 0.48 * w, 0.88 * h, 0.36 * w, 0.84 * h)
      ..cubicTo(0.20 * w, 0.78 * h, 0.10 * w, 0.64 * h, 0.12 * w, 0.48 * h)
      ..close();

    canvas.drawPath(whaleBody, bluePaint);

    // 2. Parche Blanco Ovalado del Vientre
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bellyPatch = Path()
      ..moveTo(0.18 * w, 0.46 * h)
      ..cubicTo(0.24 * w, 0.46 * h, 0.50 * w, 0.54 * h, 0.60 * w, 0.68 * h)
      ..cubicTo(0.56 * w, 0.73 * h, 0.48 * w, 0.74 * h, 0.42 * w, 0.68 * h)
      ..cubicTo(0.48 * w, 0.72 * h, 0.48 * w, 0.76 * h, 0.38 * w, 0.78 * h)
      ..cubicTo(0.24 * w, 0.76 * h, 0.16 * w, 0.64 * h, 0.18 * w, 0.46 * h)
      ..close();

    canvas.drawPath(bellyPatch, whitePaint);

    // 3. Parche Blanco del Ojo / Mancha ocular
    final eyePatch = Path()
      ..moveTo(0.62 * w, 0.48 * h)
      ..cubicTo(0.60 * w, 0.44 * h, 0.64 * w, 0.40 * h, 0.67 * w, 0.43 * h)
      ..cubicTo(0.70 * w, 0.46 * h, 0.71 * w, 0.52 * h, 0.66 * w, 0.54 * h)
      ..cubicTo(0.63 * w, 0.54 * h, 0.63 * w, 0.51 * h, 0.62 * w, 0.48 * h)
      ..close();

    canvas.drawPath(eyePatch, whitePaint);

    // 4. Pequeña pupila azul dentro de la mancha ocular
    final eyePupil = Path()
      ..moveTo(0.64 * w, 0.47 * h)
      ..cubicTo(0.63 * w, 0.45 * h, 0.65 * w, 0.43 * h, 0.66 * w, 0.44 * h)
      ..cubicTo(0.66 * w, 0.47 * h, 0.64 * w, 0.48 * h, 0.64 * w, 0.47 * h)
      ..close();

    canvas.drawPath(eyePupil, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo Oficial Phi (Símbolo griego Phi de Microsoft Research)
class PhiLogoWidget extends StatelessWidget {
  final double size;
  const PhiLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10B981), Color(0xFF0284C7)],
          ).createShader(bounds),
          child: Text(
            'Φ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: size * 0.90,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo Oficial Mistral (Viento / Llama de Mistral AI)
class MistralLogoWidget extends StatelessWidget {
  final double size;
  const MistralLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
          ).createShader(bounds),
          child: const Icon(Icons.air_rounded, size: 24),
        ),
      ),
    );
  }
}

/// Logo Oficial Qwen (Prisma isométrico 3D con caras blancas y biseles púrpura)
class QwenLogoWidget extends StatelessWidget {
  final double size;
  const QwenLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: QwenLogoPainter()),
    );
  }
}

class QwenLogoPainter extends CustomPainter {
  const QwenLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // 1. Triángulo central profundo
    final centerTriangle = Path()
      ..moveTo(cx, cy - 0.28 * r)
      ..lineTo(cx + 0.24 * r, cy + 0.14 * r)
      ..lineTo(cx - 0.24 * r, cy + 0.14 * r)
      ..close();

    final centerPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4C2CD8), Color(0xFF381CB8)],
          ).createShader(
            Rect.fromLTWH(cx - 0.3 * r, cy - 0.3 * r, 0.6 * r, 0.6 * r),
          );

    canvas.drawPath(centerTriangle, centerPaint);

    // 2. Tres brazos tridimensionales entrelazados
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(i * 2 * math.pi / 3);

      // A. Bisel lateral exterior derecho (Púrpura profundo)
      final sideOuter = Path()
        ..moveTo(-0.16 * r, -0.92 * r)
        ..lineTo(-0.72 * r, -0.60 * r)
        ..lineTo(-0.84 * r, -0.38 * r)
        ..lineTo(-0.52 * r, -0.06 * r)
        ..lineTo(-0.36 * r, -0.16 * r)
        ..lineTo(-0.48 * r, -0.36 * r)
        ..lineTo(-0.16 * r, -0.54 * r)
        ..close();

      final sideOuterPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5636E3), Color(0xFF3A1CBF)],
        ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));

      canvas.drawPath(sideOuter, sideOuterPaint);

      // B. Bisel frontal superior (Púrpura medio / brillante)
      final sideFront = Path()
        ..moveTo(-0.16 * r, -0.92 * r)
        ..lineTo(0.38 * r, -0.92 * r)
        ..lineTo(0.48 * r, -0.74 * r)
        ..lineTo(0.12 * r, -0.74 * r)
        ..lineTo(-0.16 * r, -0.54 * r)
        ..close();

      final sideFrontPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF7A5EFF), Color(0xFF5F40EB)],
        ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));

      canvas.drawPath(sideFront, sideFrontPaint);

      // C. Bisel de profundidad interior (Sombra intermedia)
      final innerBevel = Path()
        ..moveTo(0.12 * r, -0.74 * r)
        ..lineTo(0.48 * r, -0.74 * r)
        ..lineTo(0.66 * r, -0.42 * r)
        ..lineTo(0.50 * r, -0.32 * r)
        ..lineTo(0.36 * r, -0.54 * r)
        ..lineTo(0.12 * r, -0.54 * r)
        ..close();

      final innerBevelPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF9E8BFF), Color(0xFF6B4FF0)],
        ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));

      canvas.drawPath(innerBevel, innerBevelPaint);

      // D. Cara superior blanca brillante (Cinta isométrica en L)
      final topWhite = Path()
        ..moveTo(-0.16 * r, -0.54 * r)
        ..lineTo(0.36 * r, -0.54 * r)
        ..lineTo(0.50 * r, -0.32 * r)
        ..lineTo(0.66 * r, -0.04 * r)
        ..lineTo(0.48 * r, 0.08 * r)
        ..lineTo(0.36 * r, -0.16 * r)
        ..lineTo(-0.16 * r, -0.16 * r)
        ..close();

      final topWhitePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF9F7FF), Color(0xFFEBE5FF)],
        ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));

      canvas.drawPath(topWhite, topWhitePaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

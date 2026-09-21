/// Logos oficiales vectoriales de familias de modelos de IA (iOS Ultra-Crisp Aesthetic).
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class ModelBrandLogo extends StatelessWidget {
  final String name;
  final double size;

  const ModelBrandLogo({super.key, required this.name, this.size = 40});

  static (Color, String, List<Color>) familyMetaFor(String name, NanoColors colors) {
    final lower = name.toLowerCase();
    if (lower.contains('gemma')) {
      return (
        const Color(0xFF4285F4),
        'GEMMA',
        const [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF38BDF8)],
      );
    } else if (lower.contains('llama')) {
      return (
        const Color(0xFF0081FB),
        'LLAMA',
        const [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFF38BDF8)],
      );
    } else if (lower.contains('deepseek') || lower.contains('r1')) {
      return (
        const Color(0xFF336DF2),
        'DEEPSEEK',
        const [Color(0xFF1E1B4B), Color(0xFF3730A3), Color(0xFF6366F1)],
      );
    } else if (lower.contains('phi')) {
      return (
        const Color(0xFF00A4EF),
        'PHI',
        const [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF34D399)],
      );
    } else if (lower.contains('mistral') || lower.contains('mixtral')) {
      return (
        const Color(0xFFF97316),
        'MISTRAL',
        const [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFBBF24)],
      );
    } else if (lower.contains('qwen')) {
      return (
        const Color(0xFF8B5CF6),
        'QWEN',
        const [Color(0xFF3B0764), Color(0xFF6D28D9), Color(0xFFA855F7)],
      );
    } else if (lower.contains('smol') || lower.contains('hugging')) {
      return (
        const Color(0xFFF59E0B),
        'SMOLLM',
        const [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFFCD34D)],
      );
    } else if (lower.contains('whisper') || lower.contains('voice') || lower.contains('audio')) {
      return (
        const Color(0xFF06B6D4),
        'WHISPER',
        const [Color(0xFF083344), Color(0xFF0284C7), Color(0xFF38BDF8)],
      );
    } else if (lower.contains('moondream') || lower.contains('vision')) {
      return (
        const Color(0xFFEC4899),
        'VISION',
        const [Color(0xFF500724), Color(0xFFBE185D), Color(0xFFF472B6)],
      );
    }
    return (
      const Color(0xFF00E5FF),
      'GGUF',
      const [Color(0xFF083344), Color(0xFF0E7490), Color(0xFF06B6D4)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final lower = name.toLowerCase();
    final (tint, _, bgGrad) = familyMetaFor(name, colors);

    final Widget logo;
    final double iconSize = size * 0.58;

    if (lower.contains('whisper') || lower.contains('voice') || lower.contains('audio')) {
      logo = Icon(Icons.mic_rounded, size: iconSize, color: Colors.white);
    } else if (lower.contains('moondream') || lower.contains('vision')) {
      logo = Icon(Icons.camera_alt_rounded, size: iconSize, color: Colors.white);
    } else if (lower.contains('gemma')) {
      logo = GemmaLogoWidget(size: iconSize);
    } else if (lower.contains('llama')) {
      logo = LlamaLogoWidget(size: iconSize);
    } else if (lower.contains('deepseek') || lower.contains('r1')) {
      logo = DeepSeekLogoWidget(size: iconSize);
    } else if (lower.contains('phi')) {
      logo = PhiLogoWidget(size: iconSize);
    } else if (lower.contains('mistral') || lower.contains('mixtral')) {
      logo = MistralLogoWidget(size: iconSize);
    } else if (lower.contains('qwen')) {
      logo = QwenLogoWidget(size: iconSize);
    } else if (lower.contains('smol') || lower.contains('hugging')) {
      logo = SmolLMLogoWidget(size: iconSize);
    } else {
      logo = GgufChipLogoWidget(size: iconSize, tint: tint);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28), // iOS squircle
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgGrad[0].withValues(alpha: 0.85),
            bgGrad[1].withValues(alpha: 0.70),
          ],
        ),
        border: Border.all(
          color: tint.withValues(alpha: 0.40),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: logo),
    );
  }
}

/// Logo Oficial Google Gemma (4-pointed gem con degradado oficial)
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
        colors: [
          Color(0xFF60A5FA),
          Color(0xFFC084FC),
          Color(0xFFFDE047),
          Color(0xFFF87171),
        ],
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
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF38BDF8), Color(0xFF0081FB), Color(0xFF60A5FA)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo Oficial DeepSeek (Silueta anatómica exacta de la ballena azul)
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

    final bluePaint = Paint()
      ..color = const Color(0xFF60A5FA)
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

    final eyePatch = Path()
      ..moveTo(0.62 * w, 0.48 * h)
      ..cubicTo(0.60 * w, 0.44 * h, 0.64 * w, 0.40 * h, 0.67 * w, 0.43 * h)
      ..cubicTo(0.70 * w, 0.46 * h, 0.71 * w, 0.52 * h, 0.66 * w, 0.54 * h)
      ..cubicTo(0.63 * w, 0.54 * h, 0.63 * w, 0.51 * h, 0.62 * w, 0.48 * h)
      ..close();

    canvas.drawPath(eyePatch, whitePaint);
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
            colors: [Color(0xFF34D399), Color(0xFF38BDF8)],
          ).createShader(bounds),
          child: Text(
            'Φ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: size * 0.95,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo Oficial Mistral (Viento / Llama geométrica de Mistral AI)
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
            colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
          ).createShader(bounds),
          child: Icon(Icons.local_fire_department_rounded, size: size * 0.95),
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

    final centerTriangle = Path()
      ..moveTo(cx, cy - 0.28 * r)
      ..lineTo(cx + 0.24 * r, cy + 0.14 * r)
      ..lineTo(cx - 0.24 * r, cy + 0.14 * r)
      ..close();

    final centerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
      ).createShader(
        Rect.fromLTWH(cx - 0.3 * r, cy - 0.3 * r, 0.6 * r, 0.6 * r),
      );

    canvas.drawPath(centerTriangle, centerPaint);

    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(i * 2 * math.pi / 3);

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
          colors: [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
        ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));

      canvas.drawPath(sideOuter, sideOuterPaint);

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
          colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
        ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));

      canvas.drawPath(sideFront, sideFrontPaint);

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
          colors: [Color(0xFFFFFFFF), Color(0xFFF3E8FF)],
        ).createShader(Rect.fromLTWH(-r, -r, 2 * r, 2 * r));

      canvas.drawPath(topWhite, topWhitePaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo Oficial SmolLM / Hugging Face
class SmolLMLogoWidget extends StatelessWidget {
  final double size;
  const SmolLMLogoWidget({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.sentiment_very_satisfied_rounded,
      size: size * 0.95,
      color: const Color(0xFFFBBF24),
    );
  }
}

/// Logo para Modelos Locales GGUF / SD
class GgufChipLogoWidget extends StatelessWidget {
  final double size;
  final Color tint;
  const GgufChipLogoWidget({super.key, this.size = 26, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.developer_board_rounded,
      size: size * 0.95,
      color: tint,
    );
  }
}

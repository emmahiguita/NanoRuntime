// model_brand_logo.dart — Icono de marca en squircle estilo iOS para modelos neuronales.
// QUÉ HACE: Renderiza un avatar distintivo (Qwen, DeepSeek, Llama, Gemma, Phi, SD) con gradiente.
// CÓMO FUNCIONA: Detecta la familia por prefijo del nombre y dibuja un contenedor óptico compacto.
// POR QUÉ: Otorga identidad visual inmediata en el catálogo móvil respetando la cota de <200 líneas.
import 'package:flutter/material.dart';

class ModelBrandLogo extends StatelessWidget {
  final String name;
  final bool isDetected;
  final double size;

  const ModelBrandLogo({
    super.key,
    required this.name,
    this.isDetected = false,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final info = _resolveBrand(name, isDetected);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: info.gradient,
        ),
        borderRadius: BorderRadius.circular(size * 0.28), // Proporción squircle iOS
        boxShadow: [
          BoxShadow(
            color: info.gradient.first.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: info.icon != null
            ? Icon(info.icon, size: size * 0.52, color: Colors.white)
            : Text(
                info.letter,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: size * 0.44,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
      ),
    );
  }

  static _BrandInfo _resolveBrand(String rawName, bool isDetected) {
    if (isDetected) {
      return const _BrandInfo(
        gradient: [Color(0xFF059669), Color(0xFF10B981)],
        icon: Icons.sd_card_rounded,
        letter: 'SD',
      );
    }
    final lower = rawName.toLowerCase();
    if (lower.contains('deepseek')) {
      return const _BrandInfo(
        gradient: [Color(0xFF0284C7), Color(0xFF06B6D4)],
        letter: 'D',
      );
    }
    if (lower.contains('qwen')) {
      return const _BrandInfo(
        gradient: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        letter: 'Q',
      );
    }
    if (lower.contains('llama')) {
      return const _BrandInfo(
        gradient: [Color(0xFFEA580C), Color(0xFFF97316)],
        letter: '🦙',
      );
    }
    if (lower.contains('gemma')) {
      return const _BrandInfo(
        gradient: [Color(0xFF2563EB), Color(0xFF9333EA)],
        letter: 'G',
      );
    }
    if (lower.contains('phi')) {
      return const _BrandInfo(
        gradient: [Color(0xFF0D9488), Color(0xFF14B8A6)],
        letter: 'Φ',
      );
    }
    if (lower.contains('whisper')) {
      return const _BrandInfo(
        gradient: [Color(0xFF059669), Color(0xFF34D399)],
        icon: Icons.graphic_eq_rounded,
        letter: 'W',
      );
    }
    return const _BrandInfo(
      gradient: [Color(0xFF3B82F6), Color(0xFF6366F1)],
      icon: Icons.psychology_rounded,
      letter: 'AI',
    );
  }
}

class _BrandInfo {
  final List<Color> gradient;
  final IconData? icon;
  final String letter;

  const _BrandInfo({
    required this.gradient,
    this.icon,
    required this.letter,
  });
}

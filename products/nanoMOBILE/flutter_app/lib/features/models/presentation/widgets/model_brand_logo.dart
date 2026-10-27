// model_brand_logo.dart — Icono de marca en squircle estilo iOS para modelos neuronales.
// QUÉ HACE: usa logos originales de Qwen y Gemma; las demás familias usan avatares.
// CÓMO FUNCIONA: Detecta la familia por prefijo del nombre y dibuja un contenedor óptico compacto.
// POR QUÉ: Otorga identidad visual inmediata en el catálogo móvil respetando la cota de <200 líneas.
import 'package:flutter/material.dart';
import '../../../../core/widgets/qwen_brand_icon.dart';
import '../../../../core/widgets/gemma_brand_icon.dart';

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
    // Solo el catálogo identifica al proveedor: un archivo desconocido no hereda marca.
    // DeepSeek destilado de Qwen conserva la identidad de DeepSeek.
    final lower = name.toLowerCase();
    if (!isDetected && lower.startsWith('qwen')) {
      return QwenBrandIcon(size: size);
    }
    // El catálogo distingue Gemma y sus embeddings de archivos desconocidos.
    if (!isDetected &&
        (lower.startsWith('gemma') || lower.startsWith('embeddinggemma'))) {
      return GemmaBrandIcon(size: size);
    }
    final info = _resolveBrand(name, isDetected);
    // Los demás avatares son identificadores visuales, no logotipos oficiales.
    const foreground = Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: info.gradient,
        ),
        borderRadius: BorderRadius.circular(
          size * 0.28,
        ), // Proporción squircle iOS
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
            ? Icon(info.icon, size: size * 0.52, color: foreground)
            : Text(
                info.letter,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: size * 0.44,
                  fontWeight: FontWeight.w800,
                  color: foreground,
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
    if (lower.contains('llama')) {
      return const _BrandInfo(
        gradient: [Color(0xFFEA580C), Color(0xFFF97316)],
        letter: '🦙',
      );
    }
    if (lower.contains('phi')) {
      return const _BrandInfo(
        gradient: [Color(0xFF0D9488), Color(0xFF14B8A6)],
        letter: 'Φ',
      );
    }
    if (lower.contains('whisper') ||
        lower.contains('asr') ||
        lower.contains('audio8')) {
      return const _BrandInfo(
        gradient: [Color(0xFF059669), Color(0xFF34D399)],
        icon: Icons.graphic_eq_rounded,
        letter: 'W',
      );
    }
    if (lower.contains('granite')) {
      return const _BrandInfo(
        gradient: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        letter: 'IBM',
      );
    }
    if (lower.contains('paddle')) {
      return const _BrandInfo(
        gradient: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
        icon: Icons.document_scanner_rounded,
        letter: 'OCR',
      );
    }
    if (lower.contains('nemotron')) {
      return const _BrandInfo(
        gradient: [Color(0xFF16A34A), Color(0xFF84CC16)],
        icon: Icons.record_voice_over_rounded,
        letter: 'NV',
      );
    }
    if (lower.contains('agents-a1')) {
      return const _BrandInfo(
        gradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
        icon: Icons.smart_toy_rounded,
        letter: 'A1',
      );
    }
    if (lower.contains('spark')) {
      return const _BrandInfo(
        gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
        icon: Icons.bolt_rounded,
        letter: 'S',
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

  const _BrandInfo({required this.gradient, this.icon, required this.letter});
}

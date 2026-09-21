import 'package:flutter/material.dart';

/// Centralizador de estilos, colores de marca y favicons de sitios web.
/// 
/// - ¿Qué hace?: Provee colores de identidad e iconos/favicons de sitios web frecuentes.
/// - ¿Cómo funciona?: Inspecciona la URL o dominio y mapea a una identidad visual coherente.
/// - ¿Por qué?: Elimina código duplicado entre pestañas, tarjetas de ventana y carrusel 3D (DRY).
class BrowserSiteTheme {
  BrowserSiteTheme._();

  /// Retorna el color característico del sitio web o un azul eléctrico por defecto.
  static Color getSiteColor(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('deepseek') || lower.contains('deeksepp')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return const Color(0xFF10A37F);
    }
    if (lower.contains('youtube')) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains('facebook') || lower.contains('fb.com')) {
      return const Color(0xFF1877F2);
    }
    if (lower.contains('github')) {
      return const Color(0xFF8B949E);
    }
    if (lower.contains('wikipedia')) {
      return const Color(0xFF64748B);
    }
    return const Color(0xFF2563EB); // Google / Azul eléctrico por defecto
  }

  /// Retorna el icono de marca correspondiente al servicio web.
  static IconData getBrandIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('google')) return Icons.search_rounded;
    if (lower.contains('youtube')) return Icons.play_arrow_rounded;
    if (lower.contains('deepseek') || lower.contains('deeksepp')) {
      return Icons.auto_awesome_rounded;
    }
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return Icons.smart_toy_rounded;
    }
    if (lower.contains('github')) return Icons.code_rounded;
    if (lower.contains('facebook') || lower.contains('fb.com')) {
      return Icons.public_rounded;
    }
    return Icons.language_rounded;
  }

  /// Construye un favicon profesional y compacto para la cabecera o pestaña.
  static Widget buildFavicon(
    String url, {
    Color? siteColor,
    double size = 20,
    bool isLandscape = false,
  }) {
    final lower = url.toLowerCase();
    final effectiveColor = siteColor ?? getSiteColor(url);

    if (lower.contains('google')) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size * 0.6,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4285F4),
          ),
        ),
      );
    }
    if (lower.contains('deepseek') || lower.contains('deeksepp')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          color: const Color(0xFF7C3AED),
        ),
        alignment: Alignment.center,
        child: Text(
          'D',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          color: const Color(0xFF10A37F),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.smart_toy_rounded,
          size: size * 0.6,
          color: Colors.white,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveColor.withValues(alpha: 0.2),
      ),
      alignment: Alignment.center,
      child: Icon(
        getBrandIcon(url),
        size: size * 0.6,
        color: effectiveColor,
      ),
    );
  }
}

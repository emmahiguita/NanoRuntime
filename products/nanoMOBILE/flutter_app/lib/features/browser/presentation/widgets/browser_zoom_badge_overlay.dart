import 'package:flutter/material.dart';

/// Indicador flotante temporal con el porcentaje de zoom activo de la página web.
/// 
/// - ¿Qué hace?: Muestra una pastilla oscura elegante con el porcentaje de escala actual (ej. 125%).
/// - ¿Cómo funciona?: Se desvanece suavemente mediante `AnimatedOpacity` e `IgnorePointer`.
/// - ¿Por qué?: Proporciona feedback visual instantáneo sin interferir con la interacción web (UX).
class BrowserZoomBadgeOverlay extends StatelessWidget {
  final bool visible;
  final double scale;
  final Color accentColor;

  const BrowserZoomBadgeOverlay({
    super.key,
    required this.visible,
    required this.scale,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      right: 12,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEB091424),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in_rounded, size: 14, color: accentColor),
                const SizedBox(width: 5),
                Text(
                  '${(scale * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

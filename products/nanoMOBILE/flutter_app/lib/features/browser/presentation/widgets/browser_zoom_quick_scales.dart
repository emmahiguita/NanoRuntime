import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// QUÉ HACE:
/// Componente de selección rápida de escalas de zoom y reducción completa.
/// 
/// CÓMO FUNCIONA:
/// Muestra botones de porcentaje táctiles M3 Expressive
/// (5%, 10%, 20%, 30%, 50%, 75%, 100%, 150%, 200%, 300%) y botón de ajuste total.
/// 
/// POR QUÉ:
/// Permite reducción extrema libre por debajo de 30% y ajuste rápido (< 135 líneas).
class BrowserZoomQuickScales extends StatelessWidget {
  final double currentZoom;
  final ValueChanged<double> onSelectScale;
  final VoidCallback onFitToScreen;
  final VoidCallback onMobileAdapt;

  const BrowserZoomQuickScales({
    super.key,
    required this.currentZoom,
    required this.onSelectScale,
    required this.onFitToScreen,
    required this.onMobileAdapt,
  });

  static const List<double> supportedScales = [
    0.05, // 5% Reducción extrema
    0.10, // 10% Reducción total
    0.20, // 20% Panorama libre
    0.30, // 30% Reducido
    0.50, // 50% Mitad
    0.75, // 75% Compacto
    1.00, // 100% Normal
    1.50, // 150% Grande
    2.00, // 200% Detalle
    3.00, // 300% Máximo
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Escalas Rápidas de Reducción & Ampliación',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: supportedScales.map((scale) {
            final percent = (scale * 100).round();
            final isSelected = (currentZoom - scale).abs() < 0.03;
            final isUltraZoomOut = scale <= 0.30;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectScale(scale);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF007AFF))
                      : (isDark
                          ? (isUltraZoomOut
                              ? const Color(0x2238BDF8)
                              : Colors.white.withValues(alpha: 0.06))
                          : (isUltraZoomOut
                              ? const Color(0x18007AFF)
                              : Colors.black.withValues(alpha: 0.05))),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isUltraZoomOut
                            ? (isDark ? const Color(0x5538BDF8) : const Color(0x44007AFF))
                            : Colors.transparent),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onFitToScreen();
          },
          icon: const Icon(Icons.fullscreen_exit_rounded, size: 20),
          label: const Text(
            'Ajustar Todo a la Pantalla (Overview 100%)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

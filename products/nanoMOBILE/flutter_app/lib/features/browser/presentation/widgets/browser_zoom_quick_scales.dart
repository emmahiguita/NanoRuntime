import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// QUÉ HACE:
/// Componente de selección rápida de escalas de zoom y reducción completa.
/// 
/// CÓMO FUNCIONA:
/// Muestra una cuadrícula / fila de botones de porcentaje táctiles M3 Expressive
/// (10%, 25%, 35%, 50%, 75%, 100%, 150%, 200%) y botones de acción rápida
/// para ajuste total a pantalla y vista móvil.
/// 
/// POR QUÉ:
/// Cumple con Single Responsibility (SOLID) separando los selectores rápidos
/// del sheet modal principal, manteniendo el código en menos de 130 líneas.
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
    0.10, // 10% Reducción total
    0.25, // 25% Panorama amplio
    0.35, // 35% Vista general
    0.50, // 50% Mitad de escala
    0.75, // 75% Compacto
    1.00, // 100% Escala normal
    1.50, // 150% Lectura grande
    2.00, // 200% Doble tamaño
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título de la sección
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
        // Fila de chips de escala rápida envuelta en Wrap
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: supportedScales.map((scale) {
            final percent = (scale * 100).round();
            final isSelected = (currentZoom - scale).abs() < 0.04;
            final isUltraZoomOut = scale <= 0.35;

            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectScale(scale);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                      : (isDark
                          ? (isUltraZoomOut
                              ? const Color(0x2210B981)
                              : Colors.white.withValues(alpha: 0.06))
                          : (isUltraZoomOut
                              ? const Color(0x182563EB)
                              : Colors.black.withValues(alpha: 0.05))),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isUltraZoomOut
                            ? (isDark ? const Color(0x5510B981) : const Color(0x442563EB))
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
        // Botón destacado: Reducción Completa (Ajustar a Pantalla)
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

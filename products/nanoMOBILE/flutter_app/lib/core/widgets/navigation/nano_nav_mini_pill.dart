import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nano_destination.dart';
import 'nano_nav_tokens.dart';

/// Cápsula flotante ultra-compacta para la barra de navegación de Nano AI.
/// Aparece cuando la barra inferior se contrae o se auto-minimiza para que
/// el navegador o la vista activa aprovechen el 100% de la pantalla.
class NanoNavMiniPill extends StatelessWidget {
  final NanoDestination selected;
  final bool isLandscape;
  final Brightness brightness;
  final VoidCallback onExpand;

  const NanoNavMiniPill({
    super.key,
    required this.selected,
    required this.isLandscape,
    required this.brightness,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final activeColor = NanoNavTokens.activeAccent(brightness);

    return Semantics(
      button: true,
      label: 'Expandir barra de navegación Nano AI',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onExpand();
        },
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! < -4) {
            HapticFeedback.mediumImpact();
            onExpand();
          }
        },
        child: Container(
          height: isLandscape ? 22.0 : 25.0,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            color: isDark
                ? const Color(0xE607131D)
                : const Color(0xE6FFFFFF),
            border: Border.all(
              color: activeColor.withValues(alpha: isDark ? 0.40 : 0.28),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: activeColor.withValues(alpha: 0.16),
                blurRadius: 8,
                spreadRadius: -1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: isLandscape ? 15 : 17,
                    color: activeColor,
                  ),
                  const SizedBox(width: 5),
                  // Micro indicadores para cada uno de los 6 destinos
                  for (final d in NanoDestination.values) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 1.8),
                      width: d == selected ? (isLandscape ? 10.0 : 12.0) : 3.5,
                      height: 3.5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.0),
                        color: d == selected
                            ? activeColor
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.20)),
                        boxShadow: d == selected
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.65),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

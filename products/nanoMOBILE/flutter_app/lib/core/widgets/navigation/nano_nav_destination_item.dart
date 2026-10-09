// QUÉ: destino táctil del dock con lente Liquid Glass para la selección.
// CÓMO: integra blur, reflejo y escala dentro del mismo botón accesible.
// POR QUÉ: el activo se percibe como una lupa iOS, no como un botón separado.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

import 'nano_destination.dart';
import 'nano_glyph.dart';
import 'nano_nav_tokens.dart';

class NanoNavDestinationItem extends StatelessWidget {
  const NanoNavDestinationItem({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.brightness,
    required this.onSelect,
    this.compact = false,
  });

  final NanoDestination destination;
  final bool isSelected;
  final Brightness brightness;
  final ValueChanged<NanoDestination> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final muted = dark ? const Color(0xFFB4C0D0) : const Color(0xFF536276);
    final themeColors = Theme.of(
      context,
    ).extension<NanoThemeExtension>()?.colors;
    final active =
        themeColors?.accent ?? NanoNavTokens.activeAccent(brightness);
    final lensSize = compact ? 43.0 : 47.0;

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: SizedBox(
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: () {
              HapticFeedback.lightImpact();
              onSelect(destination);
            },
            radius: 25,
            containedInkWell: true,
            highlightShape: BoxShape.circle,
            child: Center(
              child: AnimatedScale(
                scale: isSelected ? 1.06 : 1,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? lensSize : 39,
                  height: isSelected ? lensSize : 39,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: active.withValues(
                                alpha: dark ? 0.36 : 0.25,
                              ),
                              blurRadius: 15,
                              spreadRadius: -3,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: dark ? 0.06 : 0.62,
                              ),
                              blurRadius: 3,
                              offset: const Offset(-1, -2),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: isSelected ? 18 : 0,
                        sigmaY: isSelected ? 18 : 0,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: dark
                                      ? [
                                          Colors.white.withValues(alpha: 0.18),
                                          active.withValues(alpha: 0.24),
                                          const Color(
                                            0xFF0B1220,
                                          ).withValues(alpha: 0.28),
                                        ]
                                      : [
                                          Colors.white.withValues(alpha: 0.82),
                                          active.withValues(alpha: 0.17),
                                          Colors.white.withValues(alpha: 0.42),
                                        ],
                                )
                              : null,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white.withValues(
                                    alpha: dark ? 0.34 : 0.78,
                                  )
                                : Colors.transparent,
                            width: 1.1,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isSelected)
                              Positioned(
                                top: 6,
                                left: 8,
                                child: Container(
                                  width: 13,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            Center(
                              child: NanoGlyph(
                                type: destination.glyph,
                                color: isSelected ? active : muted,
                                size: compact ? 19 : 21,
                                strokeWidth: isSelected ? 2.2 : 1.8,
                                glow: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

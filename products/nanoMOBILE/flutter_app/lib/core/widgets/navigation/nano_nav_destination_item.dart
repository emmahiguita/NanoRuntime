// nano_nav_destination_item.dart — Botón de destino del dock inferior.
// QUÉ HACE: Renderiza un único icono con selección visible y área táctil segura.
// CÓMO FUNCIONA: Usa InkResponse para diferenciar un toque de un gesto de arrastre.
// POR QUÉ: Evita cambios de pantalla accidentales al contraer la barra.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nanoai/core/theme/design_tokens.dart';
import 'nano_destination.dart';
import 'nano_glyph.dart';
import 'nano_nav_tokens.dart';

/// Icono accesible de uno de los cuatro destinos principales.
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
    final muted = brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final themeColors = Theme.of(context).extension<NanoThemeExtension>()?.colors;
    final active = themeColors?.accent ?? NanoNavTokens.activeAccent(brightness);

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: SizedBox(
        width: compact ? 50 : 56,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: () {
              HapticFeedback.lightImpact();
              onSelect(destination);
            },
            radius: 24,
            containedInkWell: true,
            highlightShape: BoxShape.rectangle,
            child: Center(
              child: AnimatedScale(
                scale: isSelected ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? (compact ? 44 : 48) : (compact ? 38 : 42),
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              active.withValues(alpha: 0.22),
                              active.withValues(alpha: 0.08),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? active.withValues(alpha: 0.65)
                          : Colors.transparent,
                      width: 1.1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: active.withValues(alpha: 0.32),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NanoGlyph(
                        type: destination.glyph,
                        color: isSelected ? active : muted,
                        size: compact ? 19 : 21,
                        strokeWidth: isSelected ? 2.2 : 1.8,
                        glow: isSelected,
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: isSelected ? 12 : 0,
                        height: 2.2,
                        decoration: BoxDecoration(
                          color: isSelected ? active : Colors.transparent,
                          borderRadius: BorderRadius.circular(1.5),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: active.withValues(alpha: 0.8),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
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
    );
  }
}

// QUÉ: carcasa Liquid Glass compartida por navegación y escritura.
// CÓMO: compone blur acotado, transparencia real y borde especular iOS.
// POR QUÉ: conserva todos los estados del dock sin una placa blanca opaca.
library;

import 'dart:ui';

import 'package:flutter/material.dart';

class NanoNavBarContainer extends StatelessWidget {
  const NanoNavBarContainer({
    super.key,
    required this.child,
    this.brightness,
    this.isFocused = false,
    this.isListening = false,
    this.isProcessing = false,
    this.compact = false,
    this.transparent = false,
    this.showHandle = true,
    this.radius = 26,
  });

  final Widget child;
  final Brightness? brightness;
  final bool isFocused;
  final bool isListening;
  final bool isProcessing;
  final bool compact;
  final bool transparent;
  final bool showHandle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final activeBrightness = brightness ?? Theme.of(context).brightness;
    final dark = activeBrightness == Brightness.dark;
    final radiusValue = BorderRadius.circular(radius);
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.72);
    final glassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [
              const Color(0xFF172033).withValues(alpha: 0.74),
              const Color(0xFF0B1220).withValues(alpha: 0.58),
            ]
          : [
              Colors.white.withValues(alpha: transparent ? 0.68 : 0.78),
              const Color(
                0xFFEAF2FF,
              ).withValues(alpha: transparent ? 0.34 : 0.48),
            ],
    );

    return Semantics(
      container: true,
      label: 'Navegación y escritura de Nano',
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radiusValue,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
                blurRadius: 24,
                spreadRadius: -7,
                offset: const Offset(0, 9),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: dark ? 0.03 : 0.52),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radiusValue,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: glassGradient,
                  borderRadius: radiusValue,
                  border: Border.all(color: borderColor, width: 0.9),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 7 : 11,
                      vertical: 3,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showHandle)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              width: 32,
                              height: 3,
                              decoration: BoxDecoration(
                                color: (dark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        child,
                      ],
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

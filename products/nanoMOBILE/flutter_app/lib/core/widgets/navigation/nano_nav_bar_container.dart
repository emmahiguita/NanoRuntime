// nano_nav_bar_container.dart — Carcasa Liquid Glass para la barra de navegación flotante.
//
// QUÉ HACE:
// Renderiza la cápsula de navegación flotante con textura Liquid Glass inspirada en iOS:
// fondo blanco ligeramente azulado translúcido, desenfoque óptico real y bordes finos.
//
// CÓMO FUNCIONA:
// - Aplica BackdropFilter con desenfoque simétrico (sigma 24).
// - Proyecta un gradiente blanco translúcido con matiz frío/azulado y sombras aéreas sutiles.
// - Conecta esquinas redondeadas continuas y borde especular de alta definición.
//
// POR QUÉ:
// Proporciona el acabado visual premium solicitado sin coste excesivo de GPU (< 110 líneas).
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
    this.showHandle = false,
    this.radius = 28,
  });

  final Widget child;
  final Brightness? brightness;
  final bool isFocused, isListening, isProcessing, compact, transparent, showHandle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = (brightness ?? scheme.brightness) == Brightness.dark;
    final active = isFocused || isListening || isProcessing;

    // Borde especular fino y discreto
    final borderCol = dark
        ? Colors.white.withValues(alpha: active ? 0.35 : 0.20)
        : Colors.white.withValues(alpha: active ? 0.90 : 0.75);

    // Fondo Liquid Glass: blanco translúcido ligeramente azulado en claro
    final bgColors = dark
        ? [
            const Color(0x991E2433),
            const Color(0x80131824),
          ]
        : [
            const Color(0xDFFFFFFF),
            const Color(0xC8EEF4FA),
          ];

    return Semantics(
      container: true,
      label: 'Barra de navegación flotante Nano AI',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.40)
                  : const Color(0x180F172A),
              blurRadius: 22,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 4 : 5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bgColors,
                ),
                border: Border.all(
                  color: borderCol,
                  width: active ? 1.0 : 0.85,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

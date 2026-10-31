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

    // QUÉ: Borde hairline translúcido adaptativo.
    // CÓMO: Usa outlineVariant suave en claro y blanco difuminado en oscuro.
    // POR QUÉ: Evita el halo o borde blanco grande al deslizar la barra hacia abajo.
    final borderCol = dark
        ? Colors.white.withValues(alpha: active ? 0.30 : 0.16)
        : scheme.outlineVariant.withValues(alpha: active ? 0.36 : 0.20);

    // QUÉ: Fondo Liquid Glass vinculado al tema activo de Nano.
    // CÓMO: Mezcla surfaceContainerHigh y surface con transparencia óptica.
    // POR QUÉ: Respeta el tema seleccionado y fusiona los elementos sin contrastes ásperos.
    final bgColors = dark
        ? [
            scheme.surfaceContainerHigh.withValues(alpha: 0.84),
            scheme.surface.withValues(alpha: 0.76),
          ]
        : [
            scheme.surface.withValues(alpha: 0.88),
            scheme.surfaceContainerLowest.withValues(alpha: 0.80),
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
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 4),
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
                  width: active ? 0.9 : 0.7,
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

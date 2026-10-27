// nano_metal_fx_container.dart — Contenedor de metal cepillado líquido (Metal FX).
// QUÉ HACE: Aplica textura metálica multicapa con bisel 3D, reflejo especular y micro-sombra a cualquier widget.
// CÓMO FUNCIONA: Combina gradientes angulares lineales, borde biselado con doble parada y brillo reflectante.
// POR QUÉ: Trae la textura visual de metal-fx de Libraries.dev a las tarjetas y cajas de modelos (< 130 líneas).
library;

import 'package:flutter/material.dart';
import 'nano_metal_fx_theme.dart';

class NanoMetalFxContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final NanoMetalFxPalette palette;
  final EdgeInsetsGeometry padding;
  final BorderSide? border;

  const NanoMetalFxContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.palette = NanoMetalFxPalette.titanium,
    this.padding = EdgeInsets.zero,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: palette.highlightColor.withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: -2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Capa 1: Superficie de metal cepillado
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.35, 0.70, 1.0],
                    colors: palette.surfaceColors,
                  ),
                ),
              ),
            ),

            // Capa 2: Reflejo especular diagonal cruzado (luz ambiental de estudio)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -1.0),
                      end: const Alignment(0.8, 1.0),
                      stops: const [0.0, 0.22, 0.45, 1.0],
                      colors: [
                        palette.highlightColor.withValues(alpha: 0.25),
                        Colors.transparent,
                        palette.highlightColor.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Capa 3: Borde biselado metálico
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(
                      color: border?.color ?? palette.borderColor.withValues(alpha: 0.35),
                      width: border?.width ?? 1.2,
                    ),
                  ),
                ),
              ),
            ),

            // Capa 4: Contenido del widget
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

// business_store_parallax_card.dart
//
// QUÉ HACE:
// Widget de presentación interactiva 2.5D Parallax para tarjetas de producto en la tienda.
// Combina imagen RGB, mapa de profundidad y el vector de inclinación en un Fragment Shader de GPU.
//
// CÓMO FUNCIONA:
// - Escucha cambios continuos de inclinación desde `DeviceTiltService`.
// - Captura gestos de arrastre táctil (Pan) para emuladores y pruebas de escritorio.
// - Dibuja el efecto usando un CustomPainter dedicado conectado a `FragmentShader`.
// - Si el shader o mapa de profundidad no están listos, muestra la imagen 2D con degradado elegante.
//
// POR QUÉ:
// Separa la vista pura del cálculo de profundidad (Clean Architecture / SRP) manteniéndose bajo 170 líneas.

library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'device_tilt_service.dart';

class BusinessStoreParallaxCard extends StatelessWidget {
  final ui.Image? rgbImage;
  final ui.Image? depthImage;
  final ui.FragmentShader? shader;
  final DeviceTiltService tiltService;
  final Widget fallbackWidget;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double strength;
  final double specular;

  const BusinessStoreParallaxCard({
    super.key,
    required this.rgbImage,
    required this.depthImage,
    required this.shader,
    required this.tiltService,
    required this.fallbackWidget,
    this.width = 160.0,
    this.height = 160.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16.0)),
    this.strength = 0.028,
    this.specular = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Fallback inmediato si no hay shader o faltan texturas de GPU
    final isShaderReady = shader != null && rgbImage != null && depthImage != null;

    if (!isShaderReady) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(width: width, height: height, child: fallbackWidget),
      );
    }

    // 2. Renderizado 2.5D acelerado por GPU con gestos interactivos
    return ClipRRect(
      borderRadius: borderRadius,
      child: GestureDetector(
        onPanUpdate: (details) {
          tiltService.updateFromTouchOffset(
            touchOffset: details.localPosition,
            containerSize: Size(width, height),
          );
        },
        onPanEnd: (_) => tiltService.releaseTouch(),
        onPanCancel: () => tiltService.releaseTouch(),
        child: SizedBox(
          width: width,
          height: height,
          child: ValueListenableBuilder<Offset>(
            valueListenable: tiltService.tiltListenable,
            builder: (context, tilt, _) {
              return CustomPaint(
                size: Size(width, height),
                painter: _ParallaxShaderPainter(
                  shader: shader!,
                  rgbImage: rgbImage!,
                  depthImage: depthImage!,
                  tilt: tilt,
                  strength: strength,
                  specular: specular,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ParallaxShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image rgbImage;
  final ui.Image depthImage;
  final Offset tilt;
  final double strength;
  final double specular;

  _ParallaxShaderPainter({
    required this.shader,
    required this.rgbImage,
    required this.depthImage,
    required this.tilt,
    required this.strength,
    required this.specular,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pasar uniformes al fragment shader:
    // uSize (vec2) -> setFloat(0, size.width), setFloat(1, size.height)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // uTilt (vec2) -> setFloat(2, tilt.dx), setFloat(3, tilt.dy)
    shader.setFloat(2, tilt.dx);
    shader.setFloat(3, tilt.dy);

    // uStrength (float), uSpecular (float)
    shader.setFloat(4, strength);
    shader.setFloat(5, specular);

    // Asignar samplers de texturas
    shader.setImageSampler(0, rgbImage);
    shader.setImageSampler(1, depthImage);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ParallaxShaderPainter oldDelegate) {
    return oldDelegate.tilt != tilt ||
        oldDelegate.rgbImage != rgbImage ||
        oldDelegate.depthImage != depthImage ||
        oldDelegate.strength != strength ||
        oldDelegate.specular != specular;
  }
}

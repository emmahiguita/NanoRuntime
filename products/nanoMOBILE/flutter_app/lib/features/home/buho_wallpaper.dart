import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// BUHO-WALLPAPER-01 — fondo rotativo de publicidad del Búho (Inicio).
///
/// - Dos juegos SEPARADOS por dimensión real de la imagen: verticales
///   (assets/buho/portrait/, 4) y horizontales (assets/buho/horizontal/,
///   11). La pantalla vertical JAMÁS toma una imagen apaisada y viceversa.
/// - El juego se elige por el ASPECTO de la pantalla (width > height =
///   horizontal), no por orientationOf: robusto ante rotación forzada.
/// - Imagen aleatoria al montar; rota cada 60 s dentro del juego activo.
/// - `BoxFit.cover`: llena la pantalla y encaja como parte de la app
///   (jamás franjas ni solapamiento con componentes: vive DETRÁS del
///   contenido, en la capa base del Stack).
/// - Scrim oscuro para legibilidad del contenido encima.
/// - Cambio directo de imagen (sin fade cruzado): evita decodificar dos
///   imágenes grandes a la vez en hardware barato (filosofía NanoRuntime).
class BuhoWallpaper extends StatefulWidget {
  const BuhoWallpaper({super.key, this.scrimOpacity});

  /// Opacidad del velo oscuro sobre la imagen (0 = sin velo).
  final double? scrimOpacity;

  @override
  State<BuhoWallpaper> createState() => _BuhoWallpaperState();
}

class _BuhoWallpaperState extends State<BuhoWallpaper> {
  static const int _portraitCount = 4;
  static const int _landscapeCount = 11;
  static const Duration _rotateEvery = Duration(seconds: 60);

  int _index = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _index = math.Random().nextInt(_portraitCount);
    _timer = Timer.periodic(_rotateEvery, (_) {
      if (!mounted) return;
      setState(() => _index = _index + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scrim = widget.scrimOpacity ?? (dark ? 0.45 : 0.30);
    // Aspecto REAL de la pantalla, no orientationOf: si el device quedó con
    // rotación forzada, el juego de imágenes siempre coincide con lo que se
    // ve. Ancho > alto = imagen horizontal.
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final count = landscape ? _landscapeCount : _portraitCount;
    final path = landscape
        ? 'assets/buho/horizontal/buho_h${_index % count + 1}.png'
        : 'assets/buho/portrait/buho_p${_index % count + 1}.png';

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          path,
          key: ValueKey<String>(path),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
        ColoredBox(color: Colors.black.withValues(alpha: scrim)),
      ],
    );
  }
}

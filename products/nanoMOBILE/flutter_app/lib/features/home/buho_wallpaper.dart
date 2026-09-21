import 'package:flutter/material.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';

/// BUHO-WALLPAPER-01 — Fondo cósmico del Búho (Shell y Navegación).
///
/// QUÉ HACE:
/// Renderiza la imagen de fondo oficial del Búho cósmico a pantalla completa
/// con un velo oscuro (scrim) adaptable para garantizar el contraste de texto.
///
/// CÓMO FUNCIONA:
/// 1. Detecta la relación de aspecto real de la pantalla (`size.width > size.height`).
/// 2. En vertical (portrait), utiliza la imagen única oficial canónica
///    (`assets/buho/portrait/buho_portrait_main.jpg`), sin rotaciones ni
///    desincronizaciones visuales.
/// 3. En horizontal (landscape), selecciona el asset panorámico según el tema.
/// 4. `BoxFit.cover`: ajusta la imagen de extremo a extremo sin deformación.
/// 5. Aislado en la capa de fondo detrás de todo el contenido interactivo.
///
/// POR QUÉ:
/// Al ser un `StatelessWidget`, se eliminan timers periódicos y procesos zombis
/// en segundo plano que consumían CPU y batería en reposo. Se garantiza
/// que el fondo sea 100% idéntico, continuo y estable en toda la aplicación.
class BuhoWallpaper extends StatelessWidget {
  const BuhoWallpaper({super.key, this.scrimOpacity});

  /// Ruta oficial de la imagen única vertical solicitada por el usuario.
  static const String portraitImagePath =
      'assets/buho/portrait/buho_portrait_main.jpg';

  /// Opacidad del velo oscuro sobre la imagen (0 = sin velo).
  final double? scrimOpacity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scrim = scrimOpacity ?? (dark ? 0.45 : 0.30);

    // Aspecto REAL de la pantalla, no orientationOf: si el dispositivo quedó con
    // rotación forzada, el juego de imágenes siempre coincide con lo que se ve.
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;

    final path = landscape
        ? (dark
            ? 'assets/buho/horizontal/buho_h_dark.jpg'
            : 'assets/buho/horizontal/buho_h_light.jpg')
        : portraitImagePath;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          path,
          key: ValueKey<String>(path),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            return const NanoAmbientBackground();
          },
        ),
        ColoredBox(color: Colors.black.withValues(alpha: scrim)),
      ],
    );
  }
}

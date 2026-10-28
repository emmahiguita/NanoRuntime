import 'package:flutter/services.dart';

/// Transporte de presentación del engine único. No ejecuta herramientas ni
/// contiene lógica de WhatsApp; solo aparta adornos al capturar evidencia.
abstract final class OwlSurfaceBridge {
  static const channel = MethodChannel('dev.nanoai/owl_surface');
  static Future<void> hideDecorations(bool hidden) async {
    try {
      await channel.invokeMethod<void>('captureVisibility', {'hidden': hidden});
    } on MissingPluginException {
      /* No hay esfera en esta plataforma/arranque. */
    }
  }
}

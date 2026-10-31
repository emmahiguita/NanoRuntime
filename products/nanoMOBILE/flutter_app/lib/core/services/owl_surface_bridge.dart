import 'package:flutter/services.dart';

/// Transporte de presentación del engine único. No ejecuta herramientas ni
/// contiene lógica de WhatsApp; solo aparta adornos al capturar evidencia.
abstract final class OwlSurfaceBridge {
  static const channel = MethodChannel('dev.nanoai/owl_surface');
  /// Oculta la esfera durante una tarea sin competir con capturas temporales.
  static Future<void> hideForExecution(bool hidden) async {
    try {
      await channel.invokeMethod<void>('executionVisibility', {'hidden': hidden});
    } on MissingPluginException {
      // No hay superficie nativa en esta plataforma.
    }
  }

  static Future<void> hideDecorations(bool hidden) async {
    try {
      await channel.invokeMethod<void>('captureVisibility', {'hidden': hidden});
    } on MissingPluginException {
      /* No hay esfera en esta plataforma/arranque. */
    }
  }
}

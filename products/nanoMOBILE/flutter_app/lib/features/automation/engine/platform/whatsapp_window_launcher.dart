import 'package:flutter/services.dart';

/// Adaptador de launch_app para una petición explícita de ventana WhatsApp.
/// El canal distingue solicitud y observación; no se infiere soporte por marca.
abstract final class WhatsAppWindowLauncher {
  static const _channel = MethodChannel('dev.nanoai/floating');

  /// Una sola apertura: el código nativo observa tamaño y nunca relanza.
  /// Sin soporte se informa y no se cambia silenciosamente a pantalla completa.
  static Future<String> open(String packageName) async {
    if (!const {'com.whatsapp', 'com.whatsapp.w4b'}.contains(packageName)) {
      return '[unsupported] Ventana flotante disponible aquí solo para WhatsApp instalado.';
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'openWhatsAppWindow',
        {'packageName': packageName},
      );
      final text =
          data?['text']?.toString() ?? 'No se recibió un resultado de ventana.';
      return switch (data?['state']) {
        'reduced_window_observed' => '[completed] $text',
        'launch_requested_unverified' => '[completedUnverified] $text',
        'busy' => '[busy] $text',
        'unsupported' => '[unsupported] $text',
        'cancelled' => '[timeoutOutcomeUnknown] $text',
        _ => '[error] $text',
      };
    } on PlatformException catch (error) {
      return '[error] ${error.message ?? 'No se pudo abrir WhatsApp.'}';
    } on MissingPluginException {
      return '[unsupported] Este entorno no tiene el canal Android de ventanas.';
    }
  }
}

import 'package:flutter/services.dart';

/// Conserva la causa nativa en vez de transformar cualquier fallo en «no abrió».
/// No convierte un permiso ausente en reintento automático.
class WhatsAppAutomationFailure implements Exception {
  const WhatsAppAutomationFailure(this.message);
  final String message;
  factory WhatsAppAutomationFailure.fromPlatform(
    PlatformException error,
  ) => WhatsAppAutomationFailure(switch (error.code) {
    'accessibility_unavailable' =>
      'Activa la accesibilidad de Nano en Android para escribir y enviar. No se inició el envío.',
    'automation_busy' =>
      'Otra tarea de WhatsApp está en curso. Espera su resultado antes de repetir.',
    'package_not_found' =>
      'WhatsApp no está instalado o no está disponible en este perfil.',
    _ => error.message ?? 'Android rechazó la operación (${error.code}).',
  });
  @override
  String toString() => message;
}

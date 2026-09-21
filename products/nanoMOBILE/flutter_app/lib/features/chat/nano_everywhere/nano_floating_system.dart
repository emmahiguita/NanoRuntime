// nano_floating_system.dart — Puente Flutter→Kotlin para el overlay del sistema.
// QUÉ: Expone hasPermission, requestPermission, show, hide y takePendingPrompt.
// CÓMO: MethodChannel 'dev.nanoai/floating' hacia NanoFloatingChannel.kt.
// POR QUÉ: El overlay nativo (tipo Gemini) solo puede gestionarse desde Kotlin;
//          este bridge es la única puerta para controlarlo desde Dart.
import 'package:flutter/services.dart';

class NanoFloatingSystem {
  const NanoFloatingSystem();
  static const _ch = MethodChannel('dev.nanoai/floating');

  /// Toma el prompt que el usuario escribió en el overlay nativo y lo borra.
  /// Retorna null si no hay prompt pendiente o el canal no está disponible.
  Future<String?> takePendingPrompt() async {
    try {
      return await _ch.invokeMethod<String>('takePendingPrompt');
    } on MissingPluginException {
      return null; // Canal no registrado (iOS / web).
    }
  }

  /// True si SYSTEM_ALERT_WINDOW está concedido — prerrequisito del overlay.
  Future<bool> get permitted async {
    try {
      return await _ch.invokeMethod<bool>('hasPermission') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre la pantalla de sistema para que el usuario otorgue el permiso.
  Future<void> requestPermission() async {
    try {
      await _ch.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // No disponible fuera de Android — ignorar silenciosamente.
    }
  }

  /// Muestra el búho flotante sobre otras apps. Retorna false si falta permiso.
  Future<bool> show() async {
    try {
      return await _ch.invokeMethod<bool>('show') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Oculta el overlay nativo y detiene NanoFloatingService.
  Future<void> hide() async {
    try {
      await _ch.invokeMethod<void>('hide');
    } on MissingPluginException {
      // Ignorar en plataformas sin soporte.
    }
  }
}

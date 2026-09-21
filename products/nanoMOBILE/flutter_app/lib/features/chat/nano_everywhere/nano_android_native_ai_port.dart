// nano_android_native_ai_port.dart — Handoff a apps nativas de IA vía Intent.
// QUÉ: Implementa NanoNativeAiPort usando el canal 'dev.nanoai/native_ai_apps'.
// CÓMO: Invoca el método Kotlin NanoNativeAiChannel.sharePrompt con package+prompt.
// POR QUÉ: La única forma segura de "abrir ChatGPT con contexto" sin acceder
//          a datos privados de otra app — usa Intent.ACTION_SEND estándar.
import 'package:flutter/services.dart';
import 'nano_ai_models.dart';

class NanoAndroidNativeAiPort implements NanoNativeAiPort {
  const NanoAndroidNativeAiPort();

  // Canal registrado en MainActivity → NanoNativeAiChannel.kt
  static const _channel = MethodChannel('dev.nanoai/native_ai_apps');

  @override
  Future<bool> sharePrompt(String androidPackage, String prompt) async {
    if (androidPackage.trim().isEmpty || prompt.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('sharePrompt', {
            'package': androidPackage,
            'prompt': prompt,
          }) ??
          false;
    } on PlatformException {
      // La app no está instalada o el sistema rechazó el intent.
      return false;
    } on MissingPluginException {
      // Canal no registrado en este build (ej: web/desktop).
      return false;
    }
  }
}

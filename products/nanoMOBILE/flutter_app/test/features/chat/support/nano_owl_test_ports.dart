import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/chat/nano_everywhere/nano_ai_models.dart';

/// Responde al control de acceso de la vista sin esperar un plugin Android.
/// Es un doble explícito: no concede ni prueba permisos reales del teléfono.
void installNanoAccessDouble() {
  const channel = MethodChannel('com.nanoai/share');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'isAccessibilityEnabled' ? true : null,
      );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}

/// Doble explícito: nunca abre aplicaciones ni comparte prompts.
class NanoTestNativeApps implements NanoNativeAiPort {
  @override
  Future<bool> sharePrompt(String package, String prompt) async => false;
}

/// Completer controlado por la prueba: no simula evidencia de WhatsApp.
/// Permite comprobar que ocultar la UI no cancela ni duplica una tarea.
class NanoTestActions implements NanoCancellableActionPort {
  final result = Completer<String>();
  int calls = 0;
  int cancellations = 0;

  @override
  Future<String> executeAuthorizedGoal(String goal) {
    calls++;
    return result.future;
  }

  @override
  void cancelActiveAction() => cancellations++;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nanoai/main.dart';
import 'package:nanoai/core/providers/app_providers.dart';

/// Verifica que con el motor llama.cpp APAGADO la app NO se bloquea:
///   - el health-check falla rápido (timeout 3s) -> connection=error
///   - un envío degrada HONESTO (mensaje de motor no responde) y
///     recupera con generating=false (la UI queda interactiva).
///
/// NO debe requerir motor levantado: corre con motor muerto a propósito.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('motor offline: degrade honrado, no se bloquea', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const NanoPlatformApp(),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Seleccionamos modelo para forzar health check real contra motor muerto.
    final chat = container.read(chatProvider.notifier);
    chat.selectModel('Qwen2.5-1.1B-Instruct');

    // Debe transicionar a error en pocos segundos (no colgar en loadingModel).
    final sw = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
      final st = container.read(chatProvider);
      if (st.connection == ModelConnectionState.error) break;
      if (st.connection == ModelConnectionState.ready) break; // motor vivo inesperado
    }
    sw.stop();
    final st = container.read(chatProvider);
    debugPrint('connection tras ${sw.elapsed.inSeconds}s = ${st.connection}');
    expect(st.connection, ModelConnectionState.error,
        reason: 'sin motor, /health debe fallar y llegar a error (sin colgar)');
    expect(sw.elapsed.inSeconds, lessThan(15),
        reason: 'la transición a error no puede cuelgarse más de 15s');

    // Envía una pregunta con motor offline. El notifier guard-a el envío
    // cuando connection != ready (NO intenta generar contra un motor muerto):
    // send() es no-op limpio, no puede colgarse ni emitir mensajes fantasma.
    chat.setInput('hola motor muerto');
    chat.send();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (!container.read(chatProvider).generating) break;
    }
    await tester.pumpAndSettle();
    final after = container.read(chatProvider);
    expect(after.generating, isFalse, reason: 'generating debe seguir false (no se lanza generación)');
    // Sin motor, no se debe haber emitido ningún mensaje nuevo (ni de IA ni de error):
    // el bloqueo de envío es lo correcto cuando connection != ready.
    expect(after.messages.where((m) => m.sender == MessageSender.user).length, 0,
        reason: 'send() con motor offline es no-op y no agrega mensajes del usuario');
    expect(after.messages.where((m) => m.sender == MessageSender.ai).length, 0,
        reason: 'no se emiten mensajes de IA inventados');
    expect(after.engineOnline, isFalse, reason: 'motor offline -> engineOnline=false');
    debugPrint('send offline: no-op en generación, sin mensajes, sin bloqueo');
  });
}
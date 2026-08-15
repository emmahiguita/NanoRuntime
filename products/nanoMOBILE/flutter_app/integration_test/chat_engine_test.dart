import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nanoai/main.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/features/chat/presentation/screens/chat_screen.dart';

// Prueba funcional end-to-end CORRIDA EN DISPOSITIVO:
// la app se conecta al motor llama.cpp REAL (127.0.0.1:8080) y verifica
// que el chat responde con inferencia real (texto + tps) y que el
// estado transiciona correctamente (noModel -> loadingModel -> ready).
//
// Requiere que el motor esté levantado en el device antes de correr:
//   adb shell "LD_LIBRARY_PATH=/data/local/tmp/llama_libs ./llama_libs/llama-server \
//     -m /data/local/tmp/qwen.gguf --host 127.0.0.1 --port 8080 --ctx-size 2048"
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('chat conecta al motor REAL y responde con lógica', (tester) async {
    // Container Riverpod compartido: acceso directo a state/notifier.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 1. Arranca la app
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const NanoPlatformApp(),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // 2. Navega al tab Chat. Abre el drawer y toca el tab Chat.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChatScreen).first);
    await tester.pump();

    // 3. Selecciona el primer modelo del catálogo real (Qwen2.5-1.1B)
    final chat = container.read(chatProvider.notifier);
    chat.selectModel('Qwen2.5-1.1B-Instruct');

    // 4. Espera transición a ready: health check HTTP real contra el motor.
    //    El timer de selección (600ms) + /health real. Esperamos hasta ready.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (container.read(chatProvider).connection == ModelConnectionState.ready ||
          container.read(chatProvider).connection == ModelConnectionState.error) {
        break;
      }
    }
    final st0 = container.read(chatProvider);
    expect(st0.activeModel, 'Qwen2.5-1.1B-Instruct');
    expect(st0.connection, ModelConnectionState.ready,
        reason: 'el motor llama.cpp debe estar levantado y responder /health');

    // 5. Preguntas de lógica reales contra el motor
    final preguntas = [
      'Cuanto es 12*8?',
      'Si tienes 10 pesos y gastas 3, cuantos te quedan?',
      'Escribe el primer programa en Dart que imprime Hola',
    ];
    for (final q in preguntas) {
      chat.send(q);
      await tester.pump(); // marca generating=true
      // Espera a que termine la generación (hasta ~2 min por pregunta).
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (!container.read(chatProvider).generating) break;
      }
      await tester.pumpAndSettle();

      final after = container.read(chatProvider);
      final msgs = after.messages;
      final ai = msgs.where((m) => m.sender == MessageSender.ai).last;
      expect(ai.text.trim().isNotEmpty, isTrue, reason: 'pregunta "$q" debe generar texto');
      expect(after.engineOnline, isTrue, reason: 'motor debe seguir online tras responder');
      if (ai.tps != null) {
        expect(ai.tps! > 0, isTrue, reason: 'tps real del motor debe ser > 0');
      }
      debugPrint('[$q] -> ${ai.text.trim().split('\n').first} :: tps=${ai.tps}');
    }
  });
}
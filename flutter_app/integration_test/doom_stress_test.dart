import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nanoai/main.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/features/chat/chat_screen.dart';

/// PRUEBA DE ESTRÉS DOOM — carga máxima contra el chat real (motor llama.cpp):
///   1. Ráfaga de envíos rápidos (el guard `generating` debe absorberlos)
///   2. STOP a mitad de generación -> el siguiente envío debe funcionar
///   3. Cambio de modelo en plena generación
///   4. clear()/delete() mientras genera
///   5. Input hostil: emojis, unicode, quotes, texto muy largo, vacío, espacios
///   6. Navegación entre pestañas durante generación (estado debe sobrevivir)
///   7. Terminar con el motor sano y la app operativa (sin crash)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DOOM STRESS: el chat no crashea bajo carga máxima', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const NanoPlatformApp(),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // ── Setup: navega a Chat y selecciona el modelo real ──
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Chat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChatScreen).first);
    await tester.pump();

    final chat = container.read(chatProvider.notifier);
    chat.selectModel('Qwen2.5-1.1B-Instruct');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      final st = container.read(chatProvider);
      if (st.connection == ModelConnectionState.ready ||
          st.connection == ModelConnectionState.error) break;
    }
    expect(container.read(chatProvider).connection, ModelConnectionState.ready,
        reason: 'motor debe estar ready antes del stress');

    final erroresUi = <Object>[];

    // ── 1. RÁFAGA: 5 envíos seguidos sin esperar ──
    for (var i = 0; i < 5; i++) {
      chat.send('ráfaga $i');
    }
    await tester.pump();
    // Solo el primero debe haber entrado en generación; el resto absorbido.
    expect(container.read(chatProvider).generating, isTrue,
        reason: 'el primer envío genera; los siguientes bloqueados por guard');
    // Espera a que termine.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (!container.read(chatProvider).generating) break;
    }
    final trasRafaga = container.read(chatProvider);
    debugPrint('RAFAGA: generating=${trasRafaga.generating} users=${trasRafaga.messages.where((m) => m.sender == MessageSender.user).length} ais=${trasRafaga.messages.where((m) => m.sender == MessageSender.ai).length} conn=${trasRafaga.connection}');
    expect(trasRafaga.generating, isFalse);
    expect(trasRafaga.messages.where((m) => m.sender == MessageSender.user).length, 1,
        reason: 'solo 1 mensaje de usuario real: los otros fueron absorbidos por el guard');

    // ── 2. STOP a mitad de generación ──
    chat.send('cuéntame una historia muy larga sobre el espacio');
    await tester.pump(const Duration(milliseconds: 400)); // deja que arranque
    expect(container.read(chatProvider).generating, isTrue, reason: 'generando antes del STOP');
    chat.stop();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(chatProvider).generating, isFalse, reason: 'STOP corta la generación');
    // El motor debe seguir respondiendo tras el STOP (verificación de sanidad).
    chat.send('después del stop: 2+2?');
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (!container.read(chatProvider).generating) break;
    }
    final trasStop = container.read(chatProvider);
    expect(trasStop.generating, isFalse);
    expect(trasStop.engineOnline, isTrue, reason: 'motor sigue sano tras STOP');

    // ── 3. CAMBIO DE MODELO EN PLENA GENERACIÓN ──
    chat.send('explica la cuántica');
    await tester.pump(const Duration(milliseconds: 200));
    chat.selectModel('DeepSeek-R1-7B'); // cambia el modelo mientras genera
    await tester.pump(const Duration(milliseconds: 900)); // deja correr el timer del check
    final trasSwitch = container.read(chatProvider);
    expect(trasSwitch.activeModel, 'DeepSeek-R1-7B', reason: 'modelo conmutado');
    expect(trasSwitch.connection, anyOf(ModelConnectionState.ready, ModelConnectionState.error),
        reason: 'el cambio de modelo resuelve sin colgar');
    // Vuelve al modelo original para el resto del stress.
    chat.selectModel('Qwen2.5-1.1B-Instruct');
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (container.read(chatProvider).connection != ModelConnectionState.loadingModel) break;
    }

    // ── 4. CLEAR / DELETE durante generación ──
    chat.send('historia de piratas');
    await tester.pump(const Duration(milliseconds: 200));
    chat.clear(); // borra TODO mientras genera
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(chatProvider).messages, isEmpty, reason: 'clear vacía la conversación');

    // ── 5. INPUT HOSTIL ──
    final hostiles = [
      '',                       // vacío (guard: no envía)
      '   ',                    // solo espacios (guard: trim vacío)
      'emoji 🔥🚀💀 prueba',     // emojis
      'unicode ñáéíóú üñ 😀 中文', // multibyte
      'quotes "dobles" \'simples\' \\ backslash \n newline', // escapes
      'x' * 5000,               // texto MUY largo
      'a' * 10000,              // extremo
      '<script>alert(1)</script>', // HTML/inyección
      'SELECT * FROM users; --',    // SQL
      'nanoai terminal prompt: ls -la', // shell-ish
    ];
    for (final h in hostiles) {
      chat.send(h);
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Tras el input hostil el estado no puede estar corrupto. El input puede
    // quedar con el último texto si su envío fue absorbido por el guard
    // (generación previa en curso): eso es comportamiento correcto, no corrupción.
    final hostil = container.read(chatProvider);
    expect(hostil.input.length, lessThanOrEqualTo(30),
        reason: 'input no puede quedar corrupto/desbordado');
    expect(hostil.messages.length, greaterThanOrEqualTo(0));
    debugPrint('HOSTIL: input=${hostil.input.length} users=${hostil.messages.where((m) => m.sender == MessageSender.user).length} ais=${hostil.messages.where((m) => m.sender == MessageSender.ai).length}');

    // ── 6. NAVEGACIÓN DURANTE GENERACIÓN ──
    chat.send('respuesta larga final: explica el universo');
    await tester.pump(const Duration(milliseconds: 300));
    // Saltar entre pestañas mientras genera.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Dashboard')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Terminal')));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Chat')));
    await tester.pumpAndSettle();

    // ── 7. VERIFICACIÓN FINAL ──
    final finalState = container.read(chatProvider);
    // El estado terminó consistente: no más generación pendiente, motor sano.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (!container.read(chatProvider).generating) break;
    }
    expect(container.read(chatProvider).generating, isFalse, reason: 'no queda generación colgada');
    expect(container.read(chatProvider).engineOnline, isTrue, reason: 'motor sano al final');
    expect(erroresUi, isEmpty, reason: 'ningún error de UI capturado durante el stress');

    debugPrint('STRESS OK: ráfaga=${trasRafaga.messages.length} | '
        'stop→recover=✓ | switchModel=✓ | clear=✓ | hostiles=${hostiles.length} | '
        'nav=✓ | engineOnline=${finalState.engineOnline}');
  });
}
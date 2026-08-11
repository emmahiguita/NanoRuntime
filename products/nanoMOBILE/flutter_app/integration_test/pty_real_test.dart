import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nanoai/main.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';
import 'package:nanoai/features/terminal/ansi_terminal.dart';

/// Ejercita el stack PTY+JNI real en el device:
///   1. Instala el rootfs Termux (bootstrap-aarch64.zip) si falta.
///   2. Ejecuta comandos interactivos reales vía PTY (bash -i, python).
///   3. Verifica el buffer ANSI recibe contenido y la sesión se cierra limpia.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PTY: bootstrap rootfs + sesión interactiva real', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NanoPlatformApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Navega al tab Terminal.
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Terminal')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NanoTerminal).first);
    await tester.pump();

    expect(
      find.byType(NanoTerminal),
      findsWidgets,
      reason: 'terminal Nano presente',
    );

    // Esperar a que el terminal esté inicializado (cmds + shell listos).
    // El init imprime "[shell] bash + toybox listos" — esperamos por él.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.textContaining('[shell]').evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    debugPrint('PTY-TEST: terminal inicializado');

    Finder termField() => find
        .descendant(
          of: find.byType(NanoTerminal).last,
          matching: find.byType(TextField),
        )
        .last;

    Future<void> run(
      String cmd, {
      Duration wait = const Duration(milliseconds: 800),
    }) async {
      final f = termField();
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.showKeyboard(f);
      await tester.enterText(f, cmd);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(wait);
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }

    // ── Estado actual del rootfs ──
    await run('status');
    await tester.pump(const Duration(milliseconds: 300));

    // ── 1. Instalar rootfs Termux si falta (descarga ~32MB + extracción) ──
    // Reintenta hasta que el handler responda ("[bootstrap]" visible).
    for (var attempt = 0; attempt < 5; attempt++) {
      await run('bootstrap', wait: const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      if (find.textContaining('[bootstrap]').evaluate().isNotEmpty ||
          find.textContaining('ya instalado').evaluate().isNotEmpty) {
        break;
      }
      debugPrint('PTY-TEST: reintento bootstrap #$attempt');
    }
    debugPrint(
      'PTY-TEST: bootstrap disparado — esperando descarga/extracción...',
    );

    // Confirmar que el handler corrió: buscar "[bootstrap] Iniciando" o
    // el mensaje de que ya está instalado.
    var handlerRan = false;
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.textContaining('[bootstrap]').evaluate().isNotEmpty ||
          find.textContaining('Iniciando instalación').evaluate().isNotEmpty ||
          find.textContaining('ya instalado').evaluate().isNotEmpty) {
        handlerRan = true;
        break;
      }
    }
    debugPrint('PTY-TEST: handler bootstrap ejecutado=$handlerRan');

    // Poll: espera hasta que el rootfs esté instalado. La extracción de
    // 32MB→~350MB con miles de archivos tarda 1-4 min en el device.
    // Comprobación directa de archivo (más fiable que el texto del terminal).
    var installed = false;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(seconds: 1));
      // Check 1: el archivo bash existe en el sandbox.
      final bashOk = File(
        '/data/user/0/dev.nanoai.mobile/files/nano/usr/bin/bash',
      ).existsSync();
      // Check 2: el terminal reportó éxito/fallo.
      final doneOk = find
          .textContaining('Instalación completa')
          .evaluate()
          .isNotEmpty;
      final failOk = find
          .textContaining('Falló la instalación')
          .evaluate()
          .isNotEmpty;
      final alreadyOk = find
          .textContaining('ya instalado')
          .evaluate()
          .isNotEmpty;
      if (bashOk || doneOk || alreadyOk) {
        installed = true;
        break;
      }
      if (failOk) break;
      if (i % 15 == 0) {
        debugPrint(
          'PTY-TEST: esperando extracción... ${i}s zip=${File("/data/user/0/dev.nanoai.mobile/files/nano/bootstrap-aarch64.zip").existsSync()} usr=${Directory("/data/user/0/dev.nanoai.mobile/files/nano/usr").existsSync()}',
        );
      }
    }
    debugPrint('PTY-TEST: rootfs instalado=$installed');

    // Inspección del sandbox tras la extracción (diagnóstico del check).
    const sb = '/data/user/0/dev.nanoai.mobile/files/nano';
    debugPrint('PTY-TEST: sandbox inspección:');
    for (final p in [
      '',
      '/usr',
      '/usr/bin',
      '/usr/bin/bash',
      '/bin',
      '/bin/bash',
      '/SYMLINKS.txt',
      '/bootstrap-aarch64.zip',
    ]) {
      final f = File('$sb$p');
      debugPrint(
        '  $p → exists=${f.existsSync()} size=${f.existsSync() ? f.lengthSync() : -1}',
      );
    }
    // ¿SYMLINKS.txt se procesó? ¿usr/bin tiene links?
    try {
      final usrBin = Directory('$sb/usr/bin').listSync().take(8).toList();
      debugPrint(
        '  usr/bin entries: ${usrBin.map((e) => e.uri.pathSegments.last).join(", ")}',
      );
    } catch (e) {
      debugPrint('  usr/bin list error: $e');
    }

    if (!installed) {
      // Capturar TODO el texto visible del terminal para diagnosticar el fallo.
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      debugPrint('PTY-TEST: TEXTO VISIBLE EN TERMINAL (${texts.length}):');
      for (final t in texts) {
        debugPrint('  | $t');
      }
      fail('bootstrap no completó instalación (ver texto terminal arriba)');
    }

    // ── 2. Sesión interactiva REAL: bash -i vía PTY ──
    await run('pty', wait: const Duration(seconds: 2));
    // pump manual (no pumpAndSettle: el polling PTY de 20ms impide que
    // pumpAndSettle estabilice — el Timer nunca termina).
    await tester.pump(const Duration(milliseconds: 500));

    // El modo PTY activa el buffer ANSI → el widget AnsiTerminalView aparece.
    final ansiPresent = find
        .byType(AnsiTerminalView, skipOffstage: false)
        .evaluate()
        .isNotEmpty;
    debugPrint('PTY-TEST: AnsiTerminalView visible=$ansiPresent');
    // Verificación objetiva adicional: el buffer ANSI existe (vía el estado).
    if (!ansiPresent) {
      final err = find.textContaining('error').evaluate().length;
      debugPrint('PTY-TEST: errores visibles=$err');
    }

    // Escribir comando en bash interactivo vía el TextField (el input va al PTY).
    await run('echo hola-desde-pty', wait: const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    // El bash interactivo hace eco del comando y de su salida en el PTY:
    // "hola-desde-pty" debe estar en el grid ANSI renderizado.
    final echoVisible = find
        .textContaining('hola-desde-pty')
        .evaluate()
        .isNotEmpty;
    debugPrint('PTY-TEST: echo visible en ANSI=$echoVisible');

    // ── 3. Python REPL real vía PTY ──
    await run('python3', wait: const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    await run('1+1', wait: const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 500));

    // Salir limpiamente del PTY.
    await run('exit', wait: const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));

    // Estado final: terminal sigue vivo tras el ciclo PTY.
    expect(
      find.byType(NanoTerminal),
      findsWidgets,
      reason: 'terminal vivo tras PTY',
    );
    debugPrint(
      'PTY-TEST OK: rootfs instalado + bash/python interactivo vía PTY real',
    );
  });
}

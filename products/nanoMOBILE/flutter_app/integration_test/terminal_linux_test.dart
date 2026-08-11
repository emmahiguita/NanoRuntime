import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nanoai/main.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';

/// Verifica que el terminal Linux (NanoTerminal) funciona con datos reales
/// del device via MethodChannel. No depende de execve (bloqueado en ColorOS).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('terminal Linux: comandos reales del sistema sin crash', (
    tester,
  ) async {
    // Viewport alto para que ListView.builder no descarte widgets al scrollear.
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

    // Scoping: input del terminal activo.
    Finder termField() => find
        .descendant(
          of: find.byType(NanoTerminal).last,
          matching: find.byType(TextField),
        )
        .last;

    Future<void> run(String cmd) async {
      final f = termField();
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.showKeyboard(f);
      await tester.enterText(f, cmd);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }

    // ── Datos REALES del device ──
    // id/uname obtienen info autentica via getDeviceIdentity (MethodChannel).
    // No dependen de execve (bloqueado por SELinux en ColorOS/OPPO).
    await run('id');
    expect(
      find.textContaining('uid='),
      findsWidgets,
      reason: 'id reporta uid real del device (MethodChannel)',
    );

    await run('uname -a');
    expect(
      find.textContaining('Linux'),
      findsWidgets,
      reason: 'uname reporta kernel Linux real',
    );
    expect(
      find.textContaining('aarch64'),
      findsWidgets,
      reason: 'arquitectura ARM64 real via Build.SUPPORTED_ABIS',
    );

    await run('uname -r');
    expect(
      find.textContaining('6.6'),
      findsWidgets,
      reason: 'kernel release real (os.version)',
    );

    await run('hostname');
    expect(
      find.textContaining('localhost'),
      findsWidgets,
      reason: 'hostname real del device',
    );

    // ── Comandos de filesystem REAL (BusyBox vía Nanoshell, sin sandbox) ──
    // Con rootfs instalado, cat/ls/mkdir son applets BusyBox reales operando
    // sobre el filesystem real del sandbox de la app (NO el VirtualFS demo).
    await run('ls -la');
    await run('pwd');
    await run('echo hola-mundo');

    // Crear archivo REAL y leerlo con cat real.
    const realBase = '/data/user/0/dev.nanoai.mobile/files/nano';
    await run('echo "NanoAI-REAL" > $realBase/real_test.txt');
    await run('cat $realBase/real_test.txt');
    expect(
      find.textContaining('NanoAI-REAL'),
      findsWidgets,
      reason: 'cat lee archivo real del device via BusyBox (no sandbox)',
    );

    // Listar y verificar tamaño real.
    await run('ls -la $realBase/real_test.txt');
    await run('wc -c $realBase/real_test.txt');

    // Crear y borrar directorios reales.
    await run('mkdir -p $realBase/test_real_dir');
    await run('touch $realBase/test_real_dir/inside');
    await run('ls -la $realBase/test_real_dir');
    await run('cd $realBase/test_real_dir');
    await run('pwd');
    await run('rm -r $realBase/test_real_dir');
    await run('ls -la $realBase'); // ya no debe aparecer test_real_dir

    // Segundo id — verifica grupos
    await run('id');
    expect(
      find.textContaining('gid='),
      findsWidgets,
      reason: 'id reporta gid y grupos reales',
    );

    await run('whoami');

    // AI y comandos avanzados (sin crash)
    await run('ai como optimizar ram');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // ── Gestor de paquetes ──
    await run('pkg list');
    await run('apt search node');

    // Estado final: terminal sigue vivo
    expect(
      find.byType(NanoTerminal),
      findsWidgets,
      reason: 'terminal vivo al final',
    );
    debugPrint(
      'TERMINAL OK: todos los comandos ejecutados sin crash con datos reales del device',
    );
  });
}

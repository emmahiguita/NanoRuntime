import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nanoai/core/services/terminal_dependencies.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/desktop/presentation/screens/desktop_launch_screen.dart';
import 'package:nanoai/features/desktop/presentation/screens/vnc_screen.dart';
import 'package:nanoai/features/terminal/terminal_core.dart';

/// Pruebas REALES de la terminal mobile.
///
/// Sin mocks ni simuladores: se monta NanoTerminal con TerminalDependencies
/// inyectadas SIN servicios (shell/rootfs null) — modo offline honesto.
/// Los comandos dart:io (ls/cat/mkdir/cp/mv/rm/wc/grep/find/head/tail/...)
/// operan sobre el sandbox real (Directory.systemTemp/nano_real_root) y cada
/// aserción se verifica contra el FILESYSTEM REAL con dart:io, no contra la
/// salida de un simulador.
///
/// Los comandos que requieren rootfs/binarios reales deben imprimir un error
/// honesto ("rootfs no instalado", "no disponible") — NUNCA datos falsos.
void main() {
  final sandbox = '${Directory.systemTemp.path}/nano_real_root';
  final hasProc = Directory('/proc').existsSync();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Sandbox limpio por test: operaciones reales desde cero.
    final d = Directory(sandbox);
    if (d.existsSync()) d.deleteSync(recursive: true);
  });

  tearDown(() {
    final d = Directory(sandbox);
    if (d.existsSync()) d.deleteSync(recursive: true);
  });

  Future<void> pumpTerminal(WidgetTester tester) async {
    final deps = TerminalDependencies.forTest();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [NanoThemeExtension(colors: NanoDarkColors())],
        ),
        home: Scaffold(body: NanoTerminal(deps: deps)),
      ),
    );
    // initState imprime el banner y arranca _initShell/_fetchDeviceIdentity.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  Future<void> run(WidgetTester tester, String cmd) async {
    await tester.enterText(find.byType(TextField), cmd);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // El pipeline es síncrono para comandos dart:io; frames extra por si
    // hay operaciones asíncronas (source, script). Sin pumpAndSettle:
    // el cursor parpadeante del TextField enfocado nunca deja de agendar.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void write(String rel, String content) {
    final f = File('$sandbox/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  testWidgets('banner y estado OFFLINE honesto (sin "SIMULADO")', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);

    expect(find.byType(NanoTerminal), findsOneWidget);
    expect(
      find.textContaining('NanoTerminal'),
      findsWidgets,
      reason: 'banner de arranque presente',
    );
    expect(
      find.textContaining('OFFLINE (rootfs'),
      findsWidgets,
      reason: 'status bar indica modo offline real, no simulado',
    );
    expect(
      find.textContaining('SIMULADO'),
      findsNothing,
      reason: 'la capa de simulación fue eliminada',
    );
  });

  testWidgets('FS real: mkdir/touch/ls/cat/wc/grep/find/head/tail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);

    await run(tester, 'mkdir testdir');
    expect(
      Directory('$sandbox/testdir').existsSync(),
      isTrue,
      reason: 'mkdir creó un directorio REAL en disco',
    );

    write('testdir/data.txt', 'INFO boot\nERROR crash\nINFO done\n');

    await run(tester, 'touch testdir/hello.txt');
    expect(
      File('$sandbox/testdir/hello.txt').existsSync(),
      isTrue,
      reason: 'touch creó un archivo REAL en disco',
    );

    await run(tester, 'ls testdir');
    expect(
      find.textContaining('hello.txt'),
      findsWidgets,
      reason: 'ls lista la entrada real del directorio',
    );
    expect(find.textContaining('data.txt'), findsWidgets);

    await run(tester, 'cat testdir/data.txt');
    expect(
      find.textContaining('ERROR crash'),
      findsWidgets,
      reason: 'cat imprime el contenido real del archivo',
    );

    await run(tester, 'wc -l testdir/data.txt');
    expect(
      find.textContaining('3'),
      findsWidgets,
      reason: 'wc cuenta 3 líneas reales del archivo',
    );

    await run(tester, 'grep ERROR testdir/data.txt');
    expect(
      find.textContaining('ERROR crash'),
      findsWidgets,
      reason: 'grep filtra sobre contenido real',
    );
    await run(tester, 'grep -i error testdir/data.txt');
    expect(
      find.textContaining('ERROR crash'),
      findsWidgets,
      reason: 'grep -i hace match real sin distinción de mayúsculas',
    );

    await run(tester, 'find testdir');
    expect(
      find.textContaining('testdir/data.txt'),
      findsWidgets,
      reason: 'find recorre el árbol real',
    );

    await run(tester, 'head -n 1 testdir/data.txt');
    expect(
      find.textContaining('INFO boot'),
      findsWidgets,
      reason: 'head imprime la primera línea real',
    );
    await run(tester, 'tail -n 1 testdir/data.txt');
    expect(
      find.textContaining('INFO done'),
      findsWidgets,
      reason: 'tail imprime la última línea real',
    );
  });

  testWidgets('FS real: cp/mv/rm verificados contra disco', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);
    write('src.txt', 'contenido real');

    await run(tester, 'cp src.txt dst.txt');
    expect(
      File('$sandbox/dst.txt').existsSync(),
      isTrue,
      reason: 'cp copió el archivo REAL',
    );
    expect(File('$sandbox/dst.txt').readAsStringSync(), 'contenido real');

    await run(tester, 'mv dst.txt moved.txt');
    expect(
      File('$sandbox/dst.txt').existsSync(),
      isFalse,
      reason: 'mv movió: origen ya no existe',
    );
    expect(
      File('$sandbox/moved.txt').existsSync(),
      isTrue,
      reason: 'mv movió: destino existe',
    );

    await run(tester, 'rm src.txt');
    expect(
      File('$sandbox/src.txt').existsSync(),
      isFalse,
      reason: 'rm borró el archivo REAL',
    );

    await run(tester, 'mkdir dirx');
    await run(tester, 'rm -r dirx');
    expect(
      Directory('$sandbox/dirx').existsSync(),
      isFalse,
      reason: 'rm -r borró el directorio real',
    );
  });

  testWidgets('cd/pwd reales: el cwd real sigue al filesystem', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);

    await run(tester, 'mkdir sub');
    await run(tester, 'cd sub');
    await run(tester, 'touch inside-sub.txt');
    expect(
      File('$sandbox/sub/inside-sub.txt').existsSync(),
      isTrue,
      reason: 'cd real: touch escribe DENTRO de sub, no en el root',
    );
    expect(File('$sandbox/inside-sub.txt').existsSync(), isFalse);
    await run(tester, 'pwd');
    expect(
      find.textContaining('/sub'),
      findsWidgets,
      reason: 'pwd refleja el cwd real tras cd',
    );

    await run(tester, 'cd ..');
    await run(tester, 'touch at-root.txt');
    expect(
      File('$sandbox/at-root.txt').existsSync(),
      isTrue,
      reason: 'cd .. real: touch escribe de vuelta en el root',
    );
    expect(File('$sandbox/sub/at-root.txt').existsSync(), isFalse);
  });

  testWidgets('echo/expr/seq/basename/dirname: lógica real', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);

    await run(tester, 'echo hola-mundo');
    expect(find.textContaining('hola-mundo'), findsWidgets);

    await run(tester, 'expr 2 + 3');
    expect(
      find.textContaining('5'),
      findsWidgets,
      reason: 'expr evalúa aritmética real',
    );
    await run(tester, 'expr 7 * 6');
    expect(find.textContaining('42'), findsWidgets);

    await run(tester, 'seq 1 3');
    expect(find.textContaining('1'), findsWidgets);
    expect(find.textContaining('2'), findsWidgets);
    expect(find.textContaining('3'), findsWidgets);

    await run(tester, 'basename /a/b/c.txt');
    expect(find.textContaining('c.txt'), findsWidgets);
    await run(tester, 'dirname /a/b/c.txt');
    expect(find.textContaining('/a/b'), findsWidgets);
  });

  testWidgets('source real: ejecuta comandos del archivo', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);
    write(
      'script.sh',
      '# comentario\n\necho desde-script\nmkdir creado-por-source\n',
    );

    await run(tester, 'source script.sh');

    expect(
      find.textContaining('desde-script'),
      findsWidgets,
      reason: 'source ejecuta el echo REAL del script',
    );
    expect(
      Directory('$sandbox/creado-por-source').existsSync(),
      isTrue,
      reason: 'source ejecutó mkdir REAL del script en disco',
    );
  });

  testWidgets('tree/diff reales sobre el filesystem', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);
    write('a.txt', 'linea1\nlinea2');
    write('b.txt', 'linea1\nlinea2-cambiada');

    await run(tester, 'mkdir tree_dir');
    write('tree_dir/uno.txt', 'x');
    write('tree_dir/dos.txt', 'y');
    await run(tester, 'tree tree_dir');
    expect(find.textContaining('uno.txt'), findsWidgets);
    expect(
      find.textContaining('directorios'),
      findsWidgets,
      reason: 'tree resume el conteo real de archivos',
    );

    await run(tester, 'diff a.txt b.txt');
    expect(
      find.textContaining('linea2-cambiada'),
      findsWidgets,
      reason: 'diff muestra la línea real divergente',
    );
  });

  testWidgets('errores honestos sin rootfs (cero simulación)', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);

    await run(tester, 'ps');
    expect(
      find.textContaining('rootfs no instalado'),
      findsWidgets,
      reason: 'ps sin rootfs NO imprime procesos inventados',
    );
    expect(
      find.textContaining('nanortime-core'),
      findsNothing,
      reason: 'la lista de procesos simulada legacy fue eliminada',
    );

    await run(tester, 'id');
    expect(
      find.textContaining('uid=0'),
      findsNothing,
      reason: 'id no finge ser root',
    );
    expect(
      find.textContaining('no disponible'),
      findsWidgets,
      reason: 'id sin identity del device da error honesto',
    );

    await run(tester, 'chmod +x nada.txt');
    expect(
      find.textContaining('requiere rootfs'),
      findsWidgets,
      reason: 'chmod sin rootfs no dice "operación completada"',
    );

    await run(tester, 'plugin list');
    expect(
      find.textContaining('no hay gestor de plugins'),
      findsWidgets,
      reason: 'plugin ya no usa un registry simulado',
    );

    await run(tester, 'pkg install python');
    expect(
      find.textContaining('rootfs no instalado'),
      findsWidgets,
      reason: 'pkg sin rootfs NO simula una instalación',
    );

    await run(tester, 'comando-inexistente-xyz');
    expect(find.textContaining('comando no encontrado'), findsWidgets);
  });

  testWidgets('runtime managers offline: docker/kali/desktop sin crash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    // El comando `desktop` navega a /desktop (DesktopLaunchScreen orquesta
    // instalar → Xvnc → TCP probe → VncScreen). Sin GoRouter, context.push
    // crashearía — se monta el router de producción para el test.
    final deps = TerminalDependencies.forTest();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(body: NanoTerminal(deps: deps)),
        ),
        GoRoute(
          path: '/desktop',
          builder: (_, __) => const DesktopLaunchScreen(),
        ),
        GoRoute(path: '/desktop/vnc', builder: (_, __) => const VncScreen()),
      ],
    );
    // DesktopLaunchScreen es ConsumerStateful: requiere ProviderScope.
    // Sin overrides: los providers reales fallan a error honesto, no crash.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: ThemeData(
            extensions: [NanoThemeExtension(colors: NanoDarkColors())],
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // docker run con _docker null: NO debe crashear (bug .then sobre null).
    await run(tester, 'docker run alpine echo hola');
    expect(
      find.textContaining('runtime no disponible'),
      findsWidgets,
      reason: 'docker sin servicios da error honesto, no NoSuchMethodError',
    );

    await run(tester, 'docker ps');
    await run(tester, 'docker pull alpine');

    // kali sin instalado → error honesto.
    await run(tester, 'kali shell');
    expect(find.textContaining('kali: no instalado'), findsWidgets);

    await run(tester, 'kali run nmap -sV 127.0.0.1');
    expect(find.textContaining('kali: no instalado'), findsWidgets);

    // vncstop sin servidor → sin crash.
    await run(tester, 'vncstop');

    expect(
      find.byType(NanoTerminal),
      findsOneWidget,
      reason: 'terminal vivo tras comandos de runtime managers',
    );

    // desktop → navega al orquestador DesktopLaunchScreen (no crash).
    await run(tester, 'desktop');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(DesktopLaunchScreen),
      findsOneWidget,
      reason:
          'desktop navega a DesktopLaunchScreen (orquestador real, no simulador)',
    );

    // Desmontar el árbol para que dispose() cancele el AnimationController
    // del orquestador (pulse.repeat() dejaría un timer pendiente al final).
    await tester.pumpWidget(const SizedBox());
    // Expirar el timeout del probe TCP (800ms) que el orquestador dejó
    // agendado en _probePort — sin esto el test falla por timer pendiente.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('monitor offline: datos reales o error, nunca inventados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
    });

    await pumpTerminal(tester);

    await run(tester, 'free');
    if (hasProc) {
      expect(
        find.textContaining('Mem:'),
        findsWidgets,
        reason: 'free lee /proc/meminfo real en plataformas con /proc',
      );
    } else {
      expect(
        find.textContaining('memoria no disponible'),
        findsWidgets,
        reason: 'free sin /proc ni device identity: error honesto',
      );
    }

    await run(tester, 'df');
    expect(
      find.textContaining('almacenamiento no disponible'),
      findsWidgets,
      reason: 'df sin device identity: error honesto, no 128G falso',
    );

    await run(tester, 'dashboard');
    expect(find.textContaining('Rootfs: no instalado'), findsWidgets);

    // Comandos monitor sin crash: salida real o mensaje claro.
    await run(tester, 'vmstat');
    await run(tester, 'netstat');
    await run(tester, 'top');
    await run(tester, 'lsof');

    expect(
      find.byType(NanoTerminal),
      findsOneWidget,
      reason: 'terminal sigue vivo tras todos los comandos',
    );
  });
}

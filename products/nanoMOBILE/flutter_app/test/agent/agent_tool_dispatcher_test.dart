import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/platform/linux_tool_adapter.dart';

import 'fixtures.dart';

/// Tests del AgentToolDispatcher: comandos `@` deterministas y parseo
/// tolerante del protocolo JSON de tool-calling, con canal mockeado.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');
  const notificationsChannel = MethodChannel('com.nanoai/notifications');

  final methodCalls = <String>[];
  final tapCalls = <List<int>>[];
  final inputCalls = <String>[];
  final notificationReplies = <Map<dynamic, dynamic>>[];
  final launchedPackages = <String>[];
  var dumpProvider = () => snapshotAjustes();
  var focused = false;

  final dispatcher = AgentToolDispatcher(
    executor: NanoAgentExecutor(
      stability: const StabilityChecker(
        wait: Duration.zero,
        maxCenterDeltaPx: 24,
        maxSizeChangeRatio: 0.10,
      ),
    ),
    launchPackage: (packageName) async {
      launchedPackages.add(packageName);
      return true;
    },
  );

  Map<String, dynamic> ajustesFocused() {
    final raw = snapshotAjustes();
    ((raw['nodes'] as List)[5] as Map)['focused'] = focused;
    return raw;
  }

  setUp(() {
    methodCalls.clear();
    tapCalls.clear();
    inputCalls.clear();
    notificationReplies.clear();
    launchedPackages.clear();
    dumpProvider = () => snapshotAjustes();
    focused = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call.method);
          switch (call.method) {
            case 'dumpSnapshot':
              return dumpProvider();
            case 'tapAt':
              final args = call.arguments as Map;
              tapCalls.add([args['x'] as int, args['y'] as int]);
              return true;
            case 'inputText':
              inputCalls.add((call.arguments as Map)['text'] as String);
              return true;
            case 'globalAction':
              return true;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          switch (call.method) {
            case 'status':
              return {'accessGranted': true, 'connected': true};
            case 'list':
              return [
                {
                  'key': 'notification-key-1',
                  'package': 'com.example.chat',
                  'title': 'Ana',
                  'text': '¿Llegas pronto?',
                  'canReply': true,
                },
              ];
            case 'reply':
              notificationReplies.add(call.arguments as Map);
              return {'ok': true};
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  group('isToolCommand', () {
    test('detecta @ y no confunde @@ ni texto plano', () {
      expect(AgentToolDispatcher.isToolCommand('@tap text=Bluetooth'), isTrue);
      expect(AgentToolDispatcher.isToolCommand('  @pantalla '), isTrue);
      expect(AgentToolDispatcher.isToolCommand('@@literal'), isFalse);
      expect(AgentToolDispatcher.isToolCommand('hola @tap'), isFalse);
      expect(AgentToolDispatcher.isToolCommand(''), isFalse);
    });
  });

  group('comandos @', () {
    test('@pantalla → resumen con package y nodos visibles', () async {
      final r = await dispatcher.runCommand('@pantalla');
      expect(r, contains('Pantalla "com.android.settings" · 7 nodos'));
      expect(r, contains('3 Ajustes @(540,180)'));
    });

    test('@resolver → top con criterios', () async {
      final r = await dispatcher.runCommand('@resolver text=Bluetooth');
      expect(r, contains('Resuelto: "Bluetooth" (75 pts)'));
      expect(r, contains('75 pts [textExact:+75]'));
      expect(tapCalls, isEmpty);
    });

    test(
      '@tap → ok con coordenadas del centro y postcondición verificada',
      () async {
        // Tras el gesto real (tapCalls no vacío) la pantalla cambia — el
        // verifier debe confirmar el cambio de snapshot.
        dumpProvider = () =>
            tapCalls.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
        final r = await dispatcher.runCommand('@tap text=Bluetooth');
        // AgentLoop verificado: completa limpio (sin sufijo [verify:]) porque
        // la postcondición (cambio de snapshot) se satisfizo.
        expect(r, 'tap en "Bluetooth" @(540,340)');
        expect(tapCalls, [
          [540, 340],
        ]);
        expect(methodCalls, isNot(contains('tapOnText')));
      },
    );

    test('@tap sin cambio de pantalla → gesto ok pero verify falla', () async {
      // dispatchGesture devolvió true pero la pantalla no cambió: NO se
      // reporta éxito limpio — el sufijo [verify:*] hace visible la sospecha.
      final r = await dispatcher.runCommand('@tap text=Bluetooth');
      expect(r, startsWith('tap en "Bluetooth" @(540,340) [verify:'));
      expect(tapCalls, hasLength(1));
    });

    test('@tap ambiguo → FAIL tipado sin gesto', () async {
      dumpProvider = () => snapshotDobleAceptar();
      final r = await dispatcher.runCommand('@tap text=Aceptar');
      expect(r, contains('[ambiguousTarget]'));
      expect(tapCalls, isEmpty);
    });

    test(
      '@escribir → ok, inputText exacto y texto visible verificado',
      () async {
        focused = true;
        // Antes del input el campo está sin foco/vacío; después del
        // inputText el texto "wifi" es visible → postcondición verificada.
        dumpProvider = () {
          final raw = ajustesFocused();
          if (inputCalls.isNotEmpty) {
            ((raw['nodes'] as List)[5] as Map)['text'] = inputCalls.last;
          }
          return raw;
        };
        final r = await dispatcher.runCommand('@escribir wifi | editable=true');
        expect(r, contains('"wifi" escrito en'));
        expect(inputCalls, ['wifi']);
      },
    );

    test('@back → globalAction con cambio de pantalla verificado', () async {
      dumpProvider = () => methodCalls.contains('globalAction')
          ? snapshotDobleAceptar()
          : snapshotAjustes();
      final r = await dispatcher.runCommand('@back');
      expect(r, 'Botón atrás ejecutado. · verificado');
      expect(methodCalls, contains('globalAction'));
    });

    test('@desconocido → error legible con lista', () async {
      final r = await dispatcher.runCommand('@volar');
      expect(r, contains('Comando desconocido "@volar"'));
      expect(r, contains('@tap'));
    });

    test('@tap selector inválido → error de parseo legible', () async {
      final r = await dispatcher.runCommand('@tap foo=bar');
      expect(r, contains('Selector inválido "foo=bar"'));
      expect(tapCalls, isEmpty);
    });

    test('@@ escapa y devuelve texto literal', () async {
      final r = await dispatcher.runCommand('@@ esto no es comando');
      expect(r, '@ esto no es comando');
    });
  });

  group('AgentToolProtocol.extractToolCall', () {
    test('JSON limpio de una línea', () {
      final call = AgentToolProtocol.extractToolCall(
        '{"tool":"tap","selector":"text=Bluetooth"}',
      );
      expect(call, isNotNull);
      expect(call!.tool, 'tap');
      expect(call.selector, 'text=Bluetooth');
    });

    test('JSON con prosa alrededor (fallo típico de GGUF)', () {
      final call = AgentToolProtocol.extractToolCall(
        'Voy a tocar el botón Bluetooth:\n'
        '{"tool":"tap","selector":"text=Bluetooth"}\n'
        'Eso debería funcionar.',
      );
      expect(call, isNotNull);
      expect(call!.tool, 'tap');
      expect(call.selector, 'text=Bluetooth');
    });

    test('JSON en bloque markdown', () {
      final call = AgentToolProtocol.extractToolCall(
        '```json\n{"tool":"screen"}\n```',
      );
      expect(call, isNotNull);
      expect(call!.tool, 'screen');
    });

    test('write con text y selector', () {
      final call = AgentToolProtocol.extractToolCall(
        '{"tool":"write","selector":"editable=true","text":"wifi"}',
      );
      expect(call, isNotNull);
      expect(call!.tool, 'write');
      expect(call.selector, 'editable=true');
      expect(call.text, 'wifi');
    });

    test('reply_notification conserva key y texto', () {
      final call = AgentToolProtocol.extractToolCall(
        '{"tool":"reply_notification","key":"notification-key-1","text":"Sí"}',
      );
      expect(call, isNotNull);
      expect(call!.tool, 'reply_notification');
      expect(call.key, 'notification-key-1');
      expect(call.text, 'Sí');
    });

    test('respuesta normal de texto → null', () {
      expect(
        AgentToolProtocol.extractToolCall('No necesito herramientas.'),
        isNull,
      );
      expect(
        AgentToolProtocol.extractToolCall('Puedes abrir ajustes a mano.'),
        isNull,
      );
    });

    test('JSON truncado (sin llave final) → parseo por regex', () {
      final call = AgentToolProtocol.extractToolCall('{"tool":"back"');
      expect(call, isNotNull);
      expect(call!.tool, 'back');
    });

    test('expect del LLM: postcondiciones declaradas se conservan', () {
      final call = AgentToolProtocol.extractToolCall(
        '{"tool":"tap","selector":"text=Bluetooth",'
        '"expect":{"package":"com.android.settings","appear":"text=Bluetooth"}}',
      );
      expect(call, isNotNull);
      expect(call!.expect, isNotNull);
      expect(call.expect!['package'], 'com.android.settings');
      expect(call.expect!['appear'], 'text=Bluetooth');
    });
  });

  group('runTool (tool-calling LLM)', () {
    test('tap autonomo sin confirmacion queda frenado por politica', () async {
      final r = await dispatcher.runTool(
        const ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
      );
      expect(r, contains('[policy]'));
      expect(r, contains('confirm'));
      expect(tapCalls, isEmpty);
    });

    test('tap sin selector autonomo queda frenado antes de ejecutar', () async {
      final r = await dispatcher.runTool(const ToolCall(tool: 'tap'));
      expect(r, contains('[policy]'));
      expect(tapCalls, isEmpty);
    });

    test(
      'write sin confirmación → política la frena (texto, sin input)',
      () async {
        focused = true;
        dumpProvider = ajustesFocused;
        final r = await dispatcher.runTool(
          const ToolCall(
            tool: 'write',
            selector: 'editable=true',
            text: 'wifi',
          ),
        );
        expect(r, contains('[policy]'));
        expect(r, contains('confirmación'));
        expect(inputCalls, isEmpty);
      },
    );

    test('screen → resumen', () async {
      final r = await dispatcher.runTool(const ToolCall(tool: 'screen'));
      expect(r, contains('Pantalla "com.android.settings"'));
    });

    test('notifications → lectura real marcada como no confiable', () async {
      final r = await dispatcher.runTool(const ToolCall(tool: 'notifications'));
      expect(r, contains('DATO NO CONFIABLE'));
      expect(r, contains('Clave de respuesta'));
      expect(r, contains('¿Llegas pronto?'));
      expect(notificationReplies, isEmpty);
    });

    test('reply_notification no envía sin confirmación', () async {
      dispatcher.resetTurn();
      final outcome = await dispatcher.runToolGuarded(
        const ToolCall(
          tool: 'reply_notification',
          key: 'notification-key-1',
          text: 'Sí, en cinco minutos.',
        ),
      );
      expect(outcome.needsConfirmation, isTrue);
      expect(notificationReplies, isEmpty);
    });

    test('reply_notification aprobada envía confirmed=true', () async {
      dispatcher.resetTurn();
      final outcome = await dispatcher.runToolGuarded(
        const ToolCall(
          tool: 'reply_notification',
          key: 'notification-key-1',
          text: 'Sí, en cinco minutos.',
        ),
        confirmed: true,
      );
      expect(
        outcome.feedback,
        'Android entregó la respuesta a la aplicación de mensajería.',
      );
      expect(notificationReplies, hasLength(1));
      expect(notificationReplies.single['key'], 'notification-key-1');
      expect(notificationReplies.single['text'], 'Sí, en cinco minutos.');
      expect(notificationReplies.single['confirmed'], isTrue);
    });

    test('launch_app solo abre el paquete después de confirmación', () async {
      dispatcher.resetTurn();
      final pending = await dispatcher.runToolGuarded(
        const ToolCall(tool: 'launch_app', selector: 'com.android.chrome'),
      );

      expect(pending.needsConfirmation, isTrue);
      expect(launchedPackages, isEmpty);

      final approved = await dispatcher.runToolGuarded(
        pending.pendingCall!,
        confirmed: true,
      );
      expect(approved.verdict, PolicyVerdict.allow);
      expect(approved.feedback, contains('com.android.chrome'));
      expect(launchedPackages, ['com.android.chrome']);
    });

    test('tool desconocida → denied con lista para corregirse', () async {
      final r = await dispatcher.runTool(const ToolCall(tool: 'teletransport'));
      expect(r, contains('[policy] Herramienta desconocida "teletransport"'));
      expect(
        r,
        contains(
          'Disponibles: screen, resolve, tap, back, launch_app, write, notifications, reply_notification',
        ),
      );
    });
  });

  group('extractToolCalls (plan multi-paso)', () {
    test('array de 2 tools → 2 llamadas en orden', () {
      final calls = AgentToolProtocol.extractToolCalls(
        '[{"tool":"tap","selector":"text:Bluetooth"},{"tool":"back"}]',
      );
      expect(calls, hasLength(2));
      expect(calls[0].tool, 'tap');
      expect(calls[0].selector, 'text:Bluetooth');
      expect(calls[1].tool, 'back');
    });

    test('array con prosa alrededor → solo las llamadas', () {
      final calls = AgentToolProtocol.extractToolCalls(
        'Plan: [{"tool":"tap","selector":"text:Bluetooth"},'
        '{"tool":"write","selector":"editable=true","text":"hola"}]',
      );
      expect(calls, hasLength(2));
      expect(calls[1].tool, 'write');
      expect(calls[1].text, 'hola');
    });

    test('objeto único → lista de una (compat single)', () {
      final calls = AgentToolProtocol.extractToolCalls('{"tool":"screen"}');
      expect(calls, hasLength(1));
      expect(calls.single.tool, 'screen');
    });

    test('texto normal o JSON inválido → lista vacía', () {
      expect(AgentToolProtocol.extractToolCalls('Respuesta normal'), isEmpty);
      expect(AgentToolProtocol.extractToolCalls('[{"nope":1}]'), isEmpty);
      expect(AgentToolProtocol.extractToolCalls(''), isEmpty);
    });
  });

  group('runPlanGuarded (multi-step)', () {
    // runPlanGuarded no resetea el turno (presupuesto continuo del plan):
    // el caller real (chat send) resetea antes; aquí se resetea por test.
    setUp(() => dispatcher.resetTurn());

    test(
      'plan solo-lectura de 2 pasos verificado → completed numerado',
      () async {
        final outcome = await dispatcher.runPlanGuarded(const [
          ToolCall(tool: 'screen'),
          ToolCall(tool: 'resolve', selector: 'text=Bluetooth'),
        ]);
        expect(outcome.completed, isTrue);
        expect(outcome.steps, hasLength(2));
        expect(outcome.pauseIndex, isNull);
        expect(
          outcome.summary,
          contains('1/2 Pantalla "com.android.settings"'),
        );
        expect(outcome.summary, contains('2/2 Resuelto: "Bluetooth"'));
        expect(tapCalls, isEmpty);
      },
    );

    test('plan de acciones sensibles aprobado → completed', () async {
      // El mundo cambia con cada acción: tap → dobleAceptar; back → ajustes.
      dumpProvider = () {
        if (methodCalls.contains('globalAction')) return snapshotAjustes();
        if (tapCalls.isNotEmpty) return snapshotDobleAceptar();
        return snapshotAjustes();
      };
      final outcome = await dispatcher.runPlanGuarded(
        const [
          ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
          ToolCall(tool: 'back'),
        ],
        confirmed: true, // usuario aprobó ejecutar el plan
      );
      expect(outcome.completed, isTrue);
      expect(outcome.steps, hasLength(2));
      expect(outcome.summary, contains('1/2 tap en "Bluetooth"'));
      expect(outcome.summary, contains('2/2 Botón atrás'));
      expect(tapCalls, hasLength(1));
    });

    test('respuesta RemoteInput aceptada completa el plan', () async {
      final outcome = await dispatcher.runPlanGuarded(const [
        ToolCall(
          tool: 'reply_notification',
          key: 'notification-key-1',
          text: 'Llego en cinco minutos.',
        ),
      ], confirmed: true);

      expect(outcome.completed, isTrue);
      expect(notificationReplies, hasLength(1));
      expect(outcome.summary, contains('Android entregó la respuesta'));
    });

    test('paso 2 denegado por política → plan aborta tras el paso 1', () async {
      dumpProvider = () =>
          tapCalls.isNotEmpty ? snapshotDobleAceptar() : snapshotAjustes();
      final outcome = await dispatcher.runPlanGuarded(const [
        ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
        ToolCall(tool: 'rm'), // fuera del registro
      ], confirmed: true);
      expect(outcome.completed, isFalse);
      expect(outcome.steps, hasLength(2));
      expect(outcome.summary, contains('1/2 tap en "Bluetooth"'));
      expect(outcome.summary, contains('[policy]'));
    });

    test('paso 2 falla (target inexistente) → plan aborta tipado', () async {
      // Solo el primer tap cambia la pantalla; el segundo no encuentra nada.
      dumpProvider = () =>
          tapCalls.length == 1 ? snapshotDobleAceptar() : snapshotAjustes();
      final outcome = await dispatcher.runPlanGuarded(const [
        ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
        ToolCall(tool: 'tap', selector: 'text=Inexistente'),
      ], confirmed: true);
      expect(outcome.completed, isFalse);
      expect(outcome.steps, hasLength(2));
      expect(outcome.summary, contains('[notFound]'));
      expect(tapCalls, hasLength(1));
    });

    test(
      'plan sensible sin confirmar → pausa en paso 1 y reanuda completo',
      () async {
        dumpProvider = () {
          if (methodCalls.contains('globalAction')) return snapshotAjustes();
          if (tapCalls.isNotEmpty) return snapshotDobleAceptar();
          return snapshotAjustes();
        };
        // Flujo E2E real del chat: el LLM emite [tap, back] sin autorización.
        final paused = await dispatcher.runPlanGuarded(const [
          ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
          ToolCall(tool: 'back'),
        ]);
        expect(paused.completed, isFalse);
        expect(paused.pauseIndex, 0);
        expect(paused.pauseCall!.tool, 'tap');
        // Nada se ejecutó todavía.
        expect(tapCalls, isEmpty);

        // El usuario aprueba el plan → se reanuda COMPLETO y autorizado.
        final resumed = await dispatcher.runPlanGuarded(const [
          ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
          ToolCall(tool: 'back'),
        ], confirmed: true);
        expect(resumed.completed, isTrue);
        expect(resumed.steps, hasLength(2));
        expect(tapCalls, hasLength(1));
        expect(resumed.summary, contains('2/2 Botón atrás'));
      },
    );

    test('plan cíclico A→B→A→B → loopDetected antes de repetir', () async {
      // El mundo avanza con cada acción (tap → dobleAceptar, back → ajustes),
      // pero el plan del LLM cicla tap/back sin progreso: el detector aborta
      // en el 4º paso SIN ejecutar la acción repetida.
      dumpProvider = () {
        if (tapCalls.length >= 2) return snapshotDobleAceptar(); // tras 2º tap
        if (methodCalls.contains('globalAction')) return snapshotAjustes();
        if (tapCalls.isNotEmpty) return snapshotDobleAceptar();
        return snapshotAjustes();
      };
      final outcome = await dispatcher.runPlanGuarded(const [
        ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
        ToolCall(tool: 'back'),
        ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
        ToolCall(tool: 'back'),
      ], confirmed: true);
      expect(outcome.completed, isFalse);
      expect(outcome.summary, contains('[loopDetected]'));
      // El paso repetido (2º back) no se ejecutó: solo 1 back, pero los dos
      // taps legítimos (pasos 1 y 3) sí.
      expect(tapCalls, hasLength(2));
      expect(methodCalls.where((m) => m == 'globalAction'), hasLength(1));
    });

    test(
      'plan largo legítimo sin repetir acción → no falso positivo',
      () async {
        // Solo herramientas read contra el snapshot fijo de ajustes (Bluetooth
        // y Aceptar existen): acciones todas distintas, sin loop posible.
        final outcome = await dispatcher.runPlanGuarded(const [
          ToolCall(tool: 'screen'),
          ToolCall(tool: 'resolve', selector: 'text=Bluetooth'),
          ToolCall(tool: 'screen'),
          ToolCall(tool: 'resolve', selector: 'text=Aceptar'),
        ]);
        expect(outcome.completed, isTrue);
        expect(outcome.summary, isNot(contains('[loopDetected]')));
      },
    );

    test('operación Linux correcta no aborta el plan por su prefijo', () async {
      final linuxDispatcher = AgentToolDispatcher(
        linuxAdapter: LinuxToolAdapter(runner: _SuccessfulLinuxRunner()),
      );

      final outcome = await linuxDispatcher.runPlanGuarded(const [
        ToolCall(tool: 'linux.list', text: '/tmp'),
      ]);

      expect(outcome.completed, isTrue);
      expect(outcome.summary, contains('Linux linux.list'));
    });
  });
}

class _SuccessfulLinuxRunner implements LinuxCommandRunner {
  @override
  Future<LinuxCommandResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 20),
  }) async => const LinuxCommandResult(stdout: 'ok', duration: Duration.zero);
}

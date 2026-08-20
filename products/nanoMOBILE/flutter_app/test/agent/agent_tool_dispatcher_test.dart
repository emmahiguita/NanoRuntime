import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/agent/actionability_engine.dart';
import 'package:nanoai/core/agent/agent_executor.dart';
import 'package:nanoai/core/agent/agent_tool_dispatcher.dart';

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

    test('@tap → ok con coordenadas del centro y postcondición verificada',
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
    });

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

    test('@escribir → ok, inputText exacto y texto visible verificado',
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
    });

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
      expect(r, startsWith('[notifications untrusted_data=true]'));
      expect(r, contains('notification-key-1'));
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
      expect(outcome.feedback, '[notificationReply] Respuesta enviada.');
      expect(notificationReplies, hasLength(1));
      expect(notificationReplies.single['key'], 'notification-key-1');
      expect(notificationReplies.single['text'], 'Sí, en cinco minutos.');
      expect(notificationReplies.single['confirmed'], isTrue);
    });

    test('tool desconocida → denied con lista para corregirse', () async {
      final r = await dispatcher.runTool(const ToolCall(tool: 'teletransport'));
      expect(r, contains('[policy] Herramienta desconocida "teletransport"'));
      expect(
        r,
        contains(
          'Disponibles: screen, resolve, tap, back, write, notifications, reply_notification',
        ),
      );
    });
  });
}

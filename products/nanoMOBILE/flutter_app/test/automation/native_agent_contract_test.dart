import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');
  const notificationsChannel = MethodChannel('com.nanoai/notifications');
  final calls = <MethodCall>[];
  final notificationCalls = <MethodCall>[];

  setUp(() {
    calls.clear();
    notificationCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'dumpSnapshot' => <String, Object?>{
              'package': 'com.example',
              'nodes': <Object?>[],
              'windows': <Object?>[],
              'truncated': false,
            },
            'clickTarget' => <String, Object?>{
              'ok': true,
              'method': 'ACTION_CLICK',
              'code': 'OK',
            },
            _ => true,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          notificationCalls.add(call);
          return switch (call.method) {
            'list' => <Object?>[
              {'key': 'n-1', 'canReply': true},
            ],
            'reply' => <String, Object?>{
              'ok': true,
              'code': 'REMOTE_INPUT_ACCEPTED',
            },
            _ => <String, Object?>{},
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  test(
    'Dart y Kotlin comparten el contrato de snapshot y click ligado',
    () async {
      final api = NanoRuntimeApi.instance;

      final snapshot = await api.agentDumpSnapshot();
      final click = await api.agentClickTarget(
        packageName: 'com.example',
        resourceId: 'com.example:id/send',
        className: 'android.widget.Button',
        text: '',
        description: 'Enviar',
        bounds: const [900, 1800, 1040, 1960],
      );

      expect(snapshot?['package'], 'com.example');
      expect(click?['ok'], isTrue);
      expect(calls.map((call) => call.method), ['dumpSnapshot', 'clickTarget']);
      expect(calls.last.arguments, {
        'packageName': 'com.example',
        'resourceId': 'com.example:id/send',
        'className': 'android.widget.Button',
        'text': '',
        'description': 'Enviar',
        'bounds': [900, 1800, 1040, 1960],
      });
    },
  );

  test(
    'input, gesto, global y launch conservan nombres y argumentos',
    () async {
      final api = NanoRuntimeApi.instance;

      expect(
        await api.agentInputTextAtTarget(
          'hola',
          targetResourceId: 'com.example:id/composer',
          targetBounds: const [20, 1800, 880, 1960],
        ),
        isTrue,
      );
      expect(await api.agentSwipe(10, 20, 30, 40, durationMs: 350), isTrue);
      expect(await api.agentLongPressAt(50, 60, durationMs: 700), isTrue);
      expect(await api.agentGlobalAction('back'), isTrue);
      expect(await api.agentLaunchPackage('com.example'), isTrue);

      expect(calls.map((call) => call.method), [
        'inputText',
        'swipe',
        'longPressAt',
        'globalAction',
        'launchPackage',
      ]);
      expect(calls[0].arguments, {
        'text': 'hola',
        'targetResourceId': 'com.example:id/composer',
        'targetBounds': [20, 1800, 880, 1960],
      });
      expect(calls[1].arguments, {
        'x1': 10,
        'y1': 20,
        'x2': 30,
        'y2': 40,
        'durationMs': 350,
      });
      expect(calls[2].arguments, {'x': 50, 'y': 60, 'durationMs': 700});
      expect(calls[3].arguments, {'action': 'back'});
      expect(calls[4].arguments, {'packageName': 'com.example'});
    },
  );

  test(
    'la API heredada sin identidad no se confunde con input ligado',
    () async {
      await NanoRuntimeApi.instance.agentInputText('texto heredado');

      expect(calls.single.method, 'inputText');
      expect(calls.single.arguments, {'text': 'texto heredado'});
      // El handler Kotlin rechaza este mapa por no incluir targetBounds.
    },
  );

  test(
    'notificaciones y RemoteInput conservan contrato y confirmación',
    () async {
      final api = NanoRuntimeApi.instance;

      final notifications = await api.listActiveNotifications(limit: 250);
      final denied = await api.replyToNotification(
        key: 'n-1',
        text: 'hola',
        confirmed: false,
      );
      final accepted = await api.replyToNotification(
        key: 'n-1',
        text: 'hola',
        confirmed: true,
      );

      expect((notifications.single as Map)['key'], 'n-1');
      expect(denied['code'], 'CONFIRMATION_REQUIRED');
      expect(accepted['code'], 'REMOTE_INPUT_ACCEPTED');
      expect(notificationCalls.map((call) => call.method), ['list', 'reply']);
      expect(notificationCalls.first.arguments, {'limit': 100});
      expect(notificationCalls.last.arguments, {
        'key': 'n-1',
        'text': 'hola',
        'confirmed': true,
      });
    },
  );
}

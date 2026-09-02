import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/platform/nano_system_api.dart';
import 'package:nanoai/features/automation/engine/system/system_destination.dart';
import 'package:nanoai/features/automation/engine/system/system_intent_launcher.dart';

import '../agent/fixtures.dart';

class _FakeSystemIntentLauncher implements SystemIntentLauncher {
  final List<SystemDestination> opened = [];
  SystemIntentResult next = const SystemIntentResult.ok();

  @override
  Future<SystemIntentResult> open(SystemDestination destination) async {
    opened.add(destination);
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const agentChannel = MethodChannel('com.nanoai/agent');
  const systemChannel = MethodChannel('com.nanoai/system');

  group('dispatcher open_system', () {
    test('destination válido ejecuta el launcher y verifica', () async {
      var snaps = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentChannel, (call) async {
            if (call.method == 'dumpSnapshot') {
              snaps++;
              return snaps > 1 ? snapshotDobleAceptar() : snapshotAjustes();
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(agentChannel, null),
      );

      final launcher = _FakeSystemIntentLauncher();
      final d = AgentToolDispatcher(
        executor: NanoAgentExecutor(
          stability: const StabilityChecker(wait: Duration.zero),
        ),
        systemIntentLauncher: launcher,
      );
      final r = await d.runToolGuarded(
        const ToolCall(
          tool: 'open_system',
          args: {'destination': 'bluetooth_settings'},
        ),
        confirmed: true,
      );
      expect(launcher.opened, [SystemDestination.bluetoothSettings]);
      expect(r.feedback, contains('Ajustes de Bluetooth abiertos'));
    });

    test('raw intent string rechazado (no llega al launcher)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentChannel, (call) async {
            if (call.method == 'dumpSnapshot') return snapshotAjustes();
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(agentChannel, null),
      );

      final launcher = _FakeSystemIntentLauncher();
      final d = AgentToolDispatcher(
        executor: NanoAgentExecutor(
          stability: const StabilityChecker(wait: Duration.zero),
        ),
        systemIntentLauncher: launcher,
      );
      final r = await d.runToolGuarded(
        const ToolCall(
          tool: 'open_system',
          args: {'destination': 'android.settings.WIFI_SETTINGS'},
        ),
        confirmed: true,
      );
      expect(r.feedback, contains('[tool] open_system requiere args'));
      expect(launcher.opened, isEmpty);
    });

    test('launcher no conectado → unavailable honesto', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(agentChannel, (call) async {
            if (call.method == 'dumpSnapshot') return snapshotAjustes();
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(agentChannel, null),
      );

      final d = AgentToolDispatcher(
        executor: NanoAgentExecutor(
          stability: const StabilityChecker(wait: Duration.zero),
        ),
      );
      final r = await d.runToolGuarded(
        const ToolCall(tool: 'open_system', args: {'destination': 'settings'}),
        confirmed: true,
      );
      expect(r.feedback, contains('[unavailable]'));
    });
  });

  group('MethodChannelSystemIntentLauncher', () {
    test('opened true → ok', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(systemChannel, (call) async {
            expect(call.method, 'openSystemDestination');
            expect(call.arguments, {'destination': 'bluetooth_settings'});
            return {'opened': true};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(systemChannel, null),
      );

      final res = await MethodChannelSystemIntentLauncher().open(
        SystemDestination.bluetoothSettings,
      );
      expect(res.opened, isTrue);
      expect(res.error, isNull);
    });

    test('launch_failed → error tipado', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(systemChannel, (call) async {
            return {'opened': false, 'error': 'launch_failed'};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(systemChannel, null),
      );

      final res = await MethodChannelSystemIntentLauncher().open(
        SystemDestination.wifiSettings,
      );
      expect(res.opened, isFalse);
      expect(res.error, SystemIntentError.launchFailed);
    });

    test('unsupported_destination → error tipado', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(systemChannel, (call) async {
            return {'opened': false, 'error': 'unsupported_destination'};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(systemChannel, null),
      );

      final res = await MethodChannelSystemIntentLauncher().open(
        SystemDestination.settings,
      );
      expect(res.error, SystemIntentError.unsupported);
    });
  });
}

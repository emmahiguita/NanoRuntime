import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/execution/agent_executor.dart';
import 'package:nanoai/features/automation/engine/execution/agent_result.dart';
import 'package:nanoai/features/automation/engine/perception/nano_selector.dart';

import 'fixtures.dart';

/// Tests del NanoAgentExecutor con el canal `com.nanoai/agent` mockeado
/// (patrón TestDefaultBinaryMessengerBinding de vnc_client_test.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/agent');

  // Estado del mock — configurable por test.
  final methodCalls = <String>[];
  final tapCalls = <List<int>>[];
  final inputCalls = <String>[];
  var dumpCalls = 0;
  var dumpProvider = (_) => snapshotAjustes();
  var tapResult = true;
  var inputResult = true;
  var channelDead = false;
  var focusedAfterTap = true;

  final executor = NanoAgentExecutor(
    stability: const StabilityChecker(
      wait: Duration.zero,
      maxCenterDeltaPx: 24,
      maxSizeChangeRatio: 0.10,
    ),
  );

  Map<String, dynamic> ajustesFocused({required bool focused}) {
    final raw = snapshotAjustes();
    ((raw['nodes'] as List)[5] as Map)['focused'] = focused;
    return raw;
  }

  setUp(() {
    methodCalls.clear();
    tapCalls.clear();
    inputCalls.clear();
    dumpCalls = 0;
    dumpProvider = (_) => snapshotAjustes();
    tapResult = true;
    inputResult = true;
    channelDead = false;
    focusedAfterTap = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call.method);
      switch (call.method) {
        case 'dumpSnapshot':
          if (channelDead) throw PlatformException(code: 'dead');
          return dumpProvider(dumpCalls++);
        case 'tapAt':
          focusedAfterTap = true;
          final args = call.arguments as Map;
          tapCalls.add([args['x'] as int, args['y'] as int]);
          return tapResult;
        case 'inputText':
          inputCalls.add((call.arguments as Map)['text'] as String);
          return inputResult;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('tap ok → un solo tapAt en el centro del bounds, nunca tapOnText',
      () async {
    final r = await executor.tap(const NanoSelector(text: 'Bluetooth'));
    expect(r.ok, isTrue);
    expect(r.targetNode!.bounds.centerX, 540);
    expect(r.targetNode!.bounds.centerY, 340);
    expect(tapCalls, [
      [540, 340]
    ]);
    expect(methodCalls, isNot(contains('tapOnText')));
    expect(methodCalls, isNot(contains('inputText')));
  });

  test('ambiguous → failure tipado sin gesto', () async {
    dumpProvider = (_) => snapshotDobleAceptar();
    final r = await executor.tap(const NanoSelector(text: 'Aceptar'));
    expect(r.ok, isFalse);
    expect(r.errorCode, AgentErrorCode.ambiguousTarget);
    expect(tapCalls, isEmpty);
  });

  test('primer dump vacío + segundo ok → retry y resuelve', () async {
    dumpProvider = (call) =>
        call == 0 ? const {'package': '', 'nodes': []} : snapshotAjustes();
    final r = await executor.tap(const NanoSelector(text: 'Bluetooth'));
    expect(r.ok, isTrue);
    expect(tapCalls, [
      [540, 340]
    ]);
  });

  test('siempre vacío (canal vivo) → snapshotEmpty', () async {
    dumpProvider = (_) => const {'package': '', 'nodes': []};
    final r = await executor.tap(const NanoSelector(text: 'Bluetooth'));
    expect(r.ok, isFalse);
    expect(r.errorCode, AgentErrorCode.snapshotEmpty);
    expect(tapCalls, isEmpty);
  });

  test('canal muerto (excepción) → serviceOff', () async {
    channelDead = true;
    final r = await executor.tap(const NanoSelector(text: 'Bluetooth'));
    expect(r.ok, isFalse);
    expect(r.errorCode, AgentErrorCode.serviceOff);
    expect(tapCalls, isEmpty);
  });

  test('nodo movido 60px en re-resolve → unstableTarget sin gesto', () async {
    dumpProvider = (call) {
      if (call == 0) return snapshotAjustes();
      final moved = snapshotAjustes();
      // Bluetooth bounds [40,300,1040,380] → +60 en x.
      ((moved['nodes'] as List)[4] as Map)['bounds'] = [100, 300, 1100, 380];
      return moved;
    };
    final r = await executor.tap(const NanoSelector(text: 'Bluetooth'));
    expect(r.ok, isFalse);
    expect(r.errorCode, AgentErrorCode.unstableTarget);
    expect(tapCalls, isEmpty);
  });

  test('setText sin foco → tap de foco y luego inputText', () async {
    focusedAfterTap = false; // el dump inicial viene sin foco
    dumpProvider = (_) => ajustesFocused(focused: focusedAfterTap);
    final r = await executor.setText(
      const NanoSelector(editable: true),
      'wifi',
    );
    expect(r.ok, isTrue);
    expect(tapCalls.length, 1); // tap de foco al EditText (centro 540,480)
    expect(tapCalls, [
      [540, 480]
    ]);
    expect(inputCalls, ['wifi']);
  });

  test('setText con foco → solo inputText, sin tap', () async {
    dumpProvider = (_) => ajustesFocused(focused: true);
    final r = await executor.setText(
      const NanoSelector(editable: true),
      'wifi',
    );
    expect(r.ok, isTrue);
    expect(tapCalls, isEmpty);
    expect(inputCalls, ['wifi']);
  });

  test('setText: tap de foco no enfoca → notActionable, sin inputText',
      () async {
    // El tap se ejecuta pero el campo nunca gana foco.
    dumpProvider = (_) => ajustesFocused(focused: false);
    final r = await executor.setText(
      const NanoSelector(editable: true),
      'wifi',
    );
    expect(r.ok, isFalse);
    expect(r.errorCode, AgentErrorCode.notActionable);
    expect(r.reason, contains('no enfocable'));
    expect(inputCalls, isEmpty);
  });

  test('package mismatch → notFound', () async {
    final r = await executor.tap(
      const NanoSelector(packageName: 'com.whatsapp', text: 'Bluetooth'),
    );
    expect(r.ok, isFalse);
    expect(r.errorCode, AgentErrorCode.notFound);
    expect(tapCalls, isEmpty);
  });

  test('gesto rechazado por el canal → gestureFailed', () async {
    tapResult = false;
    final r = await executor.tap(const NanoSelector(text: 'Bluetooth'));
    expect(r.ok, isFalse);
    expect(r.errorCode, AgentErrorCode.gestureFailed);
  });

  test('resolve sin ejecutar → outcome, sin gestos', () async {
    dumpProvider = (_) => snapshotDobleAceptar();
    final r = await executor.resolve(const NanoSelector(text: 'Aceptar'));
    expect(r.status, ResolveStatus.ambiguous);
    expect(r.candidates.length, 2);
    expect(tapCalls, isEmpty);
    expect(inputCalls, isEmpty);
  });
}

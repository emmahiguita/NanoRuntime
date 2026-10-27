import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_turn_state_access.dart';
import 'package:nanoai/features/automation/personal_agent/domain/open_loop_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  Map<String, dynamic>? storedRow;

  setUp(() {
    storedRow = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
          switch (call.method) {
            case 'personalTurnStateGet':
              return storedRow;
            case 'personalTurnStateUpsert':
              storedRow = <String, dynamic>{
                'id': 7,
                'scopeKey': args['scopeKey'],
                'key': 'turnState',
                'value': args['value'],
                'observedAt': args['observedAt'],
                'kind': 'personalTurnState',
                'metadata': '{}',
              };
              return 7;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('detector guarda etiqueta semántica y nunca el mensaje original', () {
    const original = 'mañana te paso el archivo confidencial contrato-2026.pdf';
    final loops = OpenLoopDetector.detect(original, nowMs: 10);

    expect(loops, hasLength(1));
    expect(loops.single.status, 'OPEN');
    expect(loops.single.dueHint, 'mañana');
    expect(loops.single.description, isNot(contains('contrato-2026')));
    expect(loops.single.description, isNot(contains('archivo confidencial')));
  });

  test('estado usa el canal upsert dedicado y vuelve a cargarse', () async {
    const access = PersonalTurnStateAccess();
    final loop = OpenLoopDetector.detect(
      'te aviso cuando llegue',
      nowMs: DateTime.now().millisecondsSinceEpoch,
    ).single;

    await access.merge('chat:academia', openLoops: [loop]);
    final stored = jsonDecode(storedRow!['value'] as String) as Map;
    expect(stored['openLoops'], hasLength(1));

    final loaded = await access.load('chat:academia');
    expect(loaded, isNotNull);
    expect(loaded!.openLoops.single.status, 'OPEN');
  });
}

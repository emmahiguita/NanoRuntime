import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/mcp/whatsapp_mcp_delta_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  final batches = <Map<Object?, Object?>>[];
  setUp(() {
    batches.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments as Map;
            if (call.method == 'syncCursorGet') {
            return {'cursorSeq': args['stream'] == 'a' ? 1 : 10};
            }
          if (call.method == 'mcpDeltaBatchApply') {
            batches.add(Map.of(args));
            return {'ok': true};
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  Map<String, Object?> delta(int next, {bool timestamp = true}) => {
    'next_cursor': next,
    'snapshot_seq': next,
    'events': [
      {
        'message': {
          'id': 'same-id',
          'chat_id': 'juan',
          'text': 'sí',
          'from_me': false,
          if (timestamp) 'timestamp_ms': 1000,
        },
      },
    ],
  };

  test(
    'Single flight agrupa una cuenta y conserva dos cuentas independientes',
    () async {
      final a = Completer<Map<String, Object?>>();
      final b = Completer<Map<String, Object?>>();
      final aStarted = Completer<void>();
      final bStarted = Completer<void>();
      var callsA = 0;
      Future<Map<String, Object?>> callerA(
        String tool,
        Map<String, Object?> args,
      ) {
        callsA++;
        expect(args['after'], 1);
        aStarted.complete();
        return a.future;
      }

      Future<Map<String, Object?>> callerB(
        String tool,
        Map<String, Object?> args,
      ) {
        expect(args['after'], 10);
        bStarted.complete();
        return b.future;
      }

      final first = WhatsAppMcpDeltaSync.syncWithCaller(callerA, stream: 'a');
      final same = WhatsAppMcpDeltaSync.syncWithCaller(callerA, stream: 'a');
      final second = WhatsAppMcpDeltaSync.syncWithCaller(callerB, stream: 'b');
      await Future.wait([aStarted.future, bStarted.future]);
      a.complete(delta(2));
      b.complete(delta(11));
      expect(await Future.wait([first, same, second]), [true, true, true]);
      expect(callsA, 1);
      expect(batches, hasLength(2));
      final rows = batches
          .map((b) => (b['rows'] as List).single as Map)
          .toList();
      expect(rows[0]['conversationId'], isNot(rows[1]['conversationId']));
      expect(rows[0]['id'], isNot(rows[1]['id']));
      expect(
        rows
            .map((r) => jsonDecode(r['rawMetadata'] as String)['accountId'])
            .toSet(),
        {'a', 'b'},
      );
    },
  );
  test('Un evento sin fecha no inventa hora ni adelanta el cursor', () async {
    final result = await WhatsAppMcpDeltaSync.syncWithCaller(
      (_, _) async => delta(2, timestamp: false),
      stream: 'a',
    );
    expect(result, isFalse);
    expect(batches, isEmpty);
  });
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/scheduling/burst_durability.dart';
import 'package:nanoai/features/automation/engine/storage/automation_db_store_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  String? section;

  setUp(() {
    section = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'get':
              await Future<void>.delayed(const Duration(milliseconds: 2));
              return section;
            case 'put':
              final args = (call.arguments as Map).cast<String, dynamic>();
              section = args['json'] as String;
              return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('dos fragmentos concurrentes conservan ambas claves', () async {
    final store = BurstShadowStore(db: AutomationDbStoreClient.instance);
    await Future.wait([
      store.recordFragment('chat-1', 'notification-a'),
      store.recordFragment('chat-1', 'notification-b'),
    ]);

    final decoded = jsonDecode(section!) as Map<String, dynamic>;
    final entry = decoded['chat-1'] as Map<String, dynamic>;
    expect(entry['keys'], ['notification-a', 'notification-b']);

    await Future<void>.delayed(const Duration(milliseconds: 2));
    final stale = await store.recoverStale(Duration.zero);
    expect(stale.single.notificationKeys, hasLength(2));
  });

  test(
    'emitir elimina la sombra después de las escrituras pendientes',
    () async {
      final store = BurstShadowStore(db: AutomationDbStoreClient.instance);
      await store.recordFragment('chat-2', 'notification-c');
      await store.markEmitted('chat-2');

      final decoded = jsonDecode(section!) as Map<String, dynamic>;
      expect(decoded.containsKey('chat-2'), isFalse);
    },
  );
}

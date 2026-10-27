import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_context_builder.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_message.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_message_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nanoai/automation_store');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var bodies = ['primero', 'segundo', 'último'];
  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'conversationCoverageList') return [];
      if (call.method == 'canonicalMessageList') {
        // Reproduce el contrato nativo real: mensajes recientes en ascendente.
        return [
          for (var i = 0; i < bodies.length; i++)
            CanonicalMessage.observed(
              conversationId: 'chat',
              provider: CanonicalMessageProvider.androidNotification,
              body: bodies[i],
              occurredAtMs: (i + 1) * 1000,
            ).toPlatformMap(),
        ];
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('el prompt conserva la secuencia real de SQLite', () async {
    final context = await CanonicalContextBuilder(
      store: CanonicalMessageStore(),
    ).build(conversationId: 'chat');
    final prompt = context.promptBlock;
    expect(prompt.indexOf('primero'), lessThan(prompt.indexOf('segundo')));
    expect(prompt.indexOf('segundo'), lessThan(prompt.indexOf('último')));
    expect(context.hasKnownGaps, isTrue);
  });

  test('el presupuesto conserva el mensaje más reciente', () async {
    bodies = ['antiguo ' * 200, 'respuesta ' * 200, 'último importante'];
    final context = await CanonicalContextBuilder(
      store: CanonicalMessageStore(),
    ).build(conversationId: 'chat', maxChars: 600);
    expect(context.promptBlock.length, lessThanOrEqualTo(600));
    expect(context.promptBlock, contains('último importante'));
  });
}

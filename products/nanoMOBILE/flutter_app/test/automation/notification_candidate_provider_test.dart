import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_provider.dart';
import 'package:nanoai/features/automation/engine/planning/candidates/notification_candidate_provider.dart';

Map<String, Object> notification({
  String key = 'k1',
  String pkg = 'com.whatsapp',
  String sender = 'Juan',
  String? conversationTitle,
  bool canReply = true,
}) => {
  'key': key,
  'package': pkg,
  'sender': sender,
  'conversationTitle': conversationTitle ?? '$sender Pérez',
  'title': 'WhatsApp',
  'text': 'hola',
  'messageText': 'hola',
  'remoteInputKey': 'ri1',
  'canReply': canReply,
  'postTime': 2,
  'isGroup': false,
  'isSummary': false,
  'actions': <String>[],
  'ongoing': false,
};

void main() {
  group('NotificationCandidateProvider · reply por lenguaje natural (T2.0)', () {
    test(
      '"responde a Juan que llego a las 8" → reply_notification con text',
      () async {
        final p = NotificationCandidateProvider(() async => [
          notification(sender: 'Juan'),
        ]);
        final c = await p.provide(
          const CandidateRequest('responde a Juan que llego a las 8'),
        );
        expect(c, hasLength(1));
        expect(c.single.tool, 'reply_notification');
        expect(c.single.args['key'], 'k1');
        expect(c.single.args['text'], 'llego a las 8');
        expect(c.single.args['conversation'], contains('Juan'));
      },
    );

    test('el match usa SOLO el recipient, no el texto del mensaje', () async {
      final p = NotificationCandidateProvider(() async => [
        notification(sender: 'María'),
        notification(sender: 'Juan', key: 'k2'),
      ]);
      final c = await p.provide(
        const CandidateRequest('responde a Juan que llego a las 8'),
      );
      // Debe matchear a Juan (k2), no a la primera (María).
      expect(c.single.args['key'], 'k2');
    });

    test('sin mensaje → no reply (no inventa texto), abre la app', () async {
      final p = NotificationCandidateProvider(() async => [
        notification(sender: 'Juan'),
      ]);
      final c = await p.provide(const CandidateRequest('responde a Juan'));
      expect(c, hasLength(1));
      expect(c.single.tool, 'launch_app');
      expect(c.single.args['packageName'], 'com.whatsapp');
    });

    test('sin RemoteInput → abre la app (fallback UI)', () async {
      final p = NotificationCandidateProvider(() async => [
        notification(sender: 'Juan', canReply: false),
      ]);
      final c = await p.provide(
        const CandidateRequest('responde a Juan que llego a las 8'),
      );
      expect(c.single.tool, 'launch_app');
    });

    test('objetivo sin verbo de respuesta → sin candidatos', () async {
      final p = NotificationCandidateProvider(() async => [
        notification(),
      ]);
      final c = await p.provide(const CandidateRequest('abre Chrome'));
      expect(c, isEmpty);
    });
  });
}

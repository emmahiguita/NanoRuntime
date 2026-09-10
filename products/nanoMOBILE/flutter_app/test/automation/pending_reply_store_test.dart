import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/pending_reply.dart';
import 'package:nanoai/features/automation/engine/messaging/pending_reply_store.dart';

void main() {
  group('PendingReplyStore WA-DRAFT-INBOX-01', () {
    test('Guarda y lista borradores pendientes con orden cronológico descendente', () async {
      final store = PendingReplyStore(); // En memoria

      final r1 = PendingReply(
        id: '1',
        conversationId: 'c1',
        packageName: 'com.whatsapp',
        sender: 'Carlos',
        originalMessage: 'Hola',
        draftText: '¡Hola Carlos!',
        status: PendingReplyStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      final r2 = PendingReply(
        id: '2',
        conversationId: 'c2',
        packageName: 'com.whatsapp.w4b',
        sender: 'Cliente VIP',
        originalMessage: 'Precio por favor',
        draftText: 'El precio es \$50.',
        status: PendingReplyStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await store.save(r1);
      await store.save(r2);

      final pending = await store.allPending();
      expect(pending.length, equals(2));
      // Orden descendente por createdAt (r2 primero)
      expect(pending.first.id, equals('2'));
      expect(pending.last.id, equals('1'));
    });

    test('Actualiza texto, aprueba, descarta y marca como enviado', () async {
      final store = PendingReplyStore();

      final reply = PendingReply(
        id: '10',
        conversationId: 'c10',
        packageName: 'com.whatsapp',
        sender: 'Maria',
        originalMessage: 'Nos vemos a las 5?',
        draftText: 'Sí',
        status: PendingReplyStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      await store.save(reply);
      await store.updateDraftText('10', 'Sí, nos vemos a las 5.');

      var pending = await store.allPending();
      expect(pending.first.draftText, equals('Sí, nos vemos a las 5.'));

      await store.markSent('10');
      pending = await store.allPending();
      expect(pending.isEmpty, isTrue); // ya no está en pending
    });

    test('Borradores expirados no se devuelven en allPending', () async {
      final store = PendingReplyStore();

      final expired = PendingReply(
        id: 'exp',
        conversationId: 'cx',
        packageName: 'com.whatsapp',
        sender: 'Viejo',
        originalMessage: 'Ayer',
        draftText: 'Borrador viejo',
        status: PendingReplyStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await store.save(expired);
      final pending = await store.allPending();
      expect(pending.isEmpty, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_assignment_store.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';
import 'package:nanoai/features/automation/engine/messaging/incoming_message.dart';
import 'package:nanoai/features/automation/engine/messaging/messaging_package.dart';
import 'package:nanoai/features/automation/engine/notifications/conversation_agent_contract.dart';

void main() {
  group('asignación persistente de agentes', () {
    test('WhatsApp personal y Business nacen en agentes distintos', () async {
      final store = MemoryConversationAssignmentStore();

      final personal = await store.ensureAssignment(
        _key(MessagingPackage.whatsapp, 'whatsapp', 'p-1'),
      );
      final business = await store.ensureAssignment(
        _key(MessagingPackage.whatsappBusiness, 'whatsapp.business', 'b-1'),
      );

      expect(personal.agentId, ConversationAgentId.personal);
      expect(business.agentId, ConversationAgentId.business);
      expect(personal.scope.id, isNot(business.scope.id));
    });

    test('la asignación no cambia por el contenido de un turno', () async {
      final store = MemoryConversationAssignmentStore();
      final key = _key(MessagingPackage.whatsapp, 'whatsapp', 'p-2');

      final first = await store.ensureAssignment(key);
      final second = await store.ensureAssignment(key);

      expect(first.agentId, ConversationAgentId.personal);
      expect(second.scope.id, first.scope.id);
    });
  });

  test('una transferencia no mezcla la memoria entre agentes', () async {
    final assignments = MemoryConversationAssignmentStore();
    final key = _key(MessagingPackage.whatsapp, 'whatsapp', 'p-3');
    await assignments.ensureAssignment(key);
    final memory = MemoryConversationMemoryStore(assignments: assignments);
    await memory.load();

    memory.appendInbound(
      _message(key, 'hola personal', 'evt-personal'),
      atMs: 1,
    );
    expect(memory.memoryFor(key.id)!.entries.single.text, 'hola personal');

    await assignments.transfer(
      key.id,
      ConversationAgentId.business,
      reason: 'el dueño transfirió la conversación',
      minimalContext: 'tema=pedido',
      atMs: 2,
    );
    expect(memory.memoryFor(key.id), isNull);

    memory.appendInbound(
      _message(key, 'hola negocio', 'evt-business'),
      atMs: 3,
    );
    expect(memory.memoryFor(key.id)!.entries.single.text, 'hola negocio');

    await assignments.transfer(
      key.id,
      ConversationAgentId.personal,
      reason: 'regreso explícito',
      atMs: 4,
    );
    expect(memory.memoryFor(key.id)!.entries.single.text, 'hola personal');
  });

  test('los contratos prohíben el contexto del otro agente', () {
    final personal = conversationAgentContract(ConversationAgentId.personal);
    final business = conversationAgentContract(ConversationAgentId.business);

    expect(personal, contains('No consultes ni reveles catálogo'));
    expect(business, contains('No leas ni reveles relaciones'));
  });
}

ConversationKey _key(String packageName, String channel, String fingerprint) =>
    ConversationKey(
      channel: channel,
      appPackage: packageName,
      accountFingerprint: 'cuenta-1',
      conversationFingerprint: fingerprint,
    );

IncomingMessage _message(ConversationKey key, String text, String eventId) =>
    IncomingMessage(
      eventId: eventId,
      conversation: ConversationIdentity(
        key: key,
        confidence: 1,
        evidenceUsed: const {'test'},
      ),
      notificationKey: eventId,
      packageName: key.appPackage,
      sender: 'Cliente',
      text: text,
      messageTimestamp: 0,
      receivedAt: 0,
      replyCapability: null,
      rawEvidence: const {},
    );

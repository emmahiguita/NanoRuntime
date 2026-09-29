import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_ownership_policy.dart';
import 'package:nanoai/features/automation/personal_agent/application/conversation_ownership_store.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_owner.dart';
import 'package:nanoai/features/automation/personal_agent/domain/persona_example.dart';
import 'package:nanoai/core/providers/settings_provider.dart';

/// TESTS: PERSONA-VARIANTS & CONTACT-POLICY
///
/// QUÉ HACE:
/// Verifica que PersonaExample decodifique títulos y listas de 5+ variantes
/// de respuesta correctamente, y que SettingsState soporte los modos de contacto.
void main() {
  group('PersonaExample & Multi-Variant Dialogues', () {
    test('PersonaExample expone categoryTitle y variants correctamente', () {
      final variants = [
        '¡Hola! ¿Cómo estás hoy?',
        '¡Buenas! ¿Todo bien por allá?',
        'Hola, ¿qué tal?',
        '¡Hola! Cuéntame en qué te puedo colaborar.',
        'Buenas tardes, ¿cómo te va?',
      ];
      final example = PersonaExample(
        id: 1,
        personaKey: 'owner',
        body: variants.first,
        incomingText: 'Hola',
        tone: {
          'title': 'Saludos cordiales',
          'variants': jsonEncode(variants),
        },
      );

      expect(example.categoryTitle, 'Saludos cordiales');
      expect(example.variants.length, 5);
      expect(example.variants, equals(variants));
    });

    test('Fallback a [body] cuando variants no está configurado', () {
      const example = PersonaExample(
        id: 2,
        personaKey: 'owner',
        body: 'Hola, ¿cómo estás?',
        incomingText: 'Hola',
      );

      expect(example.categoryTitle, isEmpty);
      expect(example.variants, equals(['Hola, ¿cómo estás?']));
    });
  });

  group('SettingsState Contact Policy', () {
    test('waTargetContactsMode tiene default all y copyWith respeta cambios', () {
      const state = SettingsState();
      expect(state.waTargetContactsMode, 'all');

      final selectedState = state.copyWith(waTargetContactsMode: 'selected');
      expect(selectedState.waTargetContactsMode, 'selected');
    });

    test('La selección por teléfono activa el contacto con una clave Android distinta', () {
      final store = _MemoryOwnershipStore()
        ..put('15551234567@s.whatsapp.net', ConversationOwner.bot)
        ..put('15551234567', ConversationOwner.bot);
      final ownership = ConversationOwnershipPolicy.ownershipForNotification(
        store: store,
        conversationId: 'whatsapp/com.whatsapp/-/shortcut:opaque-chat-id',
        notification: _notification(
          sender: 'Emma',
          senderUri: 'tel:+1 (555) 123-4567',
        ),
      );

      expect(ownership?.owner, ConversationOwner.bot);
      expect(ConversationOwnershipPolicy.humanOwns(
        targetContactsMode: 'selected',
        ownership: ownership,
      ), isFalse);
    });

    test('Un contacto no seleccionado se bloquea aunque se llame Emma', () {
      final ownership = ConversationOwnershipPolicy.ownershipForNotification(
        store: _MemoryOwnershipStore(),
        conversationId: 'whatsapp/com.whatsapp/-/conv:opaque-chat-id',
        notification: _notification(sender: 'Emma'),
      );

      expect(ownership, isNull);
      expect(ConversationOwnershipPolicy.humanOwns(
        targetContactsMode: 'selected',
        ownership: ownership,
      ), isTrue);
    });

    test('La selección de un contacto no habilita grupos', () {
      final store = _MemoryOwnershipStore()
        ..put('15551234567', ConversationOwner.bot);
      final ownership = ConversationOwnershipPolicy.ownershipForNotification(
        store: store,
        conversationId: 'whatsapp/com.whatsapp/-/shortcut:group',
        notification: _notification(
          senderUri: 'tel:+15551234567',
          isGroup: true,
        ),
        isGroup: true,
      );

      expect(ownership, isNull);
    });

    test('Las filas históricas resuelven Person.key por teléfono', () {
      final store = _MemoryOwnershipStore()
        ..put('15551234567', ConversationOwner.bot);
      final ownership = ConversationOwnershipPolicy.ownershipForConversation(
        store: store,
        conversationId: 'whatsapp/com.whatsapp/-/person:15551234567',
        packageName: 'com.whatsapp',
      );

      expect(ownership?.owner, ConversationOwner.bot);
    });

    test('Los aliases de WhatsApp no autorizan otras apps', () {
      final store = _MemoryOwnershipStore()
        ..put('15551234567', ConversationOwner.bot);
      final ownership = ConversationOwnershipPolicy.ownershipForNotification(
        store: store,
        conversationId: 'telegram/com.telegram.messenger/-/person:15551234567',
        notification: _notification(
          packageName: 'com.telegram.messenger',
          senderUri: 'tel:+15551234567',
        ),
      );

      expect(ownership, isNull);
    });

    test('Todos responde por defecto y respeta la toma de control humano', () {
      expect(ConversationOwnershipPolicy.humanOwns(
        targetContactsMode: 'all',
        ownership: null,
      ), isFalse);
      expect(ConversationOwnershipPolicy.humanOwns(
        targetContactsMode: 'all',
        ownership: const ConversationOwnership(
          conversationId: 'chat',
          owner: ConversationOwner.human,
          updatedAtMs: 0,
        ),
      ), isTrue);
    });
  });
}

NotificationObject _notification({
  String packageName = 'com.whatsapp',
  String sender = '',
  String senderUri = '',
  bool isGroup = false,
}) => NotificationObject.fromMap({
  'package': packageName,
  'key': 'notification-key',
  'title': sender,
  'sender': sender,
  'senderUri': senderUri,
  'isGroup': isGroup,
});

final class _MemoryOwnershipStore implements ConversationOwnershipStore {
  final Map<String, ConversationOwnership> _values = {};

  void put(String id, ConversationOwner owner) {
    _values[id] = ConversationOwnership(
      conversationId: id,
      owner: owner,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  ConversationOwnership? ownershipFor(String conversationId) =>
      _values[conversationId];

  @override
  Future<ConversationOwnership> setOwner(
    String conversationId,
    ConversationOwner owner, {
    int? nowMs,
  }) async {
    final value = ConversationOwnership(
      conversationId: conversationId,
      owner: owner,
      updatedAtMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    _values[conversationId] = value;
    return value;
  }

  @override
  Future<ConversationOwnership> release(String conversationId) =>
      setOwner(conversationId, ConversationOwner.bot);
}

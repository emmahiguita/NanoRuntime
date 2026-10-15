import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/automation/engine/web_bridge/whatsapp_web_conversation_decoder.dart';
import '../../../lib/features/automation/engine/web_bridge/whatsapp_web_history_scripts.dart';

void main() {
  group('WhatsAppWebConversationDecoder — Retención no destructiva', () {
    test('Conserva contactos previos fuera de la ventana virtualizada del DOM', () {
      final decoder = WhatsAppWebConversationDecoder();
      final firstSnapshot = decoder.decode([
        {
          'id': 'fonszo',
          'displayName': '🤜🏻👍🏼🤜🏻👍fonszo',
          'lastMessage': 'Hola hermano',
          'timeLabel': '10:30',
          'unreadCount': 1,
          'isGroup': false,
        },
        {
          'id': 'maria',
          'displayName': 'María Gómez',
          'lastMessage': 'Te envié el archivo',
          'timeLabel': 'Ayer',
          'unreadCount': 0,
          'isGroup': false,
        },
      ], const []);

      expect(firstSnapshot, hasLength(2));

      // Al desplazarse o actualizarse parcialmente el DOM, solo llega un nuevo chat.
      final secondSnapshot = decoder.decode([
        {
          'id': 'carlos',
          'displayName': 'Carlos Ventas',
          'lastMessage': 'Confirmado',
          'timeLabel': '11:45',
          'unreadCount': 2,
          'isGroup': false,
        },
      ], firstSnapshot);

      expect(secondSnapshot, hasLength(3));
      expect(
        secondSnapshot.map((c) => c.id),
        containsAll(['carlos', 'fonszo', 'maria']),
      );
    });

    test('Serializa y restaura contactos reales con emojis intactos', () {
      const original = WhatsAppWebConversationSummary(
        id: 'fonszo',
        displayName: '🤜🏻👍🏼🤜🏻👍fonszo',
        lastMessage: 'Listo',
        timeLabel: 'Lunes',
        lastAtMs: 1700000000000,
        unreadCount: 3,
        isGroup: false,
      );
      final restored = WhatsAppWebConversationSummary.fromJson(
        original.toJson(),
      );
      expect(restored, isNotNull);
      expect(restored!.displayName, equals('🤜🏻👍🏼🤜🏻👍fonszo'));
      expect(restored.lastMessage, equals('Listo'));
      expect(restored.unreadCount, equals(3));
    });
  });

  group('WhatsAppWebHistoryScripts — Normalización de títulos con emojis', () {
    test('Ignora selectores de variación y espacios al comparar encabezado', () {
      expect(
        WhatsAppWebHistoryScripts.normalizeTitle('🤜🏻👍🏼🤜🏻👍\uFE0F  fonszo'),
        equals(
          WhatsAppWebHistoryScripts.normalizeTitle('🤜🏻👍🏼🤜🏻👍 fonszo'),
        ),
      );
    });
  });
}

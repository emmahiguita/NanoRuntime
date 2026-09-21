import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/domain/messaging_platform.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_center_providers.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_dedup_merger.dart';

void main() {
  group('Messaging Center Domain & Platform Mapping', () {
    test('Identifica WhatsApp correctamente por packageName', () {
      expect(
        MessagingPlatform.fromPackageName('com.whatsapp'),
        equals(MessagingPlatform.whatsapp),
      );
      expect(
        MessagingPlatform.fromPackageName('com.whatsapp.w4b'),
        equals(MessagingPlatform.whatsappBusiness),
      );
    });

    test('Identifica Telegram correctamente', () {
      expect(
        MessagingPlatform.fromPackageName('org.telegram.messenger'),
        equals(MessagingPlatform.telegram),
      );
      expect(
        MessagingPlatform.fromPackageName('org.telegram.plus'),
        equals(MessagingPlatform.telegram),
      );
    });

    test('Identifica Gmail, Slack, Instagram, Facebook, X, LinkedIn', () {
      expect(
        MessagingPlatform.fromPackageName('com.google.android.gm'),
        equals(MessagingPlatform.gmail),
      );
      expect(
        MessagingPlatform.fromPackageName('com.Slack'),
        equals(MessagingPlatform.slack),
      );
      expect(
        MessagingPlatform.fromPackageName('com.instagram.android'),
        equals(MessagingPlatform.instagram),
      );
      expect(
        MessagingPlatform.fromPackageName('com.facebook.katana'),
        equals(MessagingPlatform.facebook),
      );
      expect(
        MessagingPlatform.fromPackageName('com.facebook.orca'),
        equals(MessagingPlatform.facebook),
      );
      expect(
        MessagingPlatform.fromPackageName('com.twitter.android'),
        equals(MessagingPlatform.x),
      );
      expect(
        MessagingPlatform.fromPackageName('com.linkedin.android'),
        equals(MessagingPlatform.linkedin),
      );
    });

    test('Fallback a other para paquetes desconocidos', () {
      expect(
        MessagingPlatform.fromPackageName('com.unknown.randomapp'),
        equals(MessagingPlatform.other),
      );
    });
  });

  group('Messaging Center Providers State', () {
    test('Estado inicial de filtros y búsqueda', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedPlatformFilterProvider), isNull);
      expect(
        container.read(selectedCategoryTabProvider),
        equals(MessagingCategoryFilter.all),
      );
      expect(container.read(messagingSearchQueryProvider), isEmpty);
    });
  });

  group('MessagingDedupMerger (Deduplicación e Integridad Factual)', () {
    test('Filtra paquetes del sistema operativo Android y acepta solo mensajería', () {
      expect(MessagingDedupMerger.isSupportedMessagingApp('android'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.android.systemui'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.coloros.phonemanager'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.google.android.googlequicksearchbox'), isFalse);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.whatsapp'), isTrue);
      expect(MessagingDedupMerger.isSupportedMessagingApp('com.whatsapp.w4b'), isTrue);
      expect(MessagingDedupMerger.isSupportedMessagingApp('org.telegram.messenger'), isTrue);
    });

    test('Fusiona notificación viva con conversación previa de SQLite sin duplicar', () {
      const existing = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/Emm',
        displayName: 'Emm',
        packageName: 'com.whatsapp',
        lastMessage: 'Hola, ¿cómo estás?',
        lastAtMs: 1000,
        agentId: ConversationAgentId.personal,
      );

      const incomingLive = ConversationSummaryItem(
        conversationId: 'live:com.whatsapp:Emm',
        displayName: 'Emm',
        packageName: 'com.whatsapp',
        lastMessage: 'Todo bien por acá',
        lastAtMs: 2000,
        hasPendingReply: true,
        notificationKey: 'notif_key_123',
        agentId: ConversationAgentId.personal,
      );

      final merged = MessagingDedupMerger.deduplicateAndSort([existing, incomingLive]);
      expect(merged.length, equals(1));
      expect(merged.first.displayName, equals('Emm'));
      expect(merged.first.lastMessage, equals('Todo bien por acá'));
      expect(merged.first.lastAtMs, equals(2000));
      expect(merged.first.hasPendingReply, isTrue);
      expect(merged.first.notificationKey, equals('notif_key_123'));
    });

    test('Deduplica contactos por dígitos de teléfono iguales', () {
      const item1 = ConversationSummaryItem(
        conversationId: '573001234567@s.whatsapp.net',
        displayName: 'Emmanuel Higuita',
        packageName: 'com.whatsapp',
        lastMessage: '573001234567',
        lastAtMs: 1000,
        agentId: ConversationAgentId.personal,
      );

      const item2 = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/573001234567',
        displayName: 'Emmanuel Higuita',
        packageName: 'com.whatsapp',
        lastMessage: 'Listo amigo',
        lastAtMs: 3000,
        agentId: ConversationAgentId.personal,
      );

      final merged = MessagingDedupMerger.deduplicateAndSort([item1, item2]);
      expect(merged.length, equals(1));
      expect(merged.first.lastMessage, equals('Listo amigo'));
      expect(merged.first.lastAtMs, equals(3000));
    });
  });
}

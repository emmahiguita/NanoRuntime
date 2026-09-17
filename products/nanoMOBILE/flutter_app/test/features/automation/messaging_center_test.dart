import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/domain/messaging_platform.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_center_providers.dart';

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
}

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/application/whatsapp_contacts_provider.dart';
import 'package:nanoai/features/automation/domain/whatsapp_contact.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_center_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsApp Contacts Domain & Providers', () {
    const channel = MethodChannel('com.nanoai/contacts');

    final sampleContacts = [
      {
        'id': '1',
        'name': 'Carlos Mendoza',
        'number': '+57 300 123 4567',
        'jid': '573001234567@s.whatsapp.net',
        'isBusiness': false,
      },
      {
        'id': '2',
        'name': 'Dra. Patricia Gómez',
        'number': '+57 311 987 6543',
        'jid': '573119876543@s.whatsapp.net',
        'isBusiness': true,
      },
      {
        'id': '3',
        'name': 'Juan Pérez',
        'number': '+57 320 555 7890',
        'jid': '573205557890@s.whatsapp.net',
        'isBusiness': false,
      },
    ];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'hasContactsPermission':
            return true;
          case 'requestContactsPermission':
            return true;
          case 'getWhatsAppContacts':
            return sampleContacts;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('WhatsAppContact fromMap parses fields correctly', () {
      final contact = WhatsAppContact.fromMap({
        'id': '10',
        'name': 'Elena Restrepo',
        'number': '+573009998877',
        'jid': '573009998877@s.whatsapp.net',
        'isBusiness': true,
      });

      expect(contact.id, '10');
      expect(contact.name, 'Elena Restrepo');
      expect(contact.number, '+573009998877');
      expect(contact.jid, '573009998877@s.whatsapp.net');
      expect(contact.isBusiness, isTrue);
    });

    test('WhatsAppContactsService fetches contacts and permission status', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(whatsappContactsServiceProvider);

      final hasPermission = await service.hasPermission();
      expect(hasPermission, isTrue);

      final contacts = await service.getContacts();
      expect(contacts.length, 3);
      expect(contacts.first.name, 'Carlos Mendoza');
      expect(contacts[1].isBusiness, isTrue);
    });

    test('filteredWhatsAppContactsProvider filters contacts by search query', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Esperar a que carguen los contactos
      await container.read(allWhatsAppContactsProvider.future);

      // Sin query: todos los contactos
      var filtered = container.read(filteredWhatsAppContactsProvider);
      expect(filtered.length, 3);

      // Con query: 'patricia'
      container.read(messagingSearchQueryProvider.notifier).state = 'patricia';
      filtered = container.read(filteredWhatsAppContactsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.name, 'Dra. Patricia Gómez');

      // Con query por número: '555'
      container.read(messagingSearchQueryProvider.notifier).state = '555';
      filtered = container.read(filteredWhatsAppContactsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.name, 'Juan Pérez');
    });
  });
}

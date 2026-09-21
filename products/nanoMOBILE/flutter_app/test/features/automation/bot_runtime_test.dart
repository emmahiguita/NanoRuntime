import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/bot/bot_definition.dart';
import 'package:nanoai/features/automation/domain/bot/bot_permissions.dart';
import 'package:nanoai/features/automation/domain/bot/bot_role.dart';
import 'package:nanoai/features/automation/domain/bot/bot_event.dart';
import 'package:nanoai/features/automation/application/bot/bot_skills_catalog.dart';
import 'package:nanoai/features/automation/engine/bot/bot_capability_router.dart';

void main() {
  group('Nano Bot Runtime — Dominio y Gobernanza', () {
    test('BotPermissions: Sales bloquea terminal Linux y herramientas de sistema', () {
      final salesPerms = BotPermissions.salesRestricted();

      expect(salesPerms.canExecute('catalog.search'), isTrue);
      expect(salesPerms.canExecute('whatsapp.send'), isTrue);
      expect(salesPerms.canExecute('payment.charge'), isTrue);

      expect(salesPerms.canExecute('linux.exec'), isFalse);
      expect(salesPerms.canExecute('linux.raw_exec'), isFalse);
      expect(salesPerms.canExecute('shizuku.exec'), isFalse);
      expect(salesPerms.canExecute('android.tap'), isFalse);
    });

    test('BotPermissions: Personal Owner tiene acceso pleno a Linux y UI', () {
      final personalPerms = BotPermissions.personalOwner();

      expect(personalPerms.canExecute('linux.exec'), isTrue);
      expect(personalPerms.canExecute('linux.file.read'), isTrue);
      expect(personalPerms.canExecute('android.tap'), isTrue);
      expect(personalPerms.canExecute('browser.open'), isTrue);
    });

    test('BotCapabilityRouter: Solo autoriza herramientas de skills asignadas', () {
      final now = DateTime.now();
      final salesBot = BotDefinition(
        id: 'bot_sales_test',
        name: 'Ventas Test',
        role: BotRole.sales,
        skillIds: const ['skill_catalog', 'skill_whatsapp'],
        permissions: BotPermissions.salesRestricted(),
        createdAt: now,
        updatedAt: now,
      );

      final router = BotCapabilityRouter(bot: salesBot);

      expect(router.isAuthorized('catalog.search'), isTrue);
      expect(router.isAuthorized('whatsapp.send'), isTrue);
      // LinuxSkill no está en sus skillIds:
      expect(router.isAuthorized('linux.exec'), isFalse);
      // BrowserSkill no está en sus skillIds:
      expect(router.isAuthorized('browser.open'), isFalse);
    });

    test('BotEvent: Modela correctamente eventos de mensajes y archivos', () {
      final event = BotEvent(
        id: 'evt_1',
        type: BotEventType.document,
        channel: 'whatsapp',
        senderId: '573001234567',
        senderName: 'Carlos Gómez',
        payload: const {
          'filePath': '/storage/emulated/0/Download/pedidos.xlsx',
          'mimeType': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        },
        timestamp: DateTime.now(),
      );

      expect(event.type, equals(BotEventType.document));
      expect(event.filePath, contains('pedidos.xlsx'));
      expect(event.channel, equals('whatsapp'));
    });

    test('BotDefinition: Serialización y deserialización fidedigna', () {
      final now = DateTime.now();
      final bot = BotDefinition(
        id: 'bot_custom_1',
        name: 'Bot Asistente',
        role: BotRole.assistant,
        description: 'Automatiza reportes locales',
        channels: const ['whatsapp', 'telegram'],
        skillIds: const ['skill_linux', 'skill_browser'],
        permissions: BotPermissions.personalOwner(),
        policies: const {'seguridad': 'estricta'},
        createdAt: now,
        updatedAt: now,
      );

      final map = bot.toMap();
      final restored = BotDefinition.fromMap(map);

      expect(restored.id, equals(bot.id));
      expect(restored.name, equals(bot.name));
      expect(restored.role, equals(bot.role));
      expect(restored.channels, equals(bot.channels));
      expect(restored.skillIds, equals(bot.skillIds));
      expect(restored.permissions.allowLinuxExec, isTrue);
      expect(restored.policies['seguridad'], equals('estricta'));
    });
  });
}

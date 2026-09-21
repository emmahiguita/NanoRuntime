import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/bot/bot_definition.dart';
import 'package:nanoai/features/automation/domain/bot/bot_event.dart';
import 'package:nanoai/features/automation/domain/bot/bot_permissions.dart';
import 'package:nanoai/features/automation/domain/bot/bot_role.dart';
import 'package:nanoai/features/automation/engine/bot/bot_agent_dispatcher.dart';

void main() {
  group('Nano Bot Runtime — Ciclo Agéntico y Despachador (Fase 2)', () {
    final now = DateTime.now();

    final salesBot = BotDefinition(
      id: 'bot_sales_test',
      name: 'Ventas Test',
      role: BotRole.sales,
      channels: const ['whatsapp.business'],
      skillIds: const ['skill_catalog'],
      permissions: const BotPermissions(allowLinuxExec: false),
      createdAt: now,
      updatedAt: now,
    );

    test('BotAgentDispatcher: Rechaza eventos de canales no habilitados', () async {
      const dispatcher = BotAgentDispatcher();
      final event = BotEvent(
        id: 'ev_1',
        type: BotEventType.message,
        channel: 'telegram', // Canal no habilitado en salesBot
        senderId: '+12345678',
        timestamp: now,
      );

      final result = await dispatcher.dispatch(bot: salesBot, event: event);

      expect(result.isSuccess, isFalse);
      expect(result.responseMessage, contains('no tiene habilitado el canal telegram'));
    });

    test('BotAgentDispatcher: Ejecuta flujo conversacional respetando rol y tono', () async {
      const dispatcher = BotAgentDispatcher();
      final event = BotEvent(
        id: 'ev_2',
        type: BotEventType.message,
        channel: 'whatsapp.business',
        senderId: '+12345678',
        payload: {'text': '¿Tienen camisetas disponibles?'},
        timestamp: now,
      );

      final result = await dispatcher.dispatch(bot: salesBot, event: event);

      expect(result.isSuccess, isTrue);
      expect(result.responseMessage, contains('Ventas Test'));
      expect(result.responseMessage, contains('Ventas'));
      expect(result.executedTools, isEmpty);
    });

    test('BotAgentDispatcher: Bloquea herramientas no autorizadas por RBAC', () async {
      const dispatcher = BotAgentDispatcher();
      final event = BotEvent(
        id: 'ev_3',
        type: BotEventType.message,
        channel: 'whatsapp.business',
        senderId: '+12345678',
        payload: {
          'tool': 'linux.exec',
          'args': {'command': 'cat /etc/passwd'},
        },
        timestamp: now,
      );

      final result = await dispatcher.dispatch(bot: salesBot, event: event);

      expect(result.isSuccess, isFalse);
      expect(result.executedTools, contains('linux.exec'));
      expect(result.responseMessage, contains('No fue posible'));
    });
  });
}

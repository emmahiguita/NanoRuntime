/// WHATSAPP-WEB-DEDUP-TEST — Pruebas unitarias de deduplicación para WhatsApp Web.
///
/// **QUÉ HACE:**
/// Valida que la activación de WhatsApp Web en el Centro de Mensajería
/// no duplique tarjetas ni mezcle contactos homónimos persistidos.
///
/// **CÓMO FUNCIONA:**
/// Compara escenarios reales observados: nombres con formato LTR, sufijos de conteo,
/// coincidencias telefónicas y preservación de IDs canónicos nativos.
///
/// **POR QUÉ:**
/// Garantiza matemáticamente la estabilidad del hub ante el switch de WhatsApp Web (< 200 líneas).
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_conversation_identity.dart';
import 'package:nanoai/features/automation/presentation/messaging_center/messaging_dedup_merger.dart';

void main() {
  group('WhatsApp Web Hub Deduplication', () {
    test('Fusiona chat de WhatsApp Web con conversación previa de SQLite sin duplicar', () {
      final nativeSqlite = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/shortcut:120363405730761998@g.us',
        displayName: 'AcademiaKotlin',
        packageName: 'com.whatsapp',
        lastMessage: 'Mensaje desde app nativa',
        lastAtMs: 1000,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'personal',
        agentId: ConversationAgentId.personal,
        entryCount: 5,
        isGroup: true,
        groupTitle: 'AcademiaKotlin',
      );

      final waWebItem = ConversationSummaryItem(
        conversationId: 'waweb:academiakotlin',
        conversationAliases: const ['waweb:academiakotlin'],
        displayName: 'AcademiaKotlin',
        packageName: 'com.whatsapp',
        lastMessage: 'Último mensaje recibido en web',
        lastAtMs: 2000,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'WhatsApp Web',
        agentId: ConversationAgentId.personal,
        entryCount: 1,
        isGroup: true,
        groupTitle: 'AcademiaKotlin',
      );

      final result = MessagingDedupMerger.deduplicateAndSort([nativeSqlite, waWebItem]);

      expect(result.length, 1, reason: 'No debe haber 2 tarjetas para AcademiaKotlin');
      expect(result.first.displayName, 'AcademiaKotlin');
      expect(
        result.first.conversationId,
        'whatsapp/com.whatsapp/-/shortcut:120363405730761998@g.us',
        reason: 'Debe conservar el ID persistente de SQLite para retener acciones reales',
      );
      expect(result.first.lastMessage, 'Último mensaje recibido en web');
      expect(result.first.lastAtMs, 2000);
      expect(result.first.activeRole, 'personal');
    });

    test('Fusiona WhatsApp Web con historial que contiene marcas Unicode LTR y sufijos de conteo', () {
      final historyWithSuffix = ConversationSummaryItem(
        conversationId: 'history:e3b56d7b3951784cd830a1a7fdf2595a97699a76f66f5950c2c9179056164708',
        conversationAliases: const [
          'notification-history:e3b56d7b3951784cd830a1a7fdf2595a97699a76f66f5950c2c9179056164708',
        ],
        displayName: '\u200eviral en x (2 mensajes)',
        packageName: 'com.whatsapp',
        lastMessage: 'Hola grupo',
        lastAtMs: 500,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'historial local',
        agentId: ConversationAgentId.personal,
        entryCount: 2,
        isGroup: true,
        groupTitle: '\u200eviral en x (2 mensajes)',
      );

      final waWebGroup = ConversationSummaryItem(
        conversationId: 'waweb:viral-en-x',
        conversationAliases: const ['waweb:viral-en-x'],
        displayName: 'viral en x',
        packageName: 'com.whatsapp',
        lastMessage: 'Nuevo enlace',
        lastAtMs: 800,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'WhatsApp Web',
        agentId: ConversationAgentId.personal,
        entryCount: 1,
        isGroup: true,
        groupTitle: 'viral en x',
      );

      final result = MessagingDedupMerger.deduplicateAndSort([historyWithSuffix, waWebGroup]);

      expect(result.length, 1);
      expect(result.first.displayName, 'viral en x');
      expect(result.first.conversationId, 'history:e3b56d7b3951784cd830a1a7fdf2595a97699a76f66f5950c2c9179056164708');
      expect(result.first.lastMessage, 'Nuevo enlace');
    });

    test('Fusiona contactos con número telefónico formateado en WhatsApp Web y JID nativo', () {
      final nativePhone = ConversationSummaryItem(
        conversationId: '573105913746@s.whatsapp.net',
        displayName: '+57 310 591 3746',
        packageName: 'com.whatsapp',
        lastMessage: 'Audio recibido',
        lastAtMs: 300,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'personal',
        agentId: ConversationAgentId.personal,
        entryCount: 1,
      );

      final waWebPhone = ConversationSummaryItem(
        conversationId: 'waweb:57-310-591-3746',
        conversationAliases: const ['waweb:57-310-591-3746', 'phone:573105913746', '573105913746@s.whatsapp.net'],
        displayName: '+57 310 591 3746',
        packageName: 'com.whatsapp',
        lastMessage: 'Mensaje web',
        lastAtMs: 900,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'WhatsApp Web',
        agentId: ConversationAgentId.personal,
        entryCount: 1,
      );

      final result = MessagingDedupMerger.deduplicateAndSort([nativePhone, waWebPhone]);

      expect(result.length, 1);
      expect(result.first.conversationId, '573105913746@s.whatsapp.net');
      expect(result.first.lastMessage, 'Mensaje web');
    });

    test('No fusiona dos contactos homónimos persistidos con diferentes números', () {
      final contact1 = ConversationSummaryItem(
        conversationId: '573101111111@s.whatsapp.net',
        displayName: 'Carlos',
        packageName: 'com.whatsapp',
        lastMessage: 'Hola',
        lastAtMs: 100,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'personal',
        agentId: ConversationAgentId.personal,
        entryCount: 1,
      );

      final contact2 = ConversationSummaryItem(
        conversationId: '573202222222@s.whatsapp.net',
        displayName: 'Carlos',
        packageName: 'com.whatsapp',
        lastMessage: 'Buenas',
        lastAtMs: 200,
        hasPendingReply: false,
        humanOwns: true,
        activeRole: 'personal',
        agentId: ConversationAgentId.personal,
        entryCount: 1,
      );

      final result = MessagingDedupMerger.deduplicateAndSort([contact1, contact2]);

      expect(result.length, 2, reason: 'Contactos homónimos con diferente JID deben conservarse independientes');
    });
  });
}

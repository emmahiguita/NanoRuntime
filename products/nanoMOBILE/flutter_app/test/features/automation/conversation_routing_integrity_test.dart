import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_agent.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_hub_providers.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/executors/notification_executor.dart';

void main() {
  group('Conversation Notification Matching & Routing Integrity', () {
    final notifJord = DeviceNotification(
      key: '0|com.whatsapp|1|null|10270',
      packageName: 'com.whatsapp',
      title: 'J0rd! 🟩🦅🟥',
      text: '💟 Envió un sticker.',
      postedAt: DateTime.fromMillisecondsSinceEpoch(1789608156651),
      canReply: true,
      ongoing: false,
      sender: '', // Remitente vacío como en Android WhatsApp
      shortcutId: '117007894769767@lid',
      conversationId: '',
      senderKey: '',
    );

    final notifEmm = DeviceNotification(
      key: '0|com.whatsapp|1|JJltEbTiXTawBafiN6/ng8kkgGNV12/n928i2GWN85E=|10270',
      packageName: 'com.whatsapp',
      title: 'Emm',
      text: 'Cómo estás?',
      postedAt: DateTime.fromMillisecondsSinceEpoch(1789605945266),
      canReply: true,
      ongoing: false,
      sender: 'Emm',
      shortcutId: '243142846578833@lid',
      conversationId: '18636023784@s.whatsapp.net',
      senderKey: '18636023784@s.whatsapp.net',
    );

    test('Emm NUNCA coincide con la notificación de J0rd aunque sender esté vacío', () {
      final list = [notifJord];

      DeviceNotification? findMatch({
        required String convId,
        required String displayName,
        String? notificationKey,
      }) {
        final cleanConv = convId.trim();
        final cleanName = displayName.trim().toLowerCase();

        // 1. notificationKey exacta
        if (notificationKey != null && notificationKey.isNotEmpty) {
          for (final n in list) {
            if (n.canReply && n.key == notificationKey) return n;
          }
        }

        // 2. Identidad canónica
        if (cleanConv.isNotEmpty) {
          for (final n in list) {
            if (!n.canReply) continue;
            final nId = resolveConversationIdentity(n.toNotificationObject()).key.id;
            if (nId.isNotEmpty && nId == cleanConv) return n;
          }
        }

        // 3. shortcutId / senderKey / convId
        if (cleanConv.isNotEmpty) {
          for (final n in list) {
            if (!n.canReply) continue;
            if (n.shortcutId.isNotEmpty &&
                (cleanConv == n.shortcutId ||
                    cleanConv.contains('shortcut:${n.shortcutId}') ||
                    cleanConv.endsWith(n.shortcutId))) {
              return n;
            }
          }
        }

        // 4. Dígitos telefónicos (mínimo 7)
        final targetDigits = RegExp(r'\d{7,15}').firstMatch(cleanConv)?.group(0) ??
            RegExp(r'\d{7,15}').firstMatch(cleanName)?.group(0);

        if (targetDigits != null && targetDigits.length >= 7) {
          for (final n in list) {
            if (!n.canReply) continue;
            for (final cand in [n.conversationId, n.senderKey, n.shortcutId, n.title]) {
              final nDigits = RegExp(r'\d{7,15}').firstMatch(cand)?.group(0);
              if (nDigits != null && nDigits.length >= 7) {
                if (targetDigits == nDigits ||
                    targetDigits.endsWith(nDigits) ||
                    nDigits.endsWith(targetDigits)) {
                  return n;
                }
              }
            }
          }
        }

        // 5. Nombre exacto
        final isGeneric = cleanName.isEmpty ||
            cleanName.startsWith('contacto whatsapp') ||
            cleanName.startsWith('chat de whatsapp') ||
            cleanName == 'whatsapp' ||
            cleanName.length < 3;

        if (!isGeneric) {
          for (final n in list) {
            if (!n.canReply) continue;
            final nTitle = n.title.trim().toLowerCase();
            final nSender = n.sender.trim().toLowerCase();
            if (nTitle == cleanName || (nSender.isNotEmpty && nSender == cleanName)) {
              return n;
            }
          }
        }

        return null;
      }

      final matchConvId = findMatch(
        convId: 'whatsapp/com.whatsapp/-/shortcut:243142846578833@lid',
        displayName: 'Emm',
      );
      expect(matchConvId, isNull, reason: 'Emm no debe coincidir con J0rd!');

      final matchJid = findMatch(
        convId: '18636023784@s.whatsapp.net',
        displayName: 'Emm',
      );
      expect(matchJid, isNull, reason: 'El número 18636023784 no debe coincidir con J0rd!');
    });

    test('Emm coincide exactamente con la notificación de Emm cuando ambas están activas', () {
      final list = [notifJord, notifEmm];

      DeviceNotification? findMatch({
        required String convId,
        required String displayName,
        String? notificationKey,
      }) {
        final cleanConv = convId.trim();
        final cleanName = displayName.trim().toLowerCase();

        if (notificationKey != null && notificationKey.isNotEmpty) {
          for (final n in list) {
            if (n.canReply && n.key == notificationKey) return n;
          }
        }

        if (cleanConv.isNotEmpty) {
          for (final n in list) {
            if (!n.canReply) continue;
            final nId = resolveConversationIdentity(n.toNotificationObject()).key.id;
            if (nId.isNotEmpty && nId == cleanConv) return n;
          }
        }

        if (cleanConv.isNotEmpty) {
          for (final n in list) {
            if (!n.canReply) continue;
            if (n.shortcutId.isNotEmpty &&
                (cleanConv == n.shortcutId ||
                    cleanConv.contains('shortcut:${n.shortcutId}') ||
                    cleanConv.endsWith(n.shortcutId))) {
              return n;
            }
          }
        }

        final targetDigits = RegExp(r'\d{7,15}').firstMatch(cleanConv)?.group(0) ??
            RegExp(r'\d{7,15}').firstMatch(cleanName)?.group(0);

        if (targetDigits != null && targetDigits.length >= 7) {
          for (final n in list) {
            if (!n.canReply) continue;
            for (final cand in [n.conversationId, n.senderKey, n.shortcutId, n.title]) {
              final nDigits = RegExp(r'\d{7,15}').firstMatch(cand)?.group(0);
              if (nDigits != null && nDigits.length >= 7) {
                if (targetDigits == nDigits ||
                    targetDigits.endsWith(nDigits) ||
                    nDigits.endsWith(targetDigits)) {
                  return n;
                }
              }
            }
          }
        }

        final isGeneric = cleanName.isEmpty ||
            cleanName.startsWith('contacto whatsapp') ||
            cleanName.startsWith('chat de whatsapp') ||
            cleanName == 'whatsapp' ||
            cleanName.length < 3;

        if (!isGeneric) {
          for (final n in list) {
            if (!n.canReply) continue;
            final nTitle = n.title.trim().toLowerCase();
            final nSender = n.sender.trim().toLowerCase();
            if (nTitle == cleanName || (nSender.isNotEmpty && nSender == cleanName)) {
              return n;
            }
          }
        }

        return null;
      }

      final matched = findMatch(
        convId: 'whatsapp/com.whatsapp/-/shortcut:243142846578833@lid',
        displayName: 'Emm',
      );

      expect(matched, isNotNull);
      expect(matched!.title, 'Emm');
      expect(matched.shortcutId, '243142846578833@lid');
      expect(matched.key, notifEmm.key);
    });

    test('ConversationSummaryItem preserva notificationKey para matching directo O(1)', () {
      const item = ConversationSummaryItem(
        conversationId: 'whatsapp/com.whatsapp/-/shortcut:243142846578833@lid',
        displayName: 'Emm',
        lastMessage: 'Cómo estás?',
        lastAtMs: 1789605945266,
        agentId: ConversationAgentId.personal,
        notificationKey: '0|com.whatsapp|1|JJltEbTiXTawBafiN6/ng8kkgGNV12/n928i2GWN85E=|10270',
      );

      expect(item.notificationKey, isNotNull);
      expect(item.notificationKey, contains('JJltEbTiXTawBafiN6'));
    });
  });
}

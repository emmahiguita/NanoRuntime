import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/messaging/conversation_key.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/engine/scheduling/burst_turn_gate.dart';
import 'package:nanoai/features/automation/engine/scheduling/rule_dispatcher.dart';

NotificationObject telegramMessage({
  required String chatId,
  required String sender,
  required String text,
  required int timestamp,
}) => NotificationObject(
  key: 'telegram:$chatId:$timestamp',
  packageName: 'org.telegram.messenger',
  title: sender,
  text: text,
  messageText: text,
  messageTimestamp: timestamp,
  sender: sender,
  senderKey: sender,
  senderUri: '',
  conversationTitle: sender,
  conversationId: chatId,
  shortcutId: chatId,
  locusId: '',
  accountHint: '',
  isGroup: false,
  isSummary: false,
  postTime: timestamp,
  canReply: true,
  remoteInputKey: 'reply',
  actionIndex: 0,
  actions: const ['Responder'],
  ongoing: false,
);

void main() {
  test('Telegram conserva una identidad estable y separada por chat', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ana = telegramMessage(
      chatId: 'chat-ana',
      sender: 'Ana',
      text: 'Hola',
      timestamp: now,
    );
    final bruno = telegramMessage(
      chatId: 'chat-bruno',
      sender: 'Bruno',
      text: 'Hola',
      timestamp: now,
    );

    final anaId = resolveConversationIdentity(ana).key.id;
    final brunoId = resolveConversationIdentity(bruno).key.id;
    expect(anaId, isNotEmpty);
    expect(brunoId, isNotEmpty);
    expect(anaId, isNot(brunoId));
    expect(anaId, contains('telegram'));
  });

  test(
    'Nano Personal avanza dos conversaciones sin cruzar sus turnos',
    () async {
      final gate = BurstTurnGate(
        settle: const Duration(milliseconds: 5),
        maxWait: const Duration(milliseconds: 50),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final processed = <String, String>{};

      Future<List<RuleDispatchResult>> runTurn(NotificationObject turn) async {
        if (turn.conversationId == 'chat-ana') {
          firstStarted.complete();
          await releaseFirst.future;
        }
        processed[turn.conversationId] = turn.messageText;
        return const [
          RuleDispatchResult(
            ruleId: 'personal',
            outcome: RuleOutcome.replyVerified,
          ),
        ];
      }

      final anaFuture = gate.submit(
        telegramMessage(
          chatId: 'chat-ana',
          sender: 'Ana',
          text: 'Mensaje de Ana',
          timestamp: now,
        ),
        runTurn,
      );
      await firstStarted.future;
      final brunoFuture = gate.submit(
        telegramMessage(
          chatId: 'chat-bruno',
          sender: 'Bruno',
          text: 'Mensaje de Bruno',
          timestamp: now + 1,
        ),
        runTurn,
      );

      await brunoFuture.timeout(const Duration(seconds: 1));
      expect(processed['chat-bruno'], 'Mensaje de Bruno');
      expect(processed.containsKey('chat-ana'), isFalse);

      releaseFirst.complete();
      await anaFuture;
      expect(processed, {
        'chat-bruno': 'Mensaje de Bruno',
        'chat-ana': 'Mensaje de Ana',
      });
      gate.dispose();
    },
  );
}

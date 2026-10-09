/// QUÉ HACE:
/// Enruta deterministamente turnos de mensajería en lenguaje natural hacia
/// las herramientas reales de envío y apertura de chats (WhatsApp, Telegram, Messenger).
///
/// CÓMO FUNCIONA:
/// Analiza sintáctica y semánticamente la intención mediante [WhatsAppIntentParser] y
/// [MessageIntentParser], generando el [ToolCall] correspondiente e invocando
/// [AutomationCoordinator.execute] para despachar la acción en la app real.
///
/// POR QUÉ:
/// Evita que las órdenes de mensajería queden atrapadas como texto conversacional
/// en la ventana de Nano, asegurando que se envíen de forma verificable al destino.
library;

import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/planning/message_intent_parser.dart';
import 'package:nanoai/features/automation/engine/planning/whatsapp_intent_parser.dart';

import '../../../core/models/chat_models.dart';
import '../domain/chat_turn_route_result.dart';

class ChatMessagingTurnRouter {
  const ChatMessagingTurnRouter();

  Future<ChatTurnRouteResult?> tryRoute({
    required String text,
    required AutomationCoordinator coordinator,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();
    final isTg = lower.contains('telegram') || lower.contains(' tg ');
    final isFb = lower.contains('messenger') ||
        lower.contains('facebook') ||
        lower.contains(' fb ');
    final isWa = lower.contains('whatsapp') || lower.contains(' wpp ');

    ToolCall? call;

    if (isTg) {
      final msgIntent = const MessageIntentParser().parse(clean);
      final recipient = msgIntent.recipient.isNotEmpty
          ? msgIntent.recipient
          : _extractTargetFallback(clean);
      if (recipient.isNotEmpty) {
        call = msgIntent.message.isNotEmpty
            ? ToolCall(
                tool: 'telegram.send_message',
                args: {
                  'contact': recipient,
                  'text': msgIntent.message,
                  'autoSend': true,
                },
              )
            : ToolCall(
                tool: 'telegram.open_chat',
                args: {'contact': recipient},
              );
      }
    } else if (isFb) {
      final msgIntent = const MessageIntentParser().parse(clean);
      final recipient = msgIntent.recipient.isNotEmpty
          ? msgIntent.recipient
          : _extractTargetFallback(clean);
      if (recipient.isNotEmpty) {
        call = msgIntent.message.isNotEmpty
            ? ToolCall(
                tool: 'messenger.send_message',
                args: {
                  'contact': recipient,
                  'text': msgIntent.message,
                  'autoSend': true,
                },
              )
            : ToolCall(
                tool: 'messenger.open_chat',
                args: {'contact': recipient},
              );
      }
    } else {
      // WhatsApp o mensajería general
      final waIntent = WhatsAppIntentParser.parse(clean);
      if (waIntent != null && waIntent.contact.isNotEmpty) {
        call = switch (waIntent.action) {
          WhatsAppAction.shareFile => ToolCall(
              tool: 'whatsapp.share_file',
              args: {
                'contact': waIntent.contact,
                if (waIntent.filePath != null) 'path': waIntent.filePath!,
                if (waIntent.message != null) 'caption': waIntent.message!,
              },
            ),
          WhatsAppAction.sendMessage => ToolCall(
              tool: 'whatsapp.send_message',
              args: {
                'contact': waIntent.contact,
                'text': waIntent.message ?? '',
                'autoSend': true,
              },
            ),
          WhatsAppAction.openChat => ToolCall(
              tool: 'whatsapp.open_chat',
              args: {'contact': waIntent.contact},
            ),
          WhatsAppAction.findContact => ToolCall(
              tool: 'whatsapp.contacts',
              args: {'query': waIntent.contact},
            ),
        };
      } else {
        final msgIntent = const MessageIntentParser().parse(clean);
        if (msgIntent.recipient.isNotEmpty &&
            (msgIntent.message.isNotEmpty || isWa)) {
          call = msgIntent.message.isNotEmpty
              ? ToolCall(
                  tool: 'whatsapp.send_message',
                  args: {
                    'contact': msgIntent.recipient,
                    'text': msgIntent.message,
                    'autoSend': true,
                  },
                )
              : ToolCall(
                  tool: 'whatsapp.open_chat',
                  args: {'contact': msgIntent.recipient},
                );
        }
      }
    }

    if (call == null) return null;

    final result = await coordinator.execute(
      AutomationGoal(text: clean),
      plan: [call],
    );

    if (result.isPaused && result.confirmation != null) {
      return ChatTurnRouteResult.pausePlan(
        plan: [call],
        pauseIndex: result.pauseIndex,
        confirmation: result.confirmation,
        pauseTool: result.pauseTool,
        pauseDescription: automationUserFacingReason(result.reason),
      );
    }

    return ChatTurnRouteResult.completed(
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: automationUserFacingReason(result.reason),
        timestamp: DateTime.now(),
        status: result.isVerifiedSuccess ? MessageStatus.sent : MessageStatus.error,
        source: MessageSource.device,
      ),
    );
  }

  String _extractTargetFallback(String text) {
    final m = RegExp(
      r'(?:a|para|con)\s+([A-Za-z0-9_@+]+)',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1)?.trim() ?? '';
  }
}

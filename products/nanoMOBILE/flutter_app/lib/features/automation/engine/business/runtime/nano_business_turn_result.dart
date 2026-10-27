// Resultado de composición: no acredita envío ni transferencia a una persona.
import '../state/commercial_conversation_state.dart';
import '../../messaging/core/nano_outgoing_message.dart';

final class NanoBusinessTurnResult {
  final String replyText;
  final bool isEscalatedToHuman;
  final bool requiresConfirmation;
  final bool isDuplicate;
  final String? escalatedReason;
  final List<String> suggestions;
  final CommercialConversationState updatedState;
  final NanoOutgoingMessage? outgoingMessage;

  const NanoBusinessTurnResult({
    required this.replyText,
    this.isEscalatedToHuman = false,
    this.requiresConfirmation = false,
    this.isDuplicate = false,
    this.escalatedReason,
    this.suggestions = const [],
    required this.updatedState,
    this.outgoingMessage,
  });
}

import '../../../core/models/chat_models.dart';
import 'chat_memory_index.dart';

/// Keeps short well-being replies connected to the immediate Chat dialogue.
class ChatSocialReplyResolver {
  const ChatSocialReplyResolver();

  ChatMessage? resolve(String input, List<ChatMessage> messages) {
    final normalized = ChatMemoryIndex.normalizeText(input);
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty || words.length > 6) return null;

    final currentIndex = messages.lastIndexWhere(
      (message) =>
          message.sender == MessageSender.user &&
          message.text.trim() == input.trim(),
    );
    final previousIndex = currentIndex >= 0
        ? currentIndex - 1
        : messages.length - 1;
    if (previousIndex < 0) return null;
    final previousAssistant = messages[previousIndex];
    if (previousAssistant.sender != MessageSender.ai ||
        previousAssistant.status == MessageStatus.error ||
        !_asksHowUserIs(
          ChatMemoryIndex.normalizeText(previousAssistant.text),
        )) {
      return null;
    }

    final moodText = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final negativeMood = RegExp(
      r'^(?:(?:estoy|me siento)\s+)?(?:muy\s+|bastante\s+)?(?:no estoy bien|mal|triste|cansado|cansada|agotado|agotada|preocupado|preocupada|dificil)(?:\s+(?:muchas gracias|gracias))?$',
    ).hasMatch(moodText);
    if (negativeMood) {
      return _reply(
        'Siento que estés pasando por eso. Si quieres, cuéntame un poco más; '
        'también podemos hablar de otra cosa.',
        const ['Quiero contarte', 'Dame un consejo', 'Prefiero distraerme'],
      );
    }

    final positiveMood = RegExp(
      r'^(?:(?:estoy|me siento)\s+)?(?:muy\s+|bastante\s+)?(?:bien|genial|excelente|feliz|tranquilo|tranquila|estupendo|super)(?:\s+(?:muchas gracias|gracias))?$',
    ).hasMatch(moodText);
    if (positiveMood) {
      return _reply('¡Me alegra! ¿Qué tienes en mente hoy?', const [
        'Quiero conversar un rato',
        'Tengo una pregunta',
        'Ayúdame con algo',
      ]);
    }

    final neutralMood = RegExp(
      r'^(?:(?:estoy|me siento)\s+)?(?:mas o menos|regular|normal|ahi voy|ahi vamos|tirando)(?:\s+(?:muchas gracias|gracias))?$',
    ).hasMatch(moodText);
    if (!neutralMood) return null;
    return _reply('Gracias por contármelo. ¿Qué te gustaría conversar?', const [
      'Quiero conversar',
      'Tengo una pregunta',
      'Necesito ayuda',
    ]);
  }

  bool _asksHowUserIs(String text) => RegExp(
    r'\b(como estas|como te va|como va tu dia|que tal estas|como te sientes)\b',
  ).hasMatch(text);

  ChatMessage _reply(String text, List<String> suggestions) => ChatMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sender: MessageSender.ai,
    text: text,
    timestamp: DateTime.now(),
    suggestions: suggestions,
    source: MessageSource.device,
    status: MessageStatus.sent,
  );
}

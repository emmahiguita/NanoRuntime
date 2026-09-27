import '../../../core/models/chat_models.dart';
import 'chat_memory_index.dart';

/// User-facing memory commands backed by Chat's persisted transcript.
class ChatMemoryTools {
  final ChatMemoryIndex _index;

  const ChatMemoryTools({ChatMemoryIndex index = const ChatMemoryIndex()})
    : _index = index;

  bool isMemoryCommand(String input) {
    final normalized = ChatMemoryIndex.normalizeText(input);
    return _rememberedFact(input) != null ||
        _isMemoryHelp(normalized) ||
        _isRecallRequest(normalized);
  }

  /// Handles explicit memory requests. [history] excludes the current turn.
  ChatMessage? resolveCommand({
    required String input,
    required List<ChatMessage> history,
  }) {
    final normalized = ChatMemoryIndex.normalizeText(input);
    final fact = _rememberedFact(input);
    if (fact != null) {
      return _reply(
        'Lo tendré presente en este chat: «${_clip(fact, 500)}». '
        'Puedes pedirme “¿qué recuerdas sobre …?” y buscaré en el historial real.',
        const [
          '¿Qué recuerdas de este chat?',
          'Seguir conversando',
          'Cambiar de tema',
        ],
      );
    }

    if (_isMemoryHelp(normalized)) {
      return _reply(
        'La memoria de Chat usa los mensajes guardados de esta conversación. '
        'Puedes decir “Recuerda que …” para dejar algo en el historial, '
        '“¿Qué te dije sobre …?” para recuperarlo, o “¿Qué recuerdas?” para '
        'ver los temas recientes. Al borrar el historial del chat también se borra esta memoria.',
        const [
          'Recuerda que prefiero respuestas breves',
          '¿Qué recuerdas?',
          'Buscar en este chat',
        ],
      );
    }

    if (!_isRecallRequest(normalized)) return null;
    final query = _recallQuery(normalized);
    final assistantReply = RegExp(
      r'\b(respondiste|me dijiste|tu respuesta)\b',
    ).hasMatch(normalized);
    final preferredSpeaker = assistantReply
        ? MessageSender.ai
        : MessageSender.user;
    var matches = _index.search(history, query, speaker: preferredSpeaker);
    if (matches.isEmpty && !assistantReply) {
      matches = _index.search(history, query);
    }

    if (matches.isEmpty) {
      return _reply(
        query.isEmpty
            ? 'Todavía no encuentro mensajes anteriores en este chat.'
            : 'No encuentro ese tema en el historial de este chat. Si me lo cuentas, '
                  'quedará guardado aquí para poder retomarlo.',
        const ['¿Qué recuerdas?', 'Recuerda que …', 'Seguir conversando'],
      );
    }

    final lines = matches
        .take(3)
        .map((message) {
          final speaker = message.sender == MessageSender.user ? 'Tú' : 'Nano';
          return '• $speaker: «${_clip(message.text.trim(), 260)}»';
        })
        .join('\n');
    return _reply('En el historial real de este chat encontré:\n$lines', const [
      'Buscar otra cosa',
      '¿Qué más recuerdas?',
      'Seguir conversando',
    ]);
  }

  String contextFor(List<ChatMessage> history, String currentText) =>
      _index.contextFor(history, currentText);

  String? _rememberedFact(String input) {
    final match = RegExp(
      r'^\s*(?:por favor\s+)?(?:recuerda\s+que|recuerda\s+esto|ten\s+presente\s+que|anota\s+que|guarda\s+en\s+(?:la\s+)?memoria(?:\s+que)?)\s*[:,-]?\s*(.+?)\s*[.!?]*\s*$',
      caseSensitive: false,
    ).firstMatch(input);
    final fact = match?.group(1)?.trim();
    return fact == null || fact.isEmpty ? null : fact;
  }

  bool _isRecallRequest(String text) => RegExp(
    r'\b(que recuerdas|que te dije|que me dijiste|que me respondiste|te acuerdas|recuerdas cuando|que hablamos|que conversamos|busca en (el )?(chat|historial|conversacion)|busca (en )?este chat|historial de este chat)\b',
  ).hasMatch(text);

  bool _isMemoryHelp(String text) => RegExp(
    r'\b(como (funciona|uso|puedo usar) (tu )?memoria|como te pido que recuerdes|herramientas de memoria)\b',
  ).hasMatch(text);

  String _recallQuery(String text) {
    var query = text;
    for (final phrase in const [
      'que te dije',
      'que me dijiste',
      'que me respondiste',
      'que recuerdas',
      'recuerdas cuando',
      'te acuerdas',
      'que hablamos',
      'que conversamos',
      'busca en el chat',
      'busca en este chat',
      'busca en el historial',
      'busca en la conversacion',
      'historial de este chat',
      'sobre',
      'acerca de',
    ]) {
      query = query.replaceAll(phrase, ' ');
    }
    return query;
  }

  ChatMessage _reply(String text, List<String> suggestions) => ChatMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sender: MessageSender.ai,
    text: text,
    timestamp: DateTime.now(),
    suggestions: suggestions,
    source: MessageSource.device,
    status: MessageStatus.sent,
  );

  String _clip(String value, int maxChars) => value.length <= maxChars
      ? value
      : '${value.substring(0, maxChars).trimRight()}…';
}

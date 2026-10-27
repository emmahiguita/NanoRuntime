import '../../../core/models/chat_models.dart';

/// Retrieves relevant messages from Chat's persisted transcript.
class ChatMemoryIndex {
  const ChatMemoryIndex();

  static const _stopWords = <String>{
    'que',
    'como',
    'cuando',
    'donde',
    'cual',
    'quien',
    'por',
    'para',
    'sobre',
    'acerca',
    'dije',
    'dijiste',
    'dijimos',
    'recuerdo',
    'recuerdas',
    'recordar',
    'recuerda',
    'acuerdas',
    'acuerdo',
    'hablamos',
    'conversamos',
    'chat',
    'historial',
    'conversacion',
    'antes',
    'esto',
    'eso',
    'aquello',
    'algo',
    'una',
    'uno',
    'unas',
    'unos',
    'las',
    'los',
    'del',
    'con',
    'sin',
    'mi',
    'mis',
    'me',
    'te',
    'tu',
    'tus',
    'yo',
    'era',
    'fue',
    'son',
    'estaba',
    'este',
    'esta',
    'estos',
    'estas',
    'mas',
  };

  /// Searches the full Chat transcript. A blank query returns the newest
  /// messages, optionally limited to one speaker.
  List<ChatMessage> search(
    List<ChatMessage> history,
    String query, {
    int limit = 3,
    MessageSender? speaker,
  }) {
    final terms = _keywords(normalizeText(query));
    final candidates = <({ChatMessage message, int score, int index})>[];
    for (var i = 0; i < history.length; i++) {
      final message = history[i];
      if (message.status == MessageStatus.error ||
          message.text.trim().isEmpty ||
          (speaker != null && message.sender != speaker)) {
        continue;
      }
      final tokens = _keywords(normalizeText(message.text)).toSet();
      final matches = terms.where(tokens.contains).length;
      if (terms.isNotEmpty && matches == 0) continue;
      final coverage = terms.isEmpty ? 0 : matches * 100 ~/ terms.length;
      final score = coverage + (message.sender == MessageSender.user ? 15 : 0);
      candidates.add((message: message, score: score, index: i));
    }
    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.index.compareTo(a.index);
    });
    return candidates.take(limit).map((item) => item.message).toList();
  }

  /// Adds a few relevant, verbatim past turns, including turns outside the
  /// model's recent prompt window.
  String contextFor(List<ChatMessage> history, String currentText) {
    final query = normalizeText(currentText);
    if (_keywords(query).isEmpty || history.isEmpty) return '';
    final matches = search(history, query);
    if (matches.isEmpty) return '';
    return matches
        .map((message) {
          final speaker = message.sender == MessageSender.user
              ? 'Usuario'
              : 'Nano';
          return '$speaker dijo: «${_clip(message.text.trim(), 240)}»';
        })
        .join('\n');
  }

  static String normalizeText(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<String> _keywords(String text) => text
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.length > 2 && !_stopWords.contains(word))
      .map(_singularize)
      .toList();

  String _singularize(String word) {
    if (word.length > 5 && word.endsWith('es')) {
      return word.substring(0, word.length - 2);
    }
    if (word.length > 4 && word.endsWith('s')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  String _clip(String value, int maxChars) => value.length <= maxChars
      ? value
      : '${value.substring(0, maxChars).trimRight()}…';
}

/// Participación en grupos, independiente del modelo y de los chats privados.
abstract final class GroupMentionPolicy {
  static bool allows({
    required bool isGroup,
    required String text,
    required String ownerName,
    String nickname = '',
    String aliases = '',
  }) {
    if (!isGroup) return true;
    final labels = {ownerName, nickname, ...aliases.split(RegExp(r'[,;\n]'))}
        .map((label) => _fold(label.trim().replaceFirst(RegExp(r'^@'), '')))
        .where((label) => label.isNotEmpty)
        .toSet();
    final message = _fold(text);
    for (final label in labels) {
      // Un @cualquiera o un correo no equivalen a mencionar al dueño.
      final pattern = RegExp(
        r'(^|[^\p{L}\p{N}_@])@' +
            RegExp.escape(label) +
            r'(?=$|[^\p{L}\p{N}_])',
        unicode: true,
      );
      if (pattern.hasMatch(message)) return true;
    }
    return false;
  }

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

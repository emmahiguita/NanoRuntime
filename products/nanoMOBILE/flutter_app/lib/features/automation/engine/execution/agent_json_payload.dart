/// Extrae JSON completo respetando cadenas y escapes, sin reconstruir argumentos.
/// Una respuesta incompleta queda como texto para que el llamador pueda corregirla.
abstract final class AgentJsonPayload {
  static String? extract(String text) {
    var source = text.trim();
    if (source.startsWith('```')) {
      final newline = source.indexOf('\n');
      if (newline < 0) return null;
      source = source.substring(newline + 1).trim();
    }
    var start = -1;
    for (var i = 0; i < source.length && i <= 50; i++) {
      if (source[i] == '{' || source[i] == '[') {
        start = i;
        break;
      }
    }
    if (start < 0 || source.length > 1024 * 1024) return null;
    final stack = <String>[];
    var quoted = false;
    var escaped = false;
    for (var i = start; i < source.length; i++) {
      final c = source[i];
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          quoted = false;
        }
        continue;
      }
      if (c == '"') {
        quoted = true;
        continue;
      }
      if (c == '{' || c == '[') {
        stack.add(c);
        continue;
      }
      if (c == '}' || c == ']') {
        if (stack.isEmpty) return null;
        final open = stack.removeLast();
        if ((c == '}' && open != '{') || (c == ']' && open != '[')) return null;
        if (stack.isEmpty) return source.substring(start, i + 1);
      }
    }
    return null;
  }
}

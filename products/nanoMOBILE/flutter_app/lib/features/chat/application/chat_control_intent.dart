/// Reconoce órdenes breves que deben detener la tarea activa sin invocar al LLM.
class ChatControlIntent {
  const ChatControlIntent._();

  static const _cancelCommands = <String>{
    'para',
    'para ya',
    'parate',
    'parate ya',
    'deten',
    'deten ya',
    'detente',
    'detente ya',
    'cancela',
    'cancela ya',
    'cancelalo',
    'cancelar',
    'stop',
    'alto',
    'espera',
    'espera ya',
    'espera un momento',
    'no sigas',
  };

  static const _cancelReplies = <String>[
    'Entendido, detengo lo que estaba haciendo.',
    'Listo, cancelé la tarea. ¿Quieres que sigamos con otra cosa?',
    'De acuerdo, me detengo aquí.',
  ];

  static bool isCancellation(String text) {
    var normalized = _normalize(text);
    normalized = normalized.replaceFirst(RegExp(r'^por favor\s+'), '');
    normalized = normalized.replaceFirst(RegExp(r'\s+por favor$'), '');
    return _cancelCommands.contains(normalized);
  }

  static String cancellationReply(String text) {
    final normalized = _normalize(text);
    final fingerprint = normalized.codeUnits.fold<int>(
      0,
      (sum, unit) => sum + unit,
    );
    return _cancelReplies[fingerprint % _cancelReplies.length];
  }

  static String _normalize(String text) => text
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[¡!¿?.,;:]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

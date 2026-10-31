/// Orden literal al chat visible. El destino nunca se resuelve en la agenda
/// y las palabras del mensaje no seleccionan aplicaciones ni archivos.
final class WhatsAppCurrentChatRequest {
  const WhatsAppCurrentChatRequest._(this.text, {required this.draftOnly});

  final String text;
  final bool draftOnly;

  static const _chat =
      r'(?:este\s+chat|el\s+chat(?:\s+actual)?|la\s+conversaci[oó]n(?:\s+actual)?|aqu[íi])';

  /// Acepta «escribe hola en este chat», «escribe en este chat: hola», «escribe hola»,
  /// «envía en este chat hola» y «responde aquí: hola».
  /// Escribir prepara el borrador; enviar/responder autoriza el envío al chat observado.
  static WhatsAppCurrentChatRequest? parse(String instruction) {
    final verb = RegExp(
      r'^(escribe|env[ií]a|responde|contesta)\s+(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(instruction.trim());
    if (verb == null) return null;
    final draftOnly = verb[1]!.toLowerCase() == 'escribe';
    final body = verb[2]!.trim();

    // 1. Prefijo explícito de chat actual: «en este chat hola», «a este chat: hola», «aquí hola»
    final prefix = RegExp(
      '^(?:(?:en|a)\\s+)?$_chat(?:\\s*:\\s*|\\s+)(.*)\$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);
    if (prefix != null) return _literal(prefix[1], draftOnly);

    // 2. Sufijo explícito de chat actual: «hola en este chat», «hola aquí»
    final suffix = RegExp(
      '^(.*?)\\s+(?:en|a)\\s+$_chat\\s*\$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(body);
    if (suffix != null) return _literal(suffix[1], draftOnly);

    // 3. Excluir si la orden va dirigida explícitamente a otro contacto o número:
    // «a Juan», «al número ...», «a este número ...», «con María»
    final hasExplicitRecipient = RegExp(
      r'^(?:a\s+|al\s+|con\s+|para\s+)(?!' + _chat + r'\b)',
      caseSensitive: false,
    ).hasMatch(body);
    if (hasExplicitRecipient) return null;

    // 4. Si es «escribe ...», «envía ...», «responde ...» sin destinatario externo:
    // e.g. «escribe hola», «envía gracias», se asume contexto del chat visible.
    return _literal(body, draftOnly);
  }

  /// Conserva el contenido interior exacto.
  /// Solo elimina espacio exterior; jamás genera un mensaje faltante.
  static WhatsAppCurrentChatRequest _literal(String? value, bool draftOnly) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      throw const FormatException(
        'Falta el mensaje. Escribe, por ejemplo: Escribe en este chat: hola.',
      );
    }
    return WhatsAppCurrentChatRequest._(text, draftOnly: draftOnly);
  }
}

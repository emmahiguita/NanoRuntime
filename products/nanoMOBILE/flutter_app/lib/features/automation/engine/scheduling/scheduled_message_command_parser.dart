/// Parser determinista para mensajes salientes programados.
///
/// Sintaxis soportada:
/// - `mándale a Emm: Hola`
/// - `envíales a Emm, Juan y +573001112233: Hola`
/// - `envía a (María José), (Juan Pérez) el mensaje: Llegaré tarde`
library;

final class ScheduledMessageCommand {
  final List<String> recipients;
  final String message;

  const ScheduledMessageCommand({
    required this.recipients,
    required this.message,
  });
}

abstract final class ScheduledMessageCommandParser {
  static final _verb = RegExp(
    r'^(?:env[ií]a(?:le|les)?|manda(?:le|les)?|m[aá]nda(?:le|les)?|escr[ií]be(?:le|les)?)\s+',
    caseSensitive: false,
  );
  static final _leadingMessage = RegExp(
    r'^(?:un\s+)?mensaje\s+(?:de\s+whatsapp\s+)?',
    caseSensitive: false,
  );
  static final _leadingTo = RegExp(r'^a\s+', caseSensitive: false);
  static final _messageSeparator = RegExp(
    r'\s+(?:el\s+)?mensaje\s*:\s*|\s+que\s+diga\s+|\s+diciendo\s+|\s*:\s*',
    caseSensitive: false,
  );
  static final _parenthesized = RegExp(r'\(([^()]+)\)');

  static ScheduledMessageCommand? parse(String input) {
    var rest = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    final verb = _verb.firstMatch(rest);
    if (verb == null) return null;
    rest = rest.substring(verb.end).trim();
    rest = rest.replaceFirst(_leadingMessage, '').trim();
    rest = rest.replaceFirst(_leadingTo, '').trim();

    final separator = _messageSeparator.firstMatch(rest);
    if (separator == null) return null;
    final rawRecipients = rest.substring(0, separator.start).trim();
    final message = rest.substring(separator.end).trim();
    if (rawRecipients.isEmpty || message.isEmpty) return null;

    final parenthesized = _parenthesized
        .allMatches(rawRecipients)
        .map((match) => match.group(1)!.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final recipients = parenthesized.isNotEmpty
        ? parenthesized
        : rawRecipients
              .split(RegExp(r'\s*(?:,|;|\s+y\s+)\s*', caseSensitive: false))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
    if (recipients.isEmpty || recipients.length > 50) return null;
    return ScheduledMessageCommand(recipients: recipients, message: message);
  }
}

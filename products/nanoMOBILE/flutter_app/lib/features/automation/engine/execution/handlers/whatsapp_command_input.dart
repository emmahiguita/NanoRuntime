/// Separa identidad y contenido sin truncar nombres entre comillas ni alterar
/// espacios del mensaje. Un @usuario nunca se convierte en teléfono por sus dígitos.
final class WhatsAppCommandInput {
  const WhatsAppCommandInput(this.contact, this.message);
  final String contact;
  final String message;

  static bool isUsername(String text) =>
      RegExp(r'^@[A-Za-z0-9._]{3,35}$').hasMatch(text) &&
      RegExp(r'[A-Za-z]').hasMatch(text);

  static WhatsAppCommandInput? parse(String input) {
    final match = RegExp(
      r"""^(?:"([^"]+)"|'([^']+)'|\(([^)]+)\)|(\S+))(?:\s+(.*))?$""",
      dotAll: true,
    ).firstMatch(input.trim());
    if (match == null) return null;
    final contact = [
      match[1],
      match[2],
      match[3],
      match[4],
    ].whereType<String>().first.trim();
    if (contact.isEmpty) return null;
    return WhatsAppCommandInput(contact, match[5] ?? '');
  }
}

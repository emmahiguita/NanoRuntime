import 'dart:convert';
import '../../engine/planning/whatsapp_automation_input.dart';
import '../../engine/planning/whatsapp_component_requests.dart';
import '../../engine/execution/handlers/whatsapp_command_input.dart';

/// Archivo elegido por el usuario. El nombre se muestra; la ruta privada solo
/// se entrega al ejecutor al preparar una orden explícita de compartir.
final class AutomationInputAttachment {
  const AutomationInputAttachment({required this.name, required this.path});
  final String name, path;
  static final _canonical = RegExp(
    r'^Comparte el archivo (".*") con (".*")$',
    dotAll: true,
  );

  /// Usa la gramática existente y conserva literalmente archivo y destinatario.
  String draftFor(String recipient) =>
      'Comparte el archivo ${jsonEncode(path)} con ${jsonEncode(recipient)}';

  /// Identifica el borrador con esta ruta para revocarlo si se retira el archivo.
  bool ownsDraft(String text) {
    // Usa la misma normalización que Ejecutar para poder revocar el borrador.
    final match = _canonical.firstMatch(text.trim());
    if (match == null) return false;
    try {
      return jsonDecode(match[1]!) == path;
    } on FormatException {
      return false;
    }
  }

  /// Vincula el adjunto solo a una instrucción de compartir. Abrir una app o
  /// buscar un contacto no envía el archivo ni lo consume silenciosamente.
  ({String goal, bool usesAttachment}) prepare(String input) {
    if (ownsDraft(input)) {
      return (goal: input, usesAttachment: true);
    }
    final send = RegExp(
      r'^(?:env[ií]a|manda|comparte|compartir)\s+'
      r'(?:(?:el|la|este|esta)\s+)?'
      r'(?:adjunto|archivo|foto|imagen|v[ií]deo|documento)\s+'
      r'(?:a|con)\s+(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(input);
    if (send == null) {
      // Abrir/buscar conserva el adjunto. Un envío de texto no debe ignorarlo
      // silenciosamente: requiere una orden de compartir o retirarlo del editor.
      final command = WhatsAppAutomationInput.previewCommand(input);
      final invocation = command == null
          ? null
          : RegExp(
              r'^@(?:whatsapp|wpp)\s+(.+)$',
              dotAll: true,
              caseSensitive: false,
            ).firstMatch(command);
      final arguments = invocation == null
          ? null
          : WhatsAppCommandInput.parse(invocation[1]!);
      if (arguments != null && arguments.message.trim().isNotEmpty) {
        throw const FormatException(
          'Hay un adjunto preparado. Usa «Envía el adjunto a (contacto)» '
          'o quítalo para enviar solo texto.',
        );
      }
      return (goal: input, usesAttachment: false);
    }
    var target = send[1]!.trim();
    if (target.startsWith('(') && target.endsWith(')')) {
      target = target.substring(1, target.length - 1).trim();
    }
    if (target.isEmpty || target.contains('"') || target.contains('\n')) {
      throw const FormatException('Indica el destinatario exacto del adjunto.');
    }
    return (goal: draftFor(target), usesAttachment: true);
  }
}

/// Preparación pura compartida por dashboard y búho: un archivo seleccionado
/// nunca se ignora al enviar texto ni al resolver otro PDF/producto.
({String goal, bool usesAttachment}) prepareAutomationDraft(
  String input,
  AutomationInputAttachment? attachment,
) {
  final text = WhatsAppComponentRequests.normalize(input);
  if (attachment == null) {
    if (RegExp(r'\badjunto\b', caseSensitive: false).hasMatch(text)) {
      throw const FormatException('Selecciona el archivo antes de enviarlo.');
    }
    return (goal: text, usesAttachment: false);
  }
  if (WhatsAppComponentRequests.currentReply(text) != null ||
      WhatsAppComponentRequests.currentChatDraft(text) != null ||
      WhatsAppComponentRequests.isArtifact(text)) {
    throw const FormatException(
      'Quita el adjunto preparado para enviar texto u otro documento.',
    );
  }
  return attachment.prepare(text);
}

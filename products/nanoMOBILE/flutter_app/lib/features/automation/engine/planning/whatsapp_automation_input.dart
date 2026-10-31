import 'dart:convert';
import 'whatsapp_intent_parser.dart';
import 'whatsapp_component_requests.dart';
import 'owl_workspace_input.dart';

/// Seleccionar el icono aporta el contexto WhatsApp; no ejecuta nada por sí
/// mismo. Convierte únicamente acciones explícitas al router ya existente.
abstract final class WhatsAppAutomationInput {
  static String command(String input) {
    if (OwlWorkspaceInput.kind(input) != null) return input;
    final text = WhatsAppComponentRequests.normalize(input);
    if (WhatsAppComponentRequests.isExport(text) || WhatsAppComponentRequests.isFloating(text) ||
        WhatsAppComponentRequests.currentReply(text) != null ||
        WhatsAppComponentRequests.currentChatDraft(text) != null ||
        WhatsAppComponentRequests.isArtifact(text)) {
      return text;
    }
    if (WhatsAppComponentRequests.isNavigationSequence(text)) {
      return WhatsAppComponentRequests.scope(text);
    }
    if (RegExp(
      r'^@(whatsapp|wpp)(?:\s|$)',
      caseSensitive: false,
    ).hasMatch(text)) {
      return text;
    }
    if (text.startsWith('@')) {
      throw const FormatException(
        'Desactiva WhatsApp para usar otra herramienta.',
      );
    }
    final quotedDraft = _quotedDraftCommand(text);
    if (quotedDraft != null) return quotedDraft;
    // Borrador producido por el selector real. JSON preserva espacios,
    // paréntesis y caracteres del nombre; no se interpreta una URL como archivo.
    final attachment = RegExp(
      r'^Comparte el archivo (".*") con (".*")$',
      dotAll: true,
    ).firstMatch(text);
    if (attachment != null) {
      final path = jsonDecode(attachment[1]!) as String;
      final contact = jsonDecode(attachment[2]!) as String;
      if (path.isEmpty || contact.isEmpty) {
        throw const FormatException('Falta archivo o destinatario.');
      }
      return '@whatsapp ${jsonEncode(contact)} --archivo $path';
    }
    final lower = text.toLowerCase();
    if (const ['estado', 'ver estado', '--estado'].contains(lower)) {
      return '@whatsapp --estado';
    }
    if (const ['abre whatsapp', 'abrir whatsapp'].contains(lower)) {
      return '@abrir com.whatsapp';
    }
    if (const [
      'volver a nano',
      'regresar a nano',
      'regresa a nano',
      'abre nano',
    ].contains(lower)) {
      return '@abrir dev.nanoai.mobile';
    }
    // No se antepone @whatsapp a cualquier frase: «hola cómo estás» no es
    // autorización para enviar «cómo estás» a un contacto llamado «hola».
    final colonMessage = RegExp(
      r'^(?:env[ií]a(?:le)?|manda(?:le)?|escr[ií]be(?:le)?)\s+(?:a\s+)?(.+?):\s*(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    final explicitTextObject =
        colonMessage != null &&
        RegExp(
          r'\b(?:mensaje|texto|archivo|documento|foto|video|pdf)\b',
          caseSensitive: false,
        ).hasMatch(colonMessage[1]!);
    final intent = colonMessage == null || explicitTextObject
        ? WhatsAppIntentParser.parse(text)
        : WhatsAppIntent(
            action: WhatsAppAction.sendMessage,
            contact: colonMessage[1]!.trim(),
            message: colonMessage[2],
          );
    if (intent == null || intent.contact.isEmpty) {
      final uiGoal = WhatsAppComponentRequests.uiGoal(text);
      if (uiGoal != null) return uiGoal;
      throw const FormatException(
        'Indica acción y destinatario. Ejemplo: Abre el chat de Emm. '
        'Para enviar: Envía a (Emm) (el texto exacto).',
      );
    }
    var contact = intent.contact.trim();
    if (contact.startsWith('(') && contact.endsWith(')')) {
      contact = contact.substring(1, contact.length - 1).trim();
    }
    if (contact.contains('"') || contact.contains('\n')) {
      throw const FormatException(
        'Usa un nombre sin comillas, un número o @usuario.',
      );
    }
    final quoted = jsonEncode(contact);
    return switch (intent.action) {
      WhatsAppAction.findContact => '@contactos $contact',
      WhatsAppAction.openChat => '@whatsapp $quoted',
      WhatsAppAction.sendMessage => '@whatsapp $quoted ${intent.message ?? ''}',
      WhatsAppAction.shareFile =>
        '@whatsapp $quoted --archivo ${intent.filePath ?? ''}',
    };
  }

  /// Los formularios delimitan la identidad con JSON para que dos puntos o
  /// paréntesis del nombre no se conviertan en separadores de destinatario/texto.
  static String? _quotedDraftCommand(String text) {
    final match = RegExp(
      r'^(abre el chat de|env[ií]a a)\s+("(?:\\.|[^"\\])*")'
      r'(?:\s*:\s*(.*))?$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (match == null) return null;
    final target = jsonDecode(match[2]!) as String;
    if (target.trim().isEmpty || target.contains('\n')) {
      throw const FormatException('Indica un destinatario válido.');
    }
    if (match[1]!.toLowerCase().startsWith('abre')) {
      if (match[3] != null) {
        throw const FormatException('Abrir chat no incluye un mensaje.');
      }
      return '@whatsapp ${jsonEncode(target)}';
    }
    final message = match[3];
    if (message == null || message.trim().isEmpty) {
      throw const FormatException('Escribe el mensaje que quieres enviar.');
    }
    return '@whatsapp ${jsonEncode(target)} $message';
  }

  /// Borradores parciales solo afectan a la vista previa, nunca al ejecutor.
  static String? previewCommand(String text) {
    try {
      return command(text);
    } on FormatException {
      return null;
    }
  }
}

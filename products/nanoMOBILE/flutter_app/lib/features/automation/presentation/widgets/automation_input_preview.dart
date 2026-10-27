import '../../../../core/widgets/navigation/nano_input_tool_context.dart';
import '../../engine/execution/handlers/whatsapp_command_input.dart';
import '../../engine/planning/whatsapp_intent_parser.dart';

/// Describe el borrador sin resolver contactos ni abrir aplicaciones.
abstract final class AutomationInputPreview {
  static const _asset = 'assets/automation/whatsapp_personal_icon.png';
  static NanoInputToolContext? parse(String text) {
    final command = text.trim();
    final navigation = switch (command) {
      '@abrir com.whatsapp' => 'Abrir WhatsApp',
      '@abrir dev.nanoai.mobile' => 'Volver a Nano',
      _ => null,
    };
    if (navigation != null || command.startsWith('@contactos ')) {
      return NanoInputToolContext(
        name: 'WhatsApp',
        asset: _asset,
        action: navigation ?? 'Buscar en la agenda',
        status: 'Seleccionado',
        target: navigation != null
            ? ''
            : identity(command.substring(11).trim()),
        detail: 'Acción pendiente de ejecutar',
      );
    }
    final explicit = RegExp(
      r'^@(whatsapp|wpp)(?:\s|$)',
      caseSensitive: false,
    ).firstMatch(text.trim());
    String target = '';
    String action = 'Elegir destinatario';
    if (explicit != null) {
      final rest = text.trim().substring(explicit.end).trim();
      if (rest == '--estado') {
        action = 'Consultar estado local';
      } else {
        final command = WhatsAppCommandInput.parse(rest);
        target = command?.contact ?? '';
        final message = command?.message ?? '';
        action = message.startsWith('--archivo ')
            ? 'Enviar archivo'
            : message.isEmpty
            ? 'Abrir chat'
            : 'Enviar mensaje';
      }
    } else {
      // El parser también reconoce otras frases sin app: aquí se exige contexto
      // WhatsApp explícito. Sigue siendo una intención, no una herramienta activa.
      if (!RegExp(r'\bwhatsapp\b', caseSensitive: false).hasMatch(text)) {
        return null;
      }
      final intent = WhatsAppIntentParser.parse(text);
      if (intent == null) return null;
      target = intent.contact;
      action = switch (intent.action) {
        WhatsAppAction.findContact => 'Buscar contacto',
        WhatsAppAction.openChat => 'Abrir chat',
        WhatsAppAction.sendMessage => 'Enviar mensaje',
        WhatsAppAction.shareFile => 'Enviar archivo',
      };
    }
    return NanoInputToolContext(
      name: 'WhatsApp',
      asset: _asset,
      target: identity(target),
      action: action,
      status: 'Seleccionado',
      detail: 'App Android · pendiente de ejecutar',
    );
  }

  /// Nunca confunde los dígitos de un @usuario con un número telefónico.
  static String identity(String target) {
    if (target.isEmpty) return '';
    if (WhatsAppCommandInput.isUsername(target)) return 'Usuario: $target';
    if (RegExp(r'^[+0-9 ().-]+$').hasMatch(target)) return 'Número: $target';
    return 'Contacto: $target';
  }
}

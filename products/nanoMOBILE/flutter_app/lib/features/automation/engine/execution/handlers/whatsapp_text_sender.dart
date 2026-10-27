import '../../business/whatsapp_message_provider.dart';
import '../../platform/whatsapp_media_share.dart';
import '../../platform/whatsapp_send_monitor.dart';
import '../../voice/execution_cancellation.dart';
import '../tool_call.dart';
import 'whatsapp_contact_resolver.dart';
import 'whatsapp_command_input.dart';
import 'whatsapp_current_chat_sender.dart';

/// Transporte de texto separado de adjuntos. Un paquete explícito conserva
/// la cuenta personal/Business y excluye el proveedor Cloud configurado.
final class WhatsAppTextSender {
  const WhatsAppTextSender(
    this._share,
    this._contactResolver,
    this._messageProvider,
  );
  final WhatsAppMediaShare _share;
  final WhatsAppContactResolver _contactResolver;
  final WhatsAppMessageProvider _messageProvider;

  /// Envía un mensaje directo a un contacto de WhatsApp verificado.
  Future<String> sendMessage(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) async {
    if (call.args?['replyInPlace'] == true) {
      return WhatsAppCurrentChatSender().send(call, cancellation: cancellation);
    }
    final contactQ = _str(call, 'contact').isNotEmpty
        ? _str(call, 'contact')
        : (call.selectorArg ?? '');
    final text = _str(call, 'text').isNotEmpty
        ? _str(call, 'text')
        : (call.textArg ?? '');
    if (contactQ.isEmpty) {
      return '[error] Falta especificar el contacto destinatario.';
    }
    if (text.isEmpty) {
      return '[error] Falta especificar el texto exacto del mensaje.';
    }

    final username = WhatsAppCommandInput.isUsername(contactQ);
    final resolved = username ? null : await _contactResolver.resolve(contactQ);
    if (resolved?.isGroup == true) {
      return '[error] El envío directo por teléfono no admite grupos. Usa su flujo específico.';
    }
    // Un paquete explícito exige la app instalada y no usa la conexión Cloud.
    final requestedPackage = call.args?['packageName']?.toString();
    if (requestedPackage != null &&
        !const {
          'com.whatsapp',
          'com.whatsapp.w4b',
        }.contains(requestedPackage)) {
      return '[error] El paquete de destino no es WhatsApp instalado.';
    }
    final installedOnly = requestedPackage != null;
    final cloudSelected =
        !installedOnly && await _messageProvider.cloudSelected();
    final rawPhone = contactQ.replaceAll(RegExp(r'\D'), '');
    final isDirectPhone =
        RegExp(r'^[+0-9 ().-]+$').hasMatch(contactQ) &&
        rawPhone.length >= 8 &&
        rawPhone.length <= 15;
    if (resolved == null && cloudSelected && !isDirectPhone) {
      return '[error] Meta Cloud requiere teléfono internacional con 8 a 15 dígitos.';
    }
    if (resolved == null && !cloudSelected && !username) {
      return '[error] No se encontró el contacto "$contactQ" en la agenda del dispositivo.';
    }

    try {
      final phone = resolved?.number ?? (username ? contactQ : rawPhone);
      final name = resolved?.name ?? phone;
      if (installedOnly) {
        final ok = await WhatsAppSendMonitor().launchAndWait(
          () => _share.openChat(
            contact: phone,
            text: text,
            packageName: requestedPackage,
            autoSend: true,
          ),
          cancellation: cancellation,
          recipient: name,
        );
        return ok
            ? '[completedUnverified] Clic de envío y regreso a Nano observados para "$name"; entrega no confirmada.'
            : '[error] No se pudo abrir WhatsApp instalado.';
      }
      final receipt = await _messageProvider.send(phone, text);
      return receipt.cloudMessageId != null
          ? '[completed] Meta aceptó el mensaje de "$name" '
                '($phone); ID ${receipt.cloudMessageId}.'
          : '[completedUnverified] Flujo local abierto para "$name" '
                '($phone); no se verifica clic ni entrega.';
    } on WhatsAppAutomationFailure catch (error) {
      return '[error] ${error.message}';
    } on WhatsAppOutcomeUnknown catch (error) {
      return '[timeoutOutcomeUnknown] ${error.reason}';
    } catch (error) {
      final recipient = resolved?.name ?? contactQ;
      return '[error] No se pudo enviar a "$recipient": '
          '${error.toString().replaceFirst('Exception: ', '')}';
    }
  }

  /// Lee argumentos tipados sin normalizar el contenido del mensaje.
  String _str(ToolCall call, String key) =>
      (call.args?[key] ?? '').toString().trim();
}

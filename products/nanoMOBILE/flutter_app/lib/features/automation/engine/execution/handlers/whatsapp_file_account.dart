import '../tool_call.dart';
import '../../../domain/whatsapp_contact.dart';

/// Una orden para WhatsApp personal no debe terminar en Business por los
/// metadatos de agenda. Una discrepancia exige aclaración antes de compartir.
String? whatsAppFileAccount(ToolCall call, WhatsAppContact contact) {
  final requested = call.args?['packageName']?.toString();
  if (requested != null &&
      !const {'com.whatsapp', 'com.whatsapp.w4b'}.contains(requested)) {
    throw const FormatException(
      'La cuenta solicitada no corresponde a WhatsApp instalado.',
    );
  }
  if (requested != null &&
      contact.packageName.isNotEmpty &&
      requested != contact.packageName) {
    throw const FormatException(
      'El contacto está asociado a otra cuenta de WhatsApp. Confirma personal o Business.',
    );
  }
  return requested ??
      (contact.packageName.isEmpty ? null : contact.packageName);
}

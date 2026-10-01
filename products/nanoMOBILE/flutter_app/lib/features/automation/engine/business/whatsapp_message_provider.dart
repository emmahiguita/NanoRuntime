import 'meta_templates_api.dart';

/// Resultado que diferencia apertura local de aceptación real de Cloud API.
class WhatsAppSendReceipt {
  const WhatsAppSendReceipt({required this.message, this.cloudMessageId});
  final String message;
  final String? cloudMessageId;
}

/// Puerto de salida: el agente no conoce detalles de cada transporte.
abstract interface class WhatsAppMessageProvider {
  /// Permite Cloud usar destinatarios conocidos solo por teléfono, no agenda local.
  Future<bool> cloudSelected();

  Future<WhatsAppSendReceipt> send(String phone, String text);
}

/// Selecciona el canal guardado; nunca reintenta por otro canal tras un error.
class ConfiguredWhatsAppMessageProvider implements WhatsAppMessageProvider {
  ConfiguredWhatsAppMessageProvider({
    required Future<bool> Function(String phone, String text) sendLocally,
    MetaTemplatesApi? cloudApi,
  }) : _sendLocally = sendLocally,
       _cloudApi = cloudApi ?? MetaTemplatesApi();

  final Future<bool> Function(String phone, String text) _sendLocally;
  final MetaTemplatesApi _cloudApi;

  /// Expone la selección sin enviar ni cambiar el proveedor configurado.
  @override
  Future<bool> cloudSelected() async =>
      (await _cloudApi.connection()).agentUsesCloud;

  /// Cloud devuelve ID de Meta; canal local informa explícitamente que no verifica entrega.
  @override
  Future<WhatsAppSendReceipt> send(String phone, String text) async {
    final config = await _cloudApi.connection();
    if (config.agentUsesCloud) {
      if (!config.ready) {
        throw const FormatException(
          'Configura primero la conexión Meta Cloud.',
        );
      }
      final id = await _cloudApi.sendText(phone, text);
      return WhatsAppSendReceipt(message: 'accepted', cloudMessageId: id);
    }
    if (!await _sendLocally(phone, text)) {
      throw Exception('No se pudo abrir el flujo local de WhatsApp.');
    }
    return const WhatsAppSendReceipt(message: 'local_unverified');
  }
}

part of 'meta_templates_api.dart';

/// Escritura manual por la misma conexión y línea de la bandeja.
/// requestId permanece estable ante resultado incierto; el gateway no reenvía.
extension MetaManualMessages on MetaTemplatesApi {
  Future<String> sendManual(Map<String, dynamic> body, String requestId) async {
    final data = await _request(
      'POST',
      '/api/v1/whatsapp/messages',
      body: {...body, 'request_id': requestId},
    );
    final messages = data['messages'];
    final id = messages is List && messages.isNotEmpty && messages.first is Map
        ? messages.first['id']
        : null;
    if (id is! String || id.isEmpty) {
      throw const FormatException(
        'Sin confirmación de Meta. No repitas el envío.',
      );
    }
    return id;
  }

  Future<String> uploadMedia(String name, String mime, List<int> bytes) async {
    if (bytes.isEmpty || bytes.length > 6 * 1024 * 1024) {
      throw const FormatException('Selecciona un archivo de hasta 6 MB.');
    }
    final data = await _request(
      'POST',
      '/api/v1/whatsapp/media',
      body: {
        'filename': name,
        'mime_type': mime,
        'content': base64Encode(bytes),
      },
    );
    final id = data['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Meta no confirmó el archivo.');
    }
    return id;
  }
}

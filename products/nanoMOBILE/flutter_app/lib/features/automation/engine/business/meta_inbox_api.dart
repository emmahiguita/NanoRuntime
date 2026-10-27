part of 'meta_templates_api.dart';

/// Extiende el adaptador existente: ninguna llave ni cliente HTTP adicional.
extension MetaInboxApi on MetaTemplatesApi {
  /// Obtiene lista o historial exacto, conservando instantánea al cargar páginas antiguas.
  Future<MetaInboxPage> inboxPage({
    String? peer,
    int? before,
    int? through,
  }) async {
    if (peer != null && !RegExp(r'^[0-9]{1,32}$').hasMatch(peer)) {
      throw const FormatException('Interlocutor oficial inválido.');
    }
    final path = peer == null
        ? '/api/v1/whatsapp/conversations'
        : '/api/v1/whatsapp/conversations/$peer/messages';
    final data = await _request(
      'GET',
      path,
      query: {
        'limit': '50',
        if (before != null) 'before': '$before',
        if (through != null) 'through': '$through',
      },
    );
    return _decodeInboxPage(data, conversations: peer == null);
  }

  /// Reanuda desde la secuencia confirmada; el cursor solo avanza después de leer.
  Future<MetaInboxPage> inboxChanges(int after, {int? through}) async {
    final data = await _request(
      'GET',
      '/api/v1/whatsapp/changes',
      query: {
        'after': '$after',
        'limit': '100',
        if (through != null) 'through': '$through',
      },
    );
    return _decodeInboxPage(data);
  }
}

/// Valida el contrato antes de entregarlo al controlador, incluyendo cursores.
MetaInboxPage _decodeInboxPage(
  Map<String, dynamic> data, {
  bool conversations = false,
}) {
  final rows = data['data'];
  final snapshot = data['snapshot'];
  final scope = data['scope'];
  if (rows is! List ||
      snapshot is! int ||
      snapshot < 0 ||
      scope is! Map ||
      scope['waba_id'] is! String ||
      scope['phone_number_id'] is! String) {
    throw const FormatException('Página de historial oficial inválida.');
  }
  int? cursor(String key) {
    final value = data[key];
    if (value != null && (value is! int || value < 0 || value > snapshot)) {
      throw const FormatException('Cursor oficial inválido.');
    }
    return value as int?;
  }

  final messages = <MetaInboxMessage>[];
  for (final row in rows) {
    final value = conversations && row is Map ? row['last_message'] : row;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Mensaje oficial ilegible.');
    }
    messages.add(MetaInboxMessage.fromJson(value));
  }
  return MetaInboxPage(
    messages: messages,
    snapshot: snapshot,
    scope: "${scope['waba_id']}:${scope['phone_number_id']}",
    nextBefore: cursor('next_before'),
    nextAfter: cursor('next_after'),
    cursor: cursor('cursor'),
  );
}

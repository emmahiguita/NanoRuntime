/// Política no destructiva para las vistas previas del listado de WhatsApp Web.
/// El DOM no entrega un tipo de evento fiable: se reconocen únicamente avisos
/// completos conocidos, no palabras sueltas dentro de una conversación humana.
library;

abstract final class WhatsAppWebMessageFilter {
  // Compila una vez los formatos de actividad; los anclajes conservan mensajes
  // que mencionan o explican un like sin ser el aviso completo del servicio.
  static final _likeNotice = RegExp(
    r'^(?:le gust[oó]|le gusta|dio me gusta a|liked|curtiu)\s+'
    r'(?:tu|your|seu|sua)\s+'
    r'(?:estado|historia|status|story|mensaje|message|publicaci[oó]n|post)'
    r'[.!]?$',
    caseSensitive: false,
    unicode: true,
  );

  // No incluye «respondió/replied»: una respuesta escrita a una historia es
  // mensajería, no un like. Tampoco bloquea mensajes que contienen solo emojis.
  static final _reactionNotice = RegExp(
    r'^(?:reaccion[oó](?:\s+(?:con\s+)?[^a-záéíóúüñ0-9]{1,24})?\s+a|'
    r'reacted(?:\s+(?:with\s+)?[^a-záéíóúüñ0-9]{1,24})?\s+to|'
    r'reagiu\s+ao?)\s+'
    r'(?:tu|your|seu|sua)\s+'
    r'(?:estado|historia|status|story|mensaje|message)'
    r'(?:\s*:\s*["“].+["”])?[.!]?$',
    caseSensitive: false,
    unicode: true,
  );

  // Solo se usa con el título de servicio WhatsApp, nunca sobre cualquier chat.
  static final _serviceNotice = RegExp(
    r'^(?:buscando mensajes nuevos|comprobando si hay mensajes nuevos|'
    r'checking for new messages|copia de seguridad|backup in progress|'
    r'whatsapp web)(?:\.{1,3}|…)?$',
    caseSensitive: false,
  );

  /// Admite una vista previa real sin borrar registros ni ejecutar acciones.
  /// Identificadores de estado/canal se rechazan por su identidad técnica; un
  /// chat llamado «Novedades» no se descarta solamente por su nombre humano.
  static bool allows({
    required String conversationId,
    required String displayName,
    required String lastMessage,
  }) {
    final id = conversationId.trim().toLowerCase();
    final name = _clean(displayName);
    final message = _clean(lastMessage);
    if (id.isEmpty || name.isEmpty || name == '0' || message.isEmpty) {
      return false;
    }
    if (id.contains('status@broadcast') || id.contains('@newsletter')) {
      return false;
    }
    if (name.toLowerCase() == 'whatsapp' && _serviceNotice.hasMatch(message)) {
      return false;
    }

    // Una fila puede prefijar el aviso con el nombre del contacto/remitente.
    // Solo quitamos ese nombre exacto: no adivinamos autores ni cortamos texto.
    final withoutSender = message.replaceFirst(
      RegExp('^${RegExp.escape(name)}(?:\\s*:\\s*|\\s+)', caseSensitive: false),
      '',
    );
    return !_isActivity(message) && !_isActivity(withoutSender);
  }

  // Centraliza la decisión para el adaptador Web y la unión final del panel,
  // evitando listas de frases duplicadas y descartes contradictorios.
  static bool _isActivity(String value) =>
      _likeNotice.hasMatch(value) || _reactionNotice.hasMatch(value);

  // Elimina marcas direccionales/formato del DOM y normaliza espacios, sin
  // quitar acentos, emojis ni palabras del contenido real del usuario.
  static String _clean(String value) => value
      .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

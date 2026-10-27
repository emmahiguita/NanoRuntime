// tiktok_web_types.dart
//
// QUÉ HACE: define los modelos inmutables del bridge TikTok Web (conversación
//   de la bandeja y mensaje individual).
// CÓMO: constructores `fromJson` que toleran campos ausentes (el DOM puede no
//   renderizar previews o contadores según el estado de TikTok).
// POR QUÉ: la UI y el adapter comparten un contrato único y tipado, evitando
//   Maps sueltos repartidos por la pantalla (SRP + DIP).

/// Conversación de la bandeja de mensajes de TikTok Web.
class TikTokConversation {
  /// Posición en la lista DOM (índice usado para abrirla con clic sintético).
  final int index;

  /// Nombre visible del contacto o grupo.
  final String name;

  /// Contador de no leídos (0 cuando TikTok no lo expone).
  final int unread;

  const TikTokConversation({
    required this.index,
    required this.name,
    required this.unread,
  });

  bool get hasUnread => unread > 0;

  factory TikTokConversation.fromJson(Map<String, dynamic> json) {
    return TikTokConversation(
      index: (json['index'] as num?)?.toInt() ?? -1,
      name: (json['name'] as String?)?.trim() ?? '',
      unread: int.tryParse('${json['unread'] ?? ''}') ?? 0,
    );
  }
}

/// Mensaje leído dentro de una conversación abierta.
class TikTokChatMessage {
  /// Texto plano de la burbuja (TikTok Web marca los tipos no soportados).
  final String text;

  const TikTokChatMessage({required this.text});

  factory TikTokChatMessage.fromJson(Map<String, dynamic> json) {
    return TikTokChatMessage(text: (json['text'] as String?)?.trim() ?? '');
  }
}

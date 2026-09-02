/// A14.6 — NotificationObject: representación tipada de una notificación activa
/// como CAPACIDAD del sistema (Notification Capability Graph). Cada notificación
/// de Android con acción RemoteInput es una capacidad de respuesta genérica
/// (no "WhatsAppReply" ni por app): el mismo contrato vale para Telegram,
/// Signal, Discord, Slack, Teams o cualquier app que publique una notificación
/// de mensajería contestable.
///
/// Puro Dart: parsea el mapa crudo que expone `listActiveNotifications` (nativo).
library;

/// Objeto de notificación con identidad/estructura real extraída del
/// MessagingStyle de Android. Campos vacíos = no expuesto por la app origen
/// (honesto, nunca se inventa un sender ni un texto).
final class NotificationObject {
  final String key;
  final String packageName;
  final String title;
  final String text;

  /// Texto del mensaje individual (MessagingStyle), si existe.
  final String messageText;

  /// Remitente (Person.name del último mensaje), si existe.
  final String sender;

  final String conversationTitle;
  final String conversationId;

  /// true si la notificación viene de una conversación grupal.
  final bool isGroup;

  /// true si es una notificación agregada (FLAG_GROUP_SUMMARY).
  final bool isSummary;

  final int postTime;
  final bool canReply;
  final String remoteInputKey;
  final List<String> actions;
  final bool ongoing;

  const NotificationObject({
    required this.key,
    required this.packageName,
    required this.title,
    required this.text,
    required this.messageText,
    required this.sender,
    required this.conversationTitle,
    required this.conversationId,
    required this.isGroup,
    required this.isSummary,
    required this.postTime,
    required this.canReply,
    required this.remoteInputKey,
    required this.actions,
    required this.ongoing,
  });

  factory NotificationObject.fromMap(Map<dynamic, dynamic> raw) {
    return NotificationObject(
      key: '${raw['key'] ?? ''}',
      packageName: '${raw['package'] ?? ''}',
      title: '${raw['title'] ?? ''}',
      text: '${raw['text'] ?? ''}',
      messageText: '${raw['messageText'] ?? ''}',
      sender: '${raw['sender'] ?? ''}',
      conversationTitle: '${raw['conversationTitle'] ?? ''}',
      conversationId: '${raw['conversationId'] ?? ''}',
      isGroup: raw['isGroup'] == true,
      isSummary: raw['isSummary'] == true,
      postTime: raw['postTime'] is num ? (raw['postTime'] as num).toInt() : 0,
      canReply: raw['canReply'] == true,
      remoteInputKey: '${raw['remoteInputKey'] ?? ''}',
      actions: ((raw['actions'] as List?) ?? const [])
          .map((a) => '$a')
          .where((a) => a.isNotEmpty)
          .toList(),
      ongoing: raw['ongoing'] == true,
    );
  }

  /// Identidad legible para el modelo/planner: "Juan C. (WhatsApp)".
  String get identity {
    final who = sender.isNotEmpty ? sender : conversationTitle;
    final label = who.isNotEmpty ? who : title;
    return '$label ($packageName)';
  }

  /// Texto más relevante para interpretar: mensaje individual > texto grande.
  String get interpretableText => messageText.isNotEmpty ? messageText : text;

  /// true si esta notificación se refiere a [recipient] (coincidencia en
  /// sender/conversationTitle/title). Fuente única de matching por remitente:
  /// la usan NotificationCandidateProvider (reply) y TaskOrchestrator (T2.8,
  /// derivar la app de mensajería), evitando duplicar la lógica.
  bool matchesRecipient(String recipient) {
    final needle = recipient.trim().toLowerCase();
    if (needle.isEmpty) return false;
    final hay = '$sender $conversationTitle $title'.toLowerCase();
    return hay.contains(needle);
  }

  @override
  String toString() =>
      'NotificationObject($identity, canReply=$canReply, group=$isGroup)';
}

/// BOT-EVENT-04 — Eventos de entrada y disparadores del Nano Bot Runtime.
///
/// **QUÉ HACE:**
/// Modela los estímulos a los que un bot puede reaccionar (mensajes, imágenes,
/// archivos adjuntos, notificaciones bancarias o tareas programadas cron).
///
/// **CÓMO FUNCIONA:**
/// Estructura desacoplada que normaliza eventos procedentes de WhatsApp, el sistema
/// operativo o temporizadores locales para su procesamiento agéntico.
///
/// **POR QUÉ:**
/// Permite que Nano no sea un bot puramente pasivo de "pregunta-respuesta", sino un
/// agente proactivo que procesa archivos o reacciona ante eventos del negocio.
library;

enum BotEventType {
  message('message', 'Mensaje de texto'),
  image('image', 'Imagen recibida'),
  document('document', 'Documento o archivo'),
  schedule('schedule', 'Tarea programada / Cron'),
  payment('payment', 'Notificación de pago'),
  systemNotification('systemNotification', 'Notificación Android'),
  custom('custom', 'Evento personalizado');

  final String key;
  final String label;

  const BotEventType(this.key, this.label);

  static BotEventType fromKey(String? key) {
    return BotEventType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => BotEventType.custom,
    );
  }
}

final class BotEvent {
  final String id;
  final BotEventType type;
  final String channel;
  final String senderId;
  final String senderName;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  const BotEvent({
    required this.id,
    required this.type,
    required this.channel,
    required this.senderId,
    this.senderName = '',
    this.payload = const {},
    required this.timestamp,
  });

  String get textContent => payload['text']?.toString() ?? '';
  String? get filePath => payload['filePath']?.toString();
  String? get mimeType => payload['mimeType']?.toString();

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.key,
        'channel': channel,
        'senderId': senderId,
        'senderName': senderName,
        'payload': payload,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory BotEvent.fromMap(Map<dynamic, dynamic> map) {
    return BotEvent(
      id: map['id']?.toString() ?? '',
      type: BotEventType.fromKey(map['type']?.toString()),
      channel: map['channel']?.toString() ?? 'whatsapp',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      payload: (map['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] is num ? (map['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

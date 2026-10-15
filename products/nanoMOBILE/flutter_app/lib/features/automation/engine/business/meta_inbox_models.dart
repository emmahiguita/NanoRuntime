/// Mensaje respaldado por un evento persistido de Meta, no por una notificación local.
class MetaInboxMessage {
  const MetaInboxMessage({
    required this.sequence,
    required this.wamid,
    required this.peerId,
    required this.kind,
    this.type,
    this.text,
    this.caption,
    this.providerTime,
  });
  final int sequence;
  final String wamid, peerId, kind;
  final String? type, text, caption;
  final DateTime? providerTime;

  /// Rechaza identidad incompleta; una página malformada no se convierte en éxito vacío.
  factory MetaInboxMessage.fromJson(Map<String, dynamic> data) {
    final sequence = data['sequence'];
    final wamid = data['wamid'];
    final peer = data['peer_id'];
    final kind = data['kind'];
    if (sequence is! int ||
        sequence < 1 ||
        wamid is! String ||
        wamid.isEmpty ||
        peer is! String ||
        !RegExp(r'^[0-9]{1,32}$').hasMatch(peer) ||
        !['message', 'status'].contains(kind) ||
        data['source'] != 'meta_webhook') {
      throw const FormatException('Evento oficial con identidad inválida.');
    }
    final seconds = int.tryParse(data['provider_timestamp']?.toString() ?? '');
    return MetaInboxMessage(
      sequence: sequence,
      wamid: wamid,
      peerId: peer,
      kind: kind as String,
      type: data['type'] as String?,
      text: data['text'] as String?,
      caption: data['caption'] as String?,
      providerTime: seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000,
              isUtc: true,
            ).toLocal(),
    );
  }

  /// Un medio sin texto se identifica por tipo; no inventa transcripciones ni adjuntos.
  String get preview =>
      text ?? caption ?? 'Mensaje de tipo ${type ?? 'desconocido'}';
}

/// Cursores y ámbito permiten paginar y detectar cambios de cuenta sin mezclar chats.
class MetaInboxPage {
  const MetaInboxPage({
    required this.messages,
    required this.snapshot,
    required this.scope,
    this.nextBefore,
    this.nextAfter,
    this.cursor,
  });
  final List<MetaInboxMessage> messages;
  final int snapshot;
  final String scope;
  final int? nextBefore, nextAfter, cursor;
}

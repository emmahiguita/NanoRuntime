/// Traduce metadatos reales; no asigna la hora actual a mensajes antiguos.
library;

import '../messaging/conversation_memory.dart';

final class WhatsAppWebHistoryMessage {
  final String eventId, body, sender;
  final int atMs;
  final bool isSelf;
  const WhatsAppWebHistoryMessage({
    required this.eventId,
    required this.body,
    required this.sender,
    required this.atMs,
    required this.isSelf,
  });
  static WhatsAppWebHistoryMessage? fromDom(
    Map<String, dynamic> row,
    String locale,
  ) {
    final meta = (row['metadata'] ?? '').toString();
    final match = RegExp(
      r'^\[(\d{1,2}):(\d{2})(?:\s*([ap])\.?\s*m\.?)?,\s*(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\]\s*(.*?):\s*$',
      caseSensitive: false,
    ).firstMatch(meta);
    if (match == null) return null;
    final v = [1, 2, 4, 5, 6].map((i) => int.parse(match.group(i)!)).toList();
    var hour = v[0];
    final meridiem = match.group(3)?.toLowerCase();
    if (meridiem != null) hour = hour % 12 + (meridiem == 'p' ? 12 : 0);
    final us = locale.toLowerCase() == 'en-us';
    final day = v[us ? 3 : 2], month = v[us ? 2 : 3];
    final year = v[4] < 100 ? 2000 + v[4] : v[4];
    final time = DateTime(year, month, day, hour, v[1]);
    if (time.year != year ||
        time.month != month ||
        time.day != day ||
        time.hour != hour ||
        time.minute != v[1]) {
      return null;
    }
    final id = (row['eventId'] ?? '').toString(),
        body = (row['body'] ?? '').toString();
    if (id.isEmpty || body.trim().isEmpty) return null;
    return WhatsAppWebHistoryMessage(
      eventId: id,
      body: body,
      sender: match.group(7)!,
      atMs: time.millisecondsSinceEpoch,
      isSelf: row['isSelf'] == true,
    );
  }

  factory WhatsAppWebHistoryMessage.fromStored(Map<String, dynamic> r) =>
      WhatsAppWebHistoryMessage(
        eventId: r['eventId'].toString(),
        body: r['body'].toString(),
        sender: r['sender'].toString(),
        atMs: (r['atMs'] as num).toInt(),
        isSelf: r['isSelf'] == true,
      );
  Map<String, dynamic> toStored() => {
    'eventId': eventId,
    'body': body,
    'sender': sender,
    'atMs': atMs,
    'isSelf': isSelf,
  };
  ConversationMemoryEntry get entry => ConversationMemoryEntry(
    kind: isSelf
        ? ConversationMemoryEntryKind.outboundObservedManual
        : ConversationMemoryEntryKind.inbound,
    text: body,
    sender: sender,
    atMs: atMs,
    eventId: eventId,
  );
}

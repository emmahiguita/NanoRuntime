/// Modelos y lectura de resúmenes reales del DOM; no controla el WebView.
/// Conserva la interpretación temporal existente y evita duplicar el parser.
library;

final class WhatsAppWebConversationSummary {
  final String id;
  final String displayName;
  final String lastMessage;
  final String timeLabel;
  final int lastAtMs;
  final int unreadCount;
  final bool isGroup;

  const WhatsAppWebConversationSummary({
    required this.id,
    required this.displayName,
    required this.lastMessage,
    required this.timeLabel,
    required this.lastAtMs,
    required this.unreadCount,
    required this.isGroup,
  });

  Map<String, Object> toJson() => {
    'id': id,
    'displayName': displayName,
    'lastMessage': lastMessage,
    'timeLabel': timeLabel,
    'lastAtMs': lastAtMs,
    'unreadCount': unreadCount,
    'isGroup': isGroup,
  };

  static WhatsAppWebConversationSummary? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = '${raw['id'] ?? ''}'.trim();
    final name = '${raw['displayName'] ?? ''}'.trim();
    if (id.isEmpty || name.isEmpty) return null;
    return WhatsAppWebConversationSummary(
      id: id,
      displayName: name,
      lastMessage: '${raw['lastMessage'] ?? ''}',
      timeLabel: '${raw['timeLabel'] ?? ''}',
      lastAtMs: (raw['lastAtMs'] as num?)?.toInt() ?? 0,
      unreadCount: (raw['unreadCount'] as num?)?.toInt() ?? 0,
      isGroup: raw['isGroup'] == true,
    );
  }
}

final class WhatsAppWebConversationDecoder {
  /// Máximo de chats recordados; la lista Web solo renderiza los visibles.
  static const maxKnown = 400;

  /// Convierte el evento recibido manteniendo fechas de vistas previas iguales.
  /// WhatsApp Web virtualiza la lista: un chat fuera de pantalla no se borra,
  /// se conserva con sus últimos datos reales.
  List<WhatsAppWebConversationSummary> decode(
    Object? rawValue,
    List<WhatsAppWebConversationSummary> previous,
  ) {
    if (rawValue is! List) return previous;
    final previousById = {for (final item in previous) item.id: item};
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = <WhatsAppWebConversationSummary>[];
    final seen = <String>{};

    for (var index = 0; index < rawValue.length && index < 80; index++) {
      final raw = rawValue[index];
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final id = '${map['id'] ?? ''}'.trim();
      final displayName = '${map['displayName'] ?? ''}'.trim();
      if (id.isEmpty || displayName.isEmpty || displayName == '0') continue;
      if (!seen.add(id)) continue;
      final lastMessage = '${map['lastMessage'] ?? ''}'.trim();
      final timeLabel = '${map['timeLabel'] ?? ''}'.trim();
      final previous = previousById[id];
      final unchanged =
          previous != null &&
          previous.lastMessage == lastMessage &&
          previous.timeLabel == timeLabel;
      next.add(
        WhatsAppWebConversationSummary(
          id: id,
          displayName: displayName,
          lastMessage: lastMessage,
          timeLabel: timeLabel,
          lastAtMs: unchanged
              ? previous.lastAtMs
              : _timestampFromLabel(timeLabel, now, index),
          unreadCount: ((map['unreadCount'] as num?)?.toInt() ?? 0).clamp(
            0,
            999,
          ),
          isGroup: map['isGroup'] == true,
        ),
      );
    }
    for (final item in previous) {
      if (!seen.contains(item.id)) next.add(item);
    }
    final order = {for (var i = 0; i < next.length; i++) next[i].id: i};
    next.sort((a, b) {
      final time = b.lastAtMs.compareTo(a.lastAtMs);
      return time != 0 ? time : order[a.id]!.compareTo(order[b.id]!);
    });
    return next.length > maxKnown ? next.sublist(0, maxKnown) : next;
  }

  static const _weekdays = {
    'lunes': 1, 'mon': 1, 'monday': 1,
    'martes': 2, 'tue': 2, 'tuesday': 2,
    'miércoles': 3, 'miercoles': 3, 'wed': 3, 'wednesday': 3,
    'jueves': 4, 'thu': 4, 'thursday': 4,
    'viernes': 5, 'fri': 5, 'friday': 5,
    'sábado': 6, 'sabado': 6, 'sat': 6, 'saturday': 6,
    'domingo': 7, 'sun': 7, 'sunday': 7,
  };

  // Traduce la etiqueta temporal de WhatsApp; no consulta servicios externos.
  int _timestampFromLabel(String label, int nowMs, int index) {
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    final normalized = label.trim().toLowerCase().replaceAll('.', '');
    final clock = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([ap])\s*m)?$',
    ).firstMatch(normalized);
    if (clock != null) {
      var hour = int.tryParse(clock.group(1) ?? '') ?? 0;
      final minute = int.tryParse(clock.group(2) ?? '') ?? 0;
      final meridiem = clock.group(3);
      if (meridiem == 'p' && hour < 12) hour += 12;
      if (meridiem == 'a' && hour == 12) hour = 0;
      var candidate = DateTime(now.year, now.month, now.day, hour, minute);
      if (candidate.isAfter(now.add(const Duration(minutes: 5)))) {
        candidate = candidate.subtract(const Duration(days: 1));
      }
      return candidate.millisecondsSinceEpoch;
    }

    if (normalized == 'ayer' || normalized == 'yesterday') {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1)).millisecondsSinceEpoch - index;
    }

    final weekday = _weekdays[normalized];
    if (weekday != null) {
      var back = (now.weekday - weekday) % 7;
      if (back < 2) back += 7;
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: back)).millisecondsSinceEpoch - index;
    }

    final date = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$',
    ).firstMatch(normalized);
    if (date != null) {
      final day = int.tryParse(date.group(1) ?? '');
      final month = int.tryParse(date.group(2) ?? '');
      var year = int.tryParse(date.group(3) ?? '');
      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        return DateTime(year, month, day).millisecondsSinceEpoch;
      }
    }

    return nowMs - index;
  }
}

import 'dart:convert';
import 'persona_profile.dart';

/// Grupos de organización, independientes de los grupos de WhatsApp.
abstract final class PersonalContactPolicy {
  static const groups = [
    'Familia',
    'Amigos cercanos',
    'Amigos',
    'Trabajo',
    'Clientes',
  ];
  static List<String> list(String? raw) {
    try {
      return (jsonDecode(raw ?? '[]') as List)
          .whereType<String>()
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<String> conversations(RelationshipProfile profile) => {
    ...list(profile.facts['conversationIds']),
    if (profile.facts['conversationId']?.isNotEmpty == true)
      profile.facts['conversationId']!,
  }.toList();

  static String normalizeStyle(String? value) => switch (value?.toLowerCase()) {
    'formal' => 'formal',
    'cercano' || 'close' => 'close',
    'breve' => 'brief',
    'casual' => 'casual',
    _ => 'inherit',
  };

  static Map<String, String> effectiveFacts(Map<String, String> facts) {
    final result = {...facts};
    final style = normalizeStyle(facts['styleRegister']);
    final membership = list(facts['groups']);
    result['styleRegister'] = style == 'inherit'
        ? membership.any((g) => g == 'Clientes' || g == 'Trabajo')
              ? 'formal'
              : membership.any((g) => g == 'Familia' || g == 'Amigos cercanos')
              ? 'close'
              : 'casual'
        : style == 'brief'
        ? 'casual'
        : style;
    if (style == 'brief') {
      result['customStyle'] =
          'Responde de forma breve. ${facts['customStyle'] ?? ''}';
    }
    return result;
  }

  static bool withinQuietHours(Map<String, String> facts, DateTime now) {
    if (facts['quietHoursEnabled'] != 'true') return false;
    final start = int.tryParse(facts['quietHoursStart'] ?? '') ?? 1380;
    final end = int.tryParse(facts['quietHoursEnd'] ?? '') ?? 360;
    final minute = now.hour * 60 + now.minute;
    return start == end ||
        (start < end
            ? minute >= start && minute < end
            : minute >= start || minute < end);
  }
}

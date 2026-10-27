// Flujo determinista editable: intención, datos requeridos y pasos ordenados.
final class BusinessDialogue {
  final String id;
  final String intent;
  final List<String> requiredSlots;
  final List<String> steps;

  const BusinessDialogue({
    required this.id,
    required this.intent,
    this.requiredSlots = const [],
    this.steps = const [],
  });

  factory BusinessDialogue.fromJson(Map<String, dynamic> json) =>
      BusinessDialogue(
        id: (json['id'] as String?)?.trim() ?? '',
        intent: (json['intent'] as String?)?.trim() ?? '',
        requiredSlots: _strings(json['requiredSlots']),
        steps: _strings(json['steps']),
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'intent': intent,
    'requiredSlots': requiredSlots,
    'steps': steps,
  };
}

List<String> _strings(Object? raw) => [
  for (final value in raw is List ? raw : const <Object?>[])
    if (value is String && value.trim().isNotEmpty) value.trim(),
];

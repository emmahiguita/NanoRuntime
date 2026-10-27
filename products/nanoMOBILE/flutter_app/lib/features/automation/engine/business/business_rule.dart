// Regla declarativa: describe una condición y la acción segura asociada.
final class BusinessRule {
  final String id;
  final String condition;
  final String action;
  final String priority;

  const BusinessRule({
    required this.id,
    required this.condition,
    required this.action,
    this.priority = 'NORMAL',
  });

  factory BusinessRule.fromJson(Map<String, dynamic> json) => BusinessRule(
    id: (json['id'] as String?)?.trim() ?? '',
    condition: (json['condition'] as String?)?.trim() ?? '',
    action: (json['action'] as String?)?.trim() ?? '',
    priority: (json['priority'] as String?)?.trim() ?? 'NORMAL',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'condition': condition,
    'action': action,
    'priority': priority,
  };
}

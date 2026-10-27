// Pregunta frecuente editable y factual del perfil comercial.
final class BusinessFaq {
  final String id;
  final List<String> questionPatterns;
  final String answer;

  const BusinessFaq({
    required this.id,
    required this.questionPatterns,
    required this.answer,
  });

  factory BusinessFaq.fromJson(Map<String, dynamic> json) => BusinessFaq(
    id: (json['id'] as String?)?.trim() ?? '',
    questionPatterns: [
      for (final value in (json['questionPatterns'] as List?) ?? const [])
        if (value is String && value.trim().isNotEmpty) value.trim(),
    ],
    answer: (json['answer'] as String?)?.trim() ?? '',
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'questionPatterns': questionPatterns,
    'answer': answer,
  };
}

/// Representa únicamente la plantilla que el servidor leyó de Meta.
class MetaMessageTemplate {
  const MetaMessageTemplate({
    required this.id,
    required this.name,
    required this.language,
    required this.category,
    required this.status,
    required this.components,
  });

  final String id;
  final String name;
  final String language;
  final String category;
  final String status;
  final List<Map<String, dynamic>> components;

  /// Convierte el JSON real de Graph API sin inventar valores de estado.
  factory MetaMessageTemplate.fromJson(Map<String, dynamic> json) =>
      MetaMessageTemplate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        language: json['language']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        status: json['status']?.toString() ?? 'UNKNOWN',
        components: [
          for (final item in (json['components'] as List? ?? const []))
            if (item is Map) item.cast<String, dynamic>(),
        ],
      );
}

/// Payload editable que se envía a la API; no es una plantilla publicada.
class MetaMessageTemplateDraft {
  const MetaMessageTemplateDraft({
    required this.name,
    required this.language,
    required this.category,
    required this.components,
  });

  final String name;
  final String language;
  final String category;
  final List<Map<String, dynamic>> components;

  /// Mantiene los nombres oficiales de los campos exigidos por Meta.
  Map<String, dynamic> toJson() => {
    'name': name,
    'language': language,
    'category': category,
    'components': components,
  };
}

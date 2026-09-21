import 'dart:convert';

/// PERSONA-RESPONSE-OPTION — Opción de Respuesta con Metadatos Conversacionales.
///
/// **QUÉ HACE:**
/// Modela una respuesta específica dentro de una frase o intención aprendida,
/// incluyendo su texto, estado de activación, registro de tono y si realiza contrapregunta.
///
/// **CÓMO FUNCIONA:**
/// Almacena atributos tipados y proporciona serialización JSON hacia los campos
/// de metadatos de PersonaExample en SQLite.
///
/// **POR QUÉ:**
/// Permite al Agente EMMA disponer de un catálogo flexible de respuestas por frase,
/// evitando automatizaciones rígidas o monótonas (< 200 líneas).
final class PersonaResponseOption {
  final String text;
  final bool enabled;
  final String tone;
  final bool followUp;
  final String context;

  const PersonaResponseOption({
    required this.text,
    this.enabled = true,
    this.tone = 'cotidiana',
    this.followUp = false,
    this.context = '',
  });

  PersonaResponseOption copyWith({
    String? text,
    bool? enabled,
    String? tone,
    bool? followUp,
    String? context,
  }) {
    return PersonaResponseOption(
      text: text ?? this.text,
      enabled: enabled ?? this.enabled,
      tone: tone ?? this.tone,
      followUp: followUp ?? this.followUp,
      context: context ?? this.context,
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'enabled': enabled,
    'tone': tone,
    'followUp': followUp,
    if (context.isNotEmpty) 'context': context,
  };

  factory PersonaResponseOption.fromMap(dynamic raw) {
    if (raw is String) {
      return PersonaResponseOption(text: raw);
    }
    if (raw is Map) {
      return PersonaResponseOption(
        text: raw['text']?.toString() ?? '',
        enabled: raw['enabled'] != false && raw['enabled'] != 'false',
        tone: raw['tone']?.toString() ?? 'cotidiana',
        followUp: raw['followUp'] == true || raw['followUp'] == 'true',
        context: raw['context']?.toString() ?? '',
      );
    }
    return const PersonaResponseOption(text: '');
  }

  static List<PersonaResponseOption> listFromJson(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map(PersonaResponseOption.fromMap).where((r) => r.text.trim().isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map(PersonaResponseOption.fromMap).where((r) => r.text.trim().isNotEmpty).toList();
        }
      } catch (_) {}
    }
    return const [];
  }
}

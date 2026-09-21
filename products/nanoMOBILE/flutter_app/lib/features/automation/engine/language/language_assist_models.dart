/// Modelos inmutables de datos para el coprocesador lingüístico de Android (< 140 LOC).
///
/// **QUÉ HACE:**
/// Encapsula las estructuras de datos devueltas por el canal nativo `com.nanoai/language_assist`:
/// capacidades de hardware (ICU, SpellChecker), sugerencias ortográficas, idioma detectado
/// y texto normalizado.
///
/// **CÓMO FUNCIONA:**
/// Implementa DTOs inmutables con constructores de fábrica `.fromMap` y métodos de degradación
/// passthrough para plataformas sin soporte nativo o durante pruebas unitarias.
///
/// **POR QUÉ:**
/// Preserva el principio de RAW INPUT IMMUTABILITY: el texto del usuario nunca se muta en origen,
/// manteniendo las sugerencias del sistema como señales auxiliares puras.
library;

/// Capacidades del coprocesador en ESTE dispositivo (A02, runtime).
final class LanguageAssistCapabilities {
  final bool icu;
  final bool spellChecker;
  final bool spellCheckerSpanish;
  final bool languageDetect;
  final bool conversationActions;
  final bool thermalApi;

  const LanguageAssistCapabilities({
    this.icu = false,
    this.spellChecker = false,
    this.spellCheckerSpanish = false,
    this.languageDetect = false,
    this.conversationActions = false,
    this.thermalApi = false,
  });

  factory LanguageAssistCapabilities.fromMap(Map<Object?, Object?>? map) =>
      LanguageAssistCapabilities(
        icu: map?['icu'] == true,
        spellChecker: map?['spellChecker'] == true,
        spellCheckerSpanish: map?['spellCheckerSpanish'] == true,
        languageDetect: map?['languageDetect'] == true,
        conversationActions: map?['conversationActions'] == true,
        thermalApi: map?['thermalApi'] == true,
      );

  static const unavailable = LanguageAssistCapabilities();
}

/// Señal de idioma (TextClassifier.detectLanguage). Confianza 0..1.
final class LanguageHint {
  final String language;
  final String locale;
  final double confidence;

  const LanguageHint({
    required this.language,
    required this.locale,
    required this.confidence,
  });

  factory LanguageHint.fromMap(Map<Object?, Object?>? map) => LanguageHint(
    language: (map?['language'] as String?) ?? '',
    locale: (map?['locale'] as String?) ?? '',
    confidence: (map?['confidence'] as num?)?.toDouble() ?? 0,
  );
}

/// Palabra con sugerencias del corrector del sistema. El texto crudo queda
/// intacto; esto es SOLO señal para el escalón pragmático.
final class SpellFlag {
  final int start;
  final int length;
  final List<String> suggestions;

  const SpellFlag({
    required this.start,
    required this.length,
    this.suggestions = const [],
  });

  factory SpellFlag.fromMap(Map<Object?, Object?> map) => SpellFlag(
    start: (map['start'] as num?)?.toInt() ?? 0,
    length: (map['length'] as num?)?.toInt() ?? 0,
    suggestions: [
      for (final s in map['suggestions'] as List<Object?>? ?? const [])
        if (s is String && s.isNotEmpty) s,
    ],
  );
}

/// Hint de acción conversacional (A06). Señal, jamás autoridad.
final class ConversationActionHint {
  final String type;
  final String textReply;
  final double confidence;

  const ConversationActionHint({
    required this.type,
    required this.textReply,
    required this.confidence,
  });

  factory ConversationActionHint.fromMap(Map<Object?, Object?> map) =>
      ConversationActionHint(
        type: (map['type'] as String?) ?? '',
        textReply: (map['textReply'] as String?) ?? '',
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// Resultado del análisis de input. `raw` es el texto original del usuario.
final class LanguageAssistInput {
  final String raw;

  /// NFKC + trim. Si ICU no está disponible coincide con [raw].
  final String normalized;
  final int wordCount;
  final int sentenceCount;
  final LanguageHint? language;
  final List<SpellFlag> spell;
  final List<ConversationActionHint> actions;

  const LanguageAssistInput({
    required this.raw,
    required this.normalized,
    this.wordCount = 0,
    this.sentenceCount = 0,
    this.language,
    this.spell = const [],
    this.actions = const [],
  });

  /// true cuando hay señales útiles del coprocesador (normalización real).
  bool get assisted => normalized != raw || spell.isNotEmpty;

  /// Copia degradada para pipelines sin canal (tests, desktop).
  static LanguageAssistInput passthrough(String raw) => LanguageAssistInput(
    raw: raw,
    normalized: raw.trim(),
    wordCount: raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    sentenceCount: raw.trim().isEmpty ? 0 : 1,
  );
}

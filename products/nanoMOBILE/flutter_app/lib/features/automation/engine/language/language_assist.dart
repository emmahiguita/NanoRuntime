/// LanguageAssist (A03-A06) — Android como coprocesador lingüístico.
///
/// Fachada Dart del canal `com.nanoai/language_assist`
/// (LanguageAssistChannelHandler.kt). Invariante del brief:
///
///   RAW INPUT MUST REMAIN IMMUTABLE
///
/// El texto crudo del usuario NUNCA se reescribe: `normalized` es una copia
/// de trabajo para matching/segmentación y las sugerencias del corrector son
/// señales (offset + candidatos), jamás reemplazos automáticos.
///
/// Degradación honesta: cualquier ausencia de canal/timeout/error produce
/// resultado con `normalized == raw` y señales vacías — el pipeline sigue
/// por LLM (fail-open a comprensión, nunca inventar fast reply).
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../../../../core/services/nano_runtime_api.dart';

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

/// Servicio del coprocesador lingüístico.
///
/// Threading: cada llamada va con timeout propio; el total del análisis
/// nunca excede ~2s en el peor caso (y normalmente <100ms). El caller decide
/// si espera o sigue sin señales (A09 escalation).
class LanguageAssistService {
  static const _channel = MethodChannel(NanoRuntimeChannels.languageAssist);

  /// Timeouts cortos: señales baratas, el turno nunca queda colgado.
  static const normalizeTimeout = Duration(milliseconds: 300);
  static const spellTimeout = Duration(milliseconds: 800);
  static const languageTimeout = Duration(milliseconds: 1500);
  static const actionsTimeout = Duration(milliseconds: 1500);

  Future<LanguageAssistCapabilities>? _caps;

  Future<LanguageAssistCapabilities> capabilities() => _caps ??=
      _capabilities().catchError((_) => LanguageAssistCapabilities.unavailable);

  Future<LanguageAssistCapabilities> _capabilities() async {
    final map = await _channel
        .invokeMapMethod<Object?, Object?>('capabilities')
        .timeout(normalizeTimeout);
    return LanguageAssistCapabilities.fromMap(map);
  }

  /// Normalización ICU (síncrona en nativo, µs). Nunca lanza.
  Future<LanguageAssistInput> normalizeOnly(String raw) async {
    try {
      final map = await _channel
          .invokeMapMethod<Object?, Object?>('normalize', {'text': raw})
          .timeout(normalizeTimeout);
      return LanguageAssistInput(
        raw: raw,
        normalized: (map?['normalized'] as String?)?.trim() ?? raw,
        wordCount: (map?['wordCount'] as num?)?.toInt() ?? 0,
        sentenceCount: (map?['sentenceCount'] as num?)?.toInt() ?? 0,
      );
    } on Object {
      return LanguageAssistInput.passthrough(raw);
    }
  }

  /// Análisis completo de input: normalize + spell + language. Las señales
  /// lentas se degradan individualmente (una que falle no tumba al resto).
  Future<LanguageAssistInput> analyzeInput(String raw) async {
    final base = await normalizeOnly(raw);

    final results = await Future.wait<Object?>([
      _spellFlags(raw),
      _languageHint(raw),
    ]);
    return LanguageAssistInput(
      raw: raw,
      normalized: base.normalized,
      wordCount: base.wordCount,
      sentenceCount: base.sentenceCount,
      spell: results[0] as List<SpellFlag>,
      language: results[1] as LanguageHint?,
    );
  }

  Future<List<SpellFlag>> _spellFlags(String raw) async {
    if (raw.trim().isEmpty) return const [];
    try {
      final map = await _channel
          .invokeMapMethod<Object?, Object?>('spellCheck', {'text': raw})
          .timeout(spellTimeout);
      final words = map?['words'] as List<Object?>? ?? const [];
      return [
        for (final w in words)
          if (w is Map) SpellFlag.fromMap(w.cast<Object?, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  Future<LanguageHint?> _languageHint(String raw) async {
    if (raw.trim().isEmpty) return null;
    try {
      final map = await _channel
          .invokeMapMethod<Object?, Object?>('detectLanguage', {'text': raw})
          .timeout(languageTimeout);
      final hint = LanguageHint.fromMap(map);
      return hint.language.isEmpty ? null : hint;
    } on Object {
      return null;
    }
  }

  /// A12 — estado térmico del sistema (PowerManager.getCurrentThermalStatus,
  /// API 29+). -1 = no disponible. Constantes Android:
  /// 0 none, 1 light, 2 moderate, 3 severe, 4 critical, 5 emergency, 6 shutdown.
  /// SEVERE+ (>=3) suprime la inferencia opcional (jamás la seguridad).
  Future<int> thermalStatus() async {
    try {
      final v = await _channel
          .invokeMethod<int>('thermalStatus')
          .timeout(normalizeTimeout);
      return v ?? -1;
    } on Object {
      return -1;
    }
  }

  /// Hints de acciones conversacionales (A06). Solo bajo demanda.
  Future<List<ConversationActionHint>> conversationActions(String raw) async {
    if (raw.trim().isEmpty) return const [];
    try {
      final list = await _channel
          .invokeListMethod<Object?>('conversationActions', {'text': raw})
          .timeout(actionsTimeout);
      return [
        for (final a in list ?? const <Object?>[])
          if (a is Map) ConversationActionHint.fromMap(a.cast<Object?, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  /// Correcciones SAFE y deterministas de la salida de Nano (A10). Sin LLM,
  /// sin mutar semántica: colapso de puntuación duplicada y espacios.
  /// STYLE != ERROR — jamás se corrigen acentos ni se reescribe vocabulario.
  static String safeCleanOutput(String draft) {
    var out = draft.trim();
    if (out.isEmpty) return out;
    // "??" / "!!" / ",," repetidos → uno solo. Determinista e inofensivo.
    out = out.replaceAll(RegExp(r'\?{2,}'), '?');
    out = out.replaceAll(RegExp(r'!{2,}'), '!');
    out = out.replaceAll(RegExp(r',{2,}'), ',');
    out = out.replaceAll(RegExp(r'\.{3,}'), '...');
    // Espacios accidentales antes de signos de puntuación.
    out = out.replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1');
    // Dobles espacios internos → uno.
    out = out.replaceAll(RegExp(r' {2,}'), ' ');
    return out.trim();
  }
}

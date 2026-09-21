/// LanguageAssist (A03-A06) — Android como coprocesador lingüístico (< 190 LOC).
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
import 'language_assist_models.dart';

export 'language_assist_models.dart';

/// Servicio del coprocesador lingüístico de Android.
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

  /// Análisis completo de input: normalize + spell + language.
  Future<LanguageAssistInput> analyzeInput(String raw) async {
    final base = await normalizeOnly(raw);

    final results = await Future.wait<Object?>([
      _spellFlags(raw),
      _languageHint(raw),
    ]);

    final spell = (results[0] as List<SpellFlag>?) ?? const [];
    final lang = results[1] as LanguageHint?;

    return LanguageAssistInput(
      raw: raw,
      normalized: base.normalized,
      wordCount: base.wordCount,
      sentenceCount: base.sentenceCount,
      language: lang,
      spell: spell,
    );
  }

  /// Pide acciones conversacionales al TextClassifier del sistema (A06).
  Future<List<ConversationActionHint>> suggestActions(
    List<({String text, bool isSelf, int atMs})> recentTurns,
  ) async {
    if (recentTurns.isEmpty) return const [];
    try {
      final turnsPayload = [
        for (final t in recentTurns)
          {'text': t.text, 'isSelf': t.isSelf, 'atMs': t.atMs},
      ];
      final list = await _channel
          .invokeListMethod<Object?>('suggestActions', {'turns': turnsPayload})
          .timeout(actionsTimeout);
      if (list == null) return const [];
      return [
        for (final item in list)
          if (item is Map<Object?, Object?>)
            ConversationActionHint.fromMap(item),
      ];
    } on Object {
      return const [];
    }
  }

  /// A12 — estado térmico del sistema (PowerManager.getCurrentThermalStatus, API 29+).
  Future<int> thermalStatus() async {
    try {
      final v = await _channel.invokeMethod<int>('thermalStatus').timeout(normalizeTimeout);
      return v ?? -1;
    } on Object {
      return -1;
    }
  }

  /// Hints de acciones conversacionales (A06). Solo bajo demanda.
  Future<List<ConversationActionHint>> conversationActions(String raw) async {
    if (raw.trim().isEmpty) return const [];
    try {
      final list = await _channel.invokeListMethod<Object?>('conversationActions', {'text': raw}).timeout(actionsTimeout);
      return [
        for (final a in list ?? const <Object?>[])
          if (a is Map) ConversationActionHint.fromMap(a.cast<Object?, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  /// Correcciones SAFE y deterministas de la salida de Nano (A10).
  static String safeCleanOutput(String draft) {
    var out = draft.trim();
    if (out.isEmpty) return out;
    out = out.replaceAll(RegExp(r'\?{2,}'), '?');
    out = out.replaceAll(RegExp(r'!{2,}'), '!');
    out = out.replaceAll(RegExp(r',{2,}'), ',');
    out = out.replaceAll(RegExp(r'\.{3,}'), '...');
    out = out.replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1');
    out = out.replaceAll(RegExp(r' {2,}'), ' ');
    return out.trim();
  }

  Future<List<SpellFlag>> _spellFlags(String text) async {
    if (text.trim().isEmpty) return const [];
    try {
      final list = await _channel.invokeListMethod<Object?>('spellCheck', {'text': text}).timeout(spellTimeout);
      final words = list ?? const [];
      return [
        for (final w in words)
          if (w is Map) SpellFlag.fromMap(w.cast<Object?, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  Future<LanguageHint?> _languageHint(String text) async {
    if (text.trim().isEmpty) return null;
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('detectLanguage', {'text': text}).timeout(languageTimeout);
      final hint = LanguageHint.fromMap(map);
      return hint.language.isEmpty ? null : hint;
    } on Object {
      return null;
    }
  }
}

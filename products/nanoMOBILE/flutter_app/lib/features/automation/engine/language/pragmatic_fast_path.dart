/// PragmaticFastPath (A07) — motor de diálogo determinista sin LLM (< 190 LOC).
///
/// **QUÉ HACE:**
/// Comprende y resuelve turnos conversacionales cotidianos en < 5ms:
/// saludos, bienestar, reciprocidad, actividad/planes, situaciones, presencia y ayuda.
///
/// **CÓMO FUNCIONA:**
/// Clasifica intenciones y consulta bancos inmutables de candidatos (> 10 opciones).
///
/// **POR QUÉ:**
/// Arquitectura Android-First y Clean Architecture modular (< 200 LOC por archivo).
library;

import '../../../../core/services/device_metrics.dart' show DeviceMetrics, DeviceMetricsData;
import '../../personal_agent/domain/conversation_agent_role.dart'
    show correctionPhrases, commercialIntentTokens, supportPhrases;
import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import '../messaging/conv_turn_state.dart' show ClientContextEntry, isPureGreeting;
import '../messaging/conversation_memory.dart' show ConversationMemory, ConversationMemoryEntryKind;
import '../notifications/conversation_understanding.dart';
import 'fast_path_models.dart';
import 'temporal_location_context.dart';
import 'turn_complexity_classifier.dart' show turnComplexityClassifier;

export 'fast_path_models.dart';

part 'candidate_selector.dart';
part 'pragmatic_fast_path_activity.dart';
part 'pragmatic_fast_path_activity_banks.dart';
part 'pragmatic_fast_path_composer.dart';
part 'pragmatic_fast_path_composer_misc.dart';
part 'pragmatic_fast_path_dialogue_banks.dart';
part 'pragmatic_fast_path_intents.dart';
part 'pragmatic_fast_path_intents_basic.dart';
part 'pragmatic_fast_path_intents_contextual.dart';
part 'pragmatic_fast_path_intents_situational.dart';
part 'pragmatic_fast_path_misc_banks.dart';
part 'pragmatic_fast_path_narrative.dart';
part 'pragmatic_fast_path_situation_banks.dart';
part 'pragmatic_fast_path_situations.dart';
part 'pragmatic_fast_path_template_banks.dart';
part 'pragmatic_fast_path_templates.dart';

final class PragmaticFastPath {
  final ConversationMemory? Function(String conversationId)? memoryFor;
  final ClientContextEntry? Function(String conversationId)? contextEntryFor;
  final String? Function()? ownerName;
  final Future<DeviceMetricsData> Function()? metricsSource;

  const PragmaticFastPath({this.memoryFor, this.contextEntryFor, this.ownerName, this.metricsSource});

  static DeviceMetricsData? _cachedMetrics;
  static DateTime? _lastMetricsFetch;
  static const _metricsTtl = Duration(seconds: 10);

  Future<DeviceMetricsData?> _getMetrics() async {
    final now = DateTime.now();
    if (_cachedMetrics != null && _lastMetricsFetch != null && now.difference(_lastMetricsFetch!) < _metricsTtl) {
      return _cachedMetrics;
    }
    try {
      final m = await (metricsSource?.call() ?? DeviceMetrics.fetch());
      _cachedMetrics = m;
      _lastMetricsFetch = now;
      return m;
    } catch (_) {
      return null;
    }
  }

  /// Resuelve el turno conversacional o devuelve null para escalar a estilo / catálogo / LLM.
  Future<FastPathCandidate?> resolve({
    required String text,
    required String conversationId,
    ConversationMemory? memoryOverride,
  }) async {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    final normalized = normalizeText(raw);
    final tokens = tokenizeText(normalized);
    if (tokens.isEmpty) return null;

    // 1. Guardias de escape estricto: Comercio, Soporte, Corrección, Comandos
    if (_hasCommercialOrCommandSignal(normalized, tokens)) return null;

    // 2. Escape de contenido narrativo / sustantivo / estado personal
    if (_PragmaticFastPathNarrative.hasSubstantiveNarrative(normalized, tokens)) {
      return null;
    }

    // 3. Extraer el conjunto de intenciones comunicativas
    final intents = _extractIntents(normalized, tokens);
    if (intents.isEmpty) return null;

    // 4. Si la conversación tiene obligaciones pendientes activas
    // El compositor puede entregar memoria ya unificada entre nombre y JID.
    final memory = memoryOverride ?? memoryFor?.call(conversationId);
    if (memory != null && memory.unresolvedObligations.isNotEmpty) {
      final isGreeting = intents.contains(ConversationIntent.greeting) || isPureGreeting(raw);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final isStale = memory.lastAtMs > 0 && (nowMs - memory.lastAtMs) > 900000;
      if (!isGreeting && !isStale) return null;
    }

    // 5. Consultar hechos de hardware bajo demanda SOLO si la intención lo pide
    DeviceMetricsData? metrics;
    if (intents.contains(ConversationIntent.askDeviceBattery)) {
      metrics = await _getMetrics();
    }

    // 6. Inspeccionar historial de conversación reciente para anti-repetición y anti-bucle
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var recentlyGreeted = false;
    String? lastOutboundText;

    if (memory != null && memory.entries.isNotEmpty) {
      final recent = memory.entries.reversed.take(10);
      for (final entry in recent) {
        if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
            entry.kind == ConversationMemoryEntryKind.outboundDispatched ||
            entry.kind == ConversationMemoryEntryKind.outboundObservedManual) {
          lastOutboundText ??= entry.text;
          if (nowMs - entry.atMs < 900000) recentlyGreeted = true;
        }
        if (nowMs - entry.atMs < 900000) {
          final folded = normalizeText(entry.text);
          const greetingKeywords = [
            'hola',
            'buenas',
            'buen dia',
            'buenos dias',
            'que mas',
            'quiubo',
            'como estas',
            'como te va',
            'todo bien',
          ];
          if (greetingKeywords.any(folded.contains)) {
            recentlyGreeted = true;
          }
        }
      }
    }

    // 7. Componer la respuesta unificada y natural
    final result = _composeUnifiedReply(
      intents: intents,
      normalized: normalized,
      tokens: tokens,
      conversationId: conversationId,
      recentlyGreeted: recentlyGreeted,
      lastOutboundText: lastOutboundText,
      metrics: metrics,
    );

    if (result == null || result.reply.trim().isEmpty) return null;

    final actLabel = intents.map((i) => i.name).join('+');
    const respondingIntents = {
      ConversationIntent.reciprocalQuestion,
      ConversationIntent.userWellbeing,
      ConversationIntent.negation,
      ConversationIntent.affirmation,
      ConversationIntent.askRap,
      ConversationIntent.invitation,
      ConversationIntent.wellbeingClarification,
      ConversationIntent.askAvailability,
      ConversationIntent.askFood,
      ConversationIntent.askPhysicalLocation,
      ConversationIntent.askFamily,
      ConversationIntent.askSleep,
      ConversationIntent.askMusic,
      ConversationIntent.askWeatherSocial,
      ConversationIntent.askCall,
      ConversationIntent.askLostOrMissing,
      ConversationIntent.askOpinionSocial,
    };
    final isResponse = intents.any(respondingIntents.contains);

    return FastPathCandidate(
      act: actLabel,
      reply: result.reply,
      suggestions: result.suggestions,
      understanding: ConversationUnderstanding(
        reply: result.reply,
        options: result.suggestions,
        intent: actLabel,
        relation: isResponse ? 'responde' : 'nuevo',
        questions: const [],
        missingFacts: const [],
        requiresAction: false,
      ),
    );
  }
}

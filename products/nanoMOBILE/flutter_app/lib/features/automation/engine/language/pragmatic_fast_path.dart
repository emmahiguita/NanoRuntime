/// PragmaticFastPath — motor de diálogo determinista sin LLM (< 200 LOC).
/// QUÉ HACE: resuelve turnos conversacionales en < 5ms (saludos, bienestar, reciprocidad).
/// CÓMO FUNCIONA: clasifica intenciones y consulta bancos inmutables de candidatos (> 10 opciones).
/// POR QUÉ: arquitectura Android-First y Clean Architecture modular (< 200 LOC).
library;

import '../../../../core/services/device_metrics.dart' show DeviceMetrics, DeviceMetricsData;
import '../../personal_agent/application/conversation_decision_guards.dart' show ConversationDecisionGuards;
import '../../personal_agent/domain/conversation_agent_role.dart' show correctionPhrases, commercialIntentTokens, supportPhrases;
import '../../personal_agent/domain/owner_live_fact_guard.dart' show intentNeedsOwnerLiveFact;
import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import '../messaging/conv_turn_state.dart' show ClientContextEntry, isPureGreeting;
import '../messaging/conversation_memory.dart' show ConversationMemory, ConversationMemoryEntryKind;
import '../notifications/conversation_understanding.dart';
import 'fast_path_models.dart';
import 'safe_repair_options.dart';
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

  const PragmaticFastPath({
    this.memoryFor,
    this.contextEntryFor,
    this.ownerName,
    this.metricsSource,
  });

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
    if (_PragmaticFastPathNarrative.hasSubstantiveNarrative(
      normalized,
      tokens,
    )) {
      return null;
    }

    // 3. Extraer el conjunto de intenciones comunicativas
    final intents = _extractIntents(normalized, tokens);
    if (intents.isEmpty) return null;

    // 4. Ciclo 13: FastPath = optimización, no cerebro conversacional.
    final memory = memoryOverride ?? memoryFor?.call(conversationId);
    if (intents.any((i) =>
        i.routingClass == FastPathRoutingClass.liveStateRequired ||
        i.routingClass == FastPathRoutingClass.llmRequired)) {
      return null;
    }
    final hasContextRequired = intents.any((i) => i.routingClass == FastPathRoutingClass.contextRequired);
    if (hasContextRequired &&
        (intents.length >= 2 || tokens.length > 5 || (memory != null && memory.entries.isNotEmpty))) {
      return null;
    }

    // 5. Si la conversación tiene obligaciones pendientes activas
    if (memory != null && memory.unresolvedObligations.isNotEmpty) {
      final isGreeting = intents.contains(ConversationIntent.greeting) || isPureGreeting(raw);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final isStale = memory.lastAtMs > 0 && (nowMs - memory.lastAtMs) > 900000;
      if (!isGreeting && !isStale) return null;
    }

    DeviceMetricsData? metrics;
    if (intents.contains(ConversationIntent.askDeviceBattery)) {
      metrics = await _getMetrics();
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var recentlyGreeted = false;
    String? lastOutboundText;

    if (memory != null && memory.entries.isNotEmpty) {
      for (final entry in memory.entries.reversed.take(10)) {
        final isOut = entry.kind == ConversationMemoryEntryKind.outboundVerified ||
            entry.kind == ConversationMemoryEntryKind.outboundDispatched ||
            entry.kind == ConversationMemoryEntryKind.outboundObservedManual;
        if (isOut) lastOutboundText ??= entry.text;
        if (entry.kind != ConversationMemoryEntryKind.outboundDispatched &&
            entry.kind != ConversationMemoryEntryKind.effectUnknown &&
            nowMs - entry.atMs < 900000 && _isGreetingSnippet(entry.text)) {
          recentlyGreeted = true;
        }
      }
    }

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
    final needsOwnerFact = intentNeedsOwnerLiveFact(intents.map((i) => i.name));
    final isResponse = intents.any(_isRespondingIntent);

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
        missingFacts: needsOwnerFact ? const ['estado actual del dueño'] : const [],
        requiresAction: false,
      ),
    );
  }

  static bool _isGreetingSnippet(String text) {
    final f = normalizeText(text);
    return const [
      'hola', 'buenas', 'buen dia', 'buenos dias', 'que mas', 'quiubo',
      'como estas', 'como te va', 'todo bien'
    ].any(f.contains);
  }

  static bool _isRespondingIntent(ConversationIntent i) {
    const responding = {
      ConversationIntent.reciprocalQuestion, ConversationIntent.userWellbeing,
      ConversationIntent.socialReassurance, ConversationIntent.userCorrection,
      ConversationIntent.negation, ConversationIntent.affirmation,
      ConversationIntent.askRap, ConversationIntent.invitation,
      ConversationIntent.askAvailability, ConversationIntent.askFood,
      ConversationIntent.askPhysicalLocation, ConversationIntent.askFamily,
      ConversationIntent.askSleep, ConversationIntent.askMusic,
      ConversationIntent.askWeatherSocial, ConversationIntent.askCall,
      ConversationIntent.askLostOrMissing, ConversationIntent.askOpinionSocial,
    };
    return responding.contains(i);
  }
}

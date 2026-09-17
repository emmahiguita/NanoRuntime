/// PragmaticFastPath (A07) — motor de diálogo pragmático y lingüístico sin LLM.
///
/// ANDROID FIRST / DETERMINISTIC SECOND / SMALL LLM LAST:
/// Comprende y resuelve turnos conversacionales cotidianos en < 5ms:
/// - Saludos simples y compuestos ("hola", "hola emma", "buenas tardes")
/// - Chequeo y estado de bienestar ("cómo estás", "qué tal", "todo bien?")
/// - Preguntas recíprocas ("bien y tú", "bien y vos", "todo bien y tú?")
/// - Preguntas de actividad / día ("qué haces", "en qué andas", "qué tal tu día")
/// - Preguntas de entreno / live state con honestidad
/// - Preguntas de presencia ("estás ahí?", "sigues por ahí?")
/// - Solicitudes de ayuda o preguntas ("parce lo necesito para una tarea")
/// - Multi-intentos en una sola frase integrada
/// - Agradecimientos y despedidas ("gracias", "chao", "nos vemos")
///
/// Modularizado bajo SOLID y Clean Architecture (< 250 líneas por archivo).
library;

import '../../../../core/services/device_metrics.dart'
    show DeviceMetrics, DeviceMetricsData;
import '../../personal_agent/domain/conversation_agent_role.dart'
    show correctionPhrases, commercialIntentTokens, supportPhrases;
import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import '../messaging/conv_turn_state.dart'
    show ClientContextEntry, isPureGreeting;
import '../messaging/conversation_memory.dart'
    show ConversationMemory, ConversationMemoryEntryKind;
import '../notifications/conversation_understanding.dart';
import 'temporal_location_context.dart';
import 'turn_complexity_classifier.dart' show turnComplexityClassifier;

part 'pragmatic_fast_path_intents.dart';
part 'pragmatic_fast_path_narrative.dart';
part 'pragmatic_fast_path_composer.dart';
part 'pragmatic_fast_path_templates.dart';
part 'pragmatic_fast_path_situations.dart';

/// Intento comunicativo elemental detectado en el texto.
enum ConversationIntent {
  greeting,
  askWellbeing,
  userWellbeing,
  reciprocalQuestion,
  askActivity,
  askDay,
  askTraining,
  askRap,
  invitation,
  askPresence,
  askHelpOrQuestion,
  askDeviceBattery,
  askTime,
  askDate,
  askLocation,
  planReminder,
  thanks,
  farewell,
  laughter,
  affirmation,
  negation,
  wellbeingClarification,
  askAvailability,
  askFood,
  askPhysicalLocation,
  askFamily,
  askSleep,
  askMusic,
  askWeatherSocial,
  askCall,
  askLostOrMissing,
  askOpinionSocial,
}

final class FastPathCandidate {
  final String act;
  final String reply;
  final ConversationUnderstanding understanding;
  final List<String> suggestions;

  const FastPathCandidate({
    required this.act,
    required this.reply,
    required this.understanding,
    this.suggestions = const [],
  });
}

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
    if (_cachedMetrics != null &&
        _lastMetricsFetch != null &&
        now.difference(_lastMetricsFetch!) < _metricsTtl) {
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
  }) async {
    final raw = text.trim();
    if (raw.isEmpty) return null;

    final normalized = normalizeText(raw);
    final tokens = tokenizeText(normalized);
    if (tokens.isEmpty) return null;

    // 1. Guardias de escape estricto: Comercio, Soporte, Corrección, Comandos
    if (_hasCommercialOrCommandSignal(normalized, tokens)) {
      return null;
    }

    // 2. Escape de contenido narrativo / sustantivo / estado personal
    if (_PragmaticFastPathNarrative.hasSubstantiveNarrative(normalized, tokens)) {
      return null;
    }

    // 3. Extraer el conjunto de intenciones comunicativas
    final intents = _extractIntents(normalized, tokens);
    if (intents.isEmpty) return null;

    // 4. Si la conversación tiene obligaciones pendientes activas
    final memory = memoryFor?.call(conversationId);
    if (memory != null && memory.unresolvedObligations.isNotEmpty) {
      final isGreeting = intents.contains(ConversationIntent.greeting) ||
          isPureGreeting(raw);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final isStale = memory.lastAtMs > 0 && (nowMs - memory.lastAtMs) > 900000;
      if (!isGreeting && !isStale) {
        return null;
      }
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
          // Si hubo cualquier mensaje saliente en los últimos 15 min, la conversación ya está abierta
          if (nowMs - entry.atMs < 900000) {
            recentlyGreeted = true;
          }
        }
        // Si en los últimos 15 min hubo saludo o bienestar por cualquiera de los dos lados
        if (nowMs - entry.atMs < 900000) {
          final folded = normalizeText(entry.text);
          if (folded.contains('hola') ||
              folded.contains('buenas') ||
              folded.contains('buen dia') ||
              folded.contains('buenos dias') ||
              folded.contains('que mas') ||
              folded.contains('quiubo') ||
              folded.contains('como estas') ||
              folded.contains('como te va') ||
              folded.contains('todo bien')) {
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
    return FastPathCandidate(
      act: actLabel,
      reply: result.reply,
      suggestions: result.suggestions,
      understanding: ConversationUnderstanding(
        reply: result.reply,
        options: result.suggestions,
        intent: actLabel,
        relation:
            intents.contains(ConversationIntent.reciprocalQuestion) ||
                intents.contains(ConversationIntent.userWellbeing) ||
                intents.contains(ConversationIntent.negation) ||
                intents.contains(ConversationIntent.affirmation) ||
                intents.contains(ConversationIntent.askRap) ||
                intents.contains(ConversationIntent.invitation) ||
                intents.contains(ConversationIntent.wellbeingClarification) ||
                intents.contains(ConversationIntent.askAvailability) ||
                intents.contains(ConversationIntent.askFood) ||
                intents.contains(ConversationIntent.askPhysicalLocation) ||
                intents.contains(ConversationIntent.askFamily) ||
                intents.contains(ConversationIntent.askSleep) ||
                intents.contains(ConversationIntent.askMusic) ||
                intents.contains(ConversationIntent.askWeatherSocial) ||
                intents.contains(ConversationIntent.askCall) ||
                intents.contains(ConversationIntent.askLostOrMissing) ||
                intents.contains(ConversationIntent.askOpinionSocial)
            ? 'responde'
            : 'nuevo',
        questions: const [],
        missingFacts: const [],
        requiresAction: false,
      ),
    );
  }
}

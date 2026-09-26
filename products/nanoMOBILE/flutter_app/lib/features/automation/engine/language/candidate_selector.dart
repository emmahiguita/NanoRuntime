// candidate_selector.dart
//
// QUÉ HACE:
// Selecciona deterministamente respuestas candidatas en fast-path garantizando variedad
// conversacional, naturalidad y anti-repetición de mensajes salientes.
//
// CÓMO FUNCIONA:
// - Consulta los últimos mensajes salientes en `ConversationMemory` para esa conversación
//   y descarta del pool de candidatos las frases emitidas recientemente.
// - Combina el ID de conversación, la intención y el conteo de turnos (seed determinista).
// - Provee hasta 3 sugerencias alternativas distintas para selección rápida.
//
// POR QUÉ:
// Resuelve AUT-P2-11 (repetición semántica) manteniendo el archivo estrictamente < 200 líneas (SOLID-SRP).

part of 'pragmatic_fast_path.dart';

/// Selector determinista multicriterio de respuestas para el Agente Personal (Ciclo 8).
abstract final class PersonalResponseSelector {
  static List<String> extractRecentOutbound(
    ConversationMemory? memory, {
    String? lastOutboundText,
    int maxEntries = 5,
  }) {
    final recent = <String>[];
    if (lastOutboundText != null && lastOutboundText.trim().isNotEmpty) {
      recent.add(normalizeText(lastOutboundText));
    }
    if (memory != null && memory.entries.isNotEmpty) {
      for (final entry in memory.entries.reversed) {
        if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
            entry.kind == ConversationMemoryEntryKind.outboundDispatched ||
            entry.kind == ConversationMemoryEntryKind.outboundObservedManual) {
          final norm = normalizeText(entry.text);
          if (norm.isNotEmpty && !recent.contains(norm)) {
            recent.add(norm);
            if (recent.length >= maxEntries) break;
          }
        }
      }
    }
    return recent;
  }

  static double scoreCandidate({
    required String candidate,
    required String userText,
    required List<String> recentOutbound,
    bool allowLiveActivity = false,
  }) {
    final normCand = normalizeText(candidate);
    if (normCand.isEmpty) return -1.0;
    final normUser = normalizeText(userText);
    final candTokens = tokenizeText(normCand).toSet();
    final userTokens = tokenizeText(normUser).toSet();

    var score = 0.70;

    // 1. Factualidad: nunca afirmar actividad temporal del dueño sin evidencia viva
    if (!allowLiveActivity && ConversationDecisionGuards.affirmsOwnerActivity(candidate)) {
      score -= 0.85;
    }

    // 2. Estilo y relación: prohibir frases robóticas o de soporte
    if (ConversationDecisionGuards.isCallCenterPhrase(candidate)) {
      score -= 0.80;
    }

    // 3. No-eco: penalizar repetición literal o cuasi-literal del turno entrante
    if (normUser.isNotEmpty) {
      if (normCand == normUser) return -1.0;
      if (userTokens.length >= 2 && candTokens.isNotEmpty) {
        final overlap = candTokens.intersection(userTokens).length / candTokens.length;
        if (overlap >= 0.85) score -= 0.75;
      }
    }

    // 4. No-repetición contra salidas recientes en ConversationMemory
    for (var i = 0; i < recentOutbound.length; i++) {
      final prev = recentOutbound[i];
      if (prev == normCand) {
        score -= (i == 0 ? 0.90 : 0.75);
        break;
      }
      final prevTokens = tokenizeText(prev).toSet();
      if (candTokens.isNotEmpty && prevTokens.isNotEmpty) {
        final union = candTokens.union(prevTokens).length;
        final jaccard = candTokens.intersection(prevTokens).length / union;
        if (jaccard >= 0.65) {
          score -= (i == 0 ? 0.50 : 0.35);
          break;
        }
      }
    }

    // 5. Intención actual y especificidad: evitar monosílabos ante turnos compuestos/preguntas
    final hasQuestion = userText.contains('?') || userText.contains('¿') ||
        userTokens.any(const {'que', 'como', 'cuando', 'donde', 'cual', 'quien', 'vas', 'tienes', 'puedes'}.contains);
    if ((hasQuestion || userTokens.length >= 3) && candTokens.length <= 2) {
      score -= 0.28;
    } else if (candTokens.length >= 4 && candTokens.length <= 20) {
      score += 0.14;
    }

    // 6. Naturalidad y marcadores del registro personal
    if (_personalRegisterMarkers.any(normCand.contains)) {
      score += 0.08;
    }

    return score.clamp(-1.0, 1.0);
  }

  static ({String reply, List<String> suggestions}) selectFromPool({
    required List<String> pool,
    required String conversationId,
    ConversationMemory? memory,
    String? lastOutboundText,
    String userText = '',
    bool allowLiveActivity = false,
  }) {
    if (pool.isEmpty) {
      return (reply: 'Todo bien por acá.', suggestions: const ['Todo bien por acá.']);
    }

    final recentOutbound = extractRecentOutbound(
      memory,
      lastOutboundText: lastOutboundText,
    );

    final uniquePool = <String>[];
    for (final item in pool) {
      if (item.trim().isNotEmpty && !uniquePool.contains(item)) {
        uniquePool.add(item);
      }
    }
    if (uniquePool.isEmpty) {
      return (reply: pool.first, suggestions: [pool.first]);
    }

    final scored = uniquePool
        .map((c) => (
              candidate: c,
              score: scoreCandidate(
                candidate: c,
                userText: userText,
                recentOutbound: recentOutbound,
                allowLiveActivity: allowLiveActivity,
              ),
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final bestScore = scored.first.score;
    final topBand = scored
        .where((entry) => entry.score >= bestScore - 0.06)
        .map((entry) => entry.candidate)
        .toList();

    final turnOffset = memory?.entries.length ?? 0;
    final seed = (conversationId.hashCode ^ uniquePool.first.hashCode ^ turnOffset).abs();
    final selected = topBand[seed % topBand.length];

    final suggestions = <String>[selected];
    for (final entry in scored) {
      if (!suggestions.contains(entry.candidate) && suggestions.length < 3) {
        suggestions.add(entry.candidate);
      }
    }

    return (reply: selected, suggestions: suggestions);
  }

  static const List<String> _personalRegisterMarkers = [
    'todo bien', 'gracias a dios', 'por aca', 'cuentame', 'dime', 'tranquilo', 'en orden',
  ];
}

extension _CandidateSelector on PragmaticFastPath {
  ({String reply, List<String> suggestions}) _selectCandidate(
    List<String> pool,
    String conversationId,
    String? lastOutboundText,
  ) {
    final mem = conversationId.isNotEmpty ? memoryFor?.call(conversationId) : null;
    return PersonalResponseSelector.selectFromPool(
      pool: pool,
      conversationId: conversationId,
      memory: mem,
      lastOutboundText: lastOutboundText,
    );
  }
}

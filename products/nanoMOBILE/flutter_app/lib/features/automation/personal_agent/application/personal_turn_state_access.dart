/// LOOP-3-STATE-V2 — acceso al estado personal compacto por conversación.
///
/// Lee/escribe [PersonalTurnState] como UNA fila `personalTurnState` de
/// PersonalMemory (datastore existente vía [PersonaRepository]): hereda
/// lifecycle, TTL y scopeKey por conversación. Nunca un store paralelo,
/// nunca transcripciones: una fila JSON compacta por conversación.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../domain/personal_conversation_state.dart';
import '../domain/personal_memory.dart';
// Extensions de memoria (listPersonalMemories/savePersonalMemory) viven en
// el library persona_repository.dart — el import completo las expone.
import 'persona_repository.dart';

final class PersonalTurnStateAccess {
  const PersonalTurnStateAccess();

  static const String _stateKey = 'turnState';
  static const String _kind = 'personalTurnState';

  /// Estado actual de la conversación o null si aún no existe.
  Future<PersonalTurnState?> load(String conversationId) async {
    if (conversationId.isEmpty) return null;
    final scope = personalizationScope(conversationId);
    try {
      final memory = await PersonaRepository.instance.loadPersonalTurnState(
        scope,
      );
      if (memory != null) {
        final decoded = jsonDecode(memory.value);
        if (decoded is Map) {
          return PersonalTurnState.fromJson(decoded.cast<String, dynamic>());
        }
      }
    } on Object catch (error) {
      // Estado corrupto o canal caído: null = sin estado (fail-closed, el
      // prompt compacto se degrada sin inventar contexto).
      debugPrint('[personal-state] load falló: ${error.runtimeType}');
    }
    return null;
  }

  /// Mergea y persiste el estado del turno (idempotente). Un campo vacío
  /// no borra el valor previo; los loops abiertos conservan su vida.
  ///
  /// LOOP-4 — lifecycle de loops al mergear:
  /// - un loop nuevo con el mismo id (misma descripción) SUPERSEDE al previo;
  /// - un loop OPEN vence por dueHint/sin-hint → EXPIRED;
  /// - RESOLVED requiere evidencia del router (LOOP 6); aquí nunca se
  ///   inventa una resolución.
  Future<void> merge(
    String conversationId, {
    String currentTopic = '',
    String latestIntent = '',
    String unresolvedReference = '',
    List<OpenLoopSummary> openLoops = const [],
    double confidence = 0.0,
  }) async {
    if (conversationId.isEmpty) return;
    final scope = personalizationScope(conversationId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final prev =
        await load(conversationId) ?? PersonalTurnState(stateUpdatedAt: now);
    final detectedIds = {for (final l in openLoops) l.id};
    final prevLoops = [
      for (final l in prev.openLoops)
        if (l.isOpen && detectedIds.contains(l.id))
          l.withStatus('SUPERSEDED', supersededBy: l.id)
        else if (l.isOpen && _expiredByDueHint(l, now))
          l.withStatus('EXPIRED')
        else
          l,
    ];
    final allLoops = [...prevLoops, ...openLoops];
    // Acota el historial durable para evitar crecimiento indefinido. Conserva
    // primero todos los pendientes y completa hasta 64 con los más recientes.
    final activeLoops = allLoops.where((loop) => loop.isOpen).toList();
    final inactiveLoops = allLoops.where((loop) => !loop.isOpen).toList();
    final boundedLoops = <OpenLoopSummary>[
      ...activeLoops.reversed.take(64).toList().reversed,
    ];
    if (boundedLoops.length < 64) {
      boundedLoops.insertAll(
        0,
        inactiveLoops.reversed.take(64 - boundedLoops.length).toList().reversed,
      );
    }
    final merged = prev.merge(
      currentTopic: currentTopic,
      latestIntent: latestIntent,
      unresolvedReference: unresolvedReference,
      openLoops: boundedLoops,
      stateUpdatedAt: now,
      // Confianza desconocida (0) NO degrada la medición previa.
      confidence: confidence > 0 ? confidence : null,
    );
    try {
      // Una sola fila por conversación: key fija + kind fijo. El valor es
      // el JSON compacto del estado (nunca el contenido de los mensajes).
      await PersonaRepository.instance.savePersonalTurnState(
        PersonalMemory(
          scopeKey: scope,
          key: _stateKey,
          value: jsonEncode(merged.toJson()),
          kind: _kind,
          observedAt: now,
        ),
      );
    } on Object catch (error) {
      // Best-effort: un fallo de escritura jamás altera el resultado real
      // del turno (mismo criterio que la sombra de ráfagas y el gate).
      debugPrint('[personal-state] save falló: ${error.runtimeType}');
    }
  }

  /// LOOP-4 — vencimiento conservador por dueHint (sin inventar fechas):
  /// "mañana" 24h, "hoy/esta noche" 12h, día de semana 7d, sin hint 7d.
  static bool _expiredByDueHint(OpenLoopSummary loop, int nowMs) {
    if (loop.createdAt <= 0) return false;
    final age = nowMs - loop.createdAt;
    if (age < 0) return false;
    final hint = loop.dueHint.toLowerCase();
    if (hint.contains('mañana') || hint.contains('manana')) {
      return age > 24 * 60 * 60 * 1000;
    }
    if (hint.contains('hoy') ||
        hint.contains('noche') ||
        hint.contains('tarde') ||
        hint.contains('ahora')) {
      return age > 12 * 60 * 60 * 1000;
    }
    return age > 7 * 24 * 60 * 60 * 1000;
  }
}

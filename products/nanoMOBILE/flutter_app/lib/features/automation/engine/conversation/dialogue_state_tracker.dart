// dialogue_state_tracker.dart
//
// QUÉ HACE:
// Mantiene el estado pragmático y contextual continuo por conversación activa
// (DialogueStateTracker), permitiendo coherencia semántica entre turnos consecutivos.
//
// CÓMO FUNCIONA:
// - Registra por cada conversación (`conversationId`):
//   * El último acto pragmático del usuario (`DialogueAct`)
//   * El último acto pragmático emitido por el agente
//   * El último enunciado emitido y si quedó una pregunta pendiente
// - Facilita resolver anáforas y reacciones dependientes ("me alegra", "eso no lo pregunté").
//
// POR QUÉ:
// Evita que cada turno se procese en el vacío. Permite reconocer de inmediato
// si "me alegra" es reacción a un "bien" previo, o si "no pregunté eso" requiere reparación.
// Sigue SOLID (SRP), inmutable por consulta, estrictamente < 200 líneas.

library;

import '../language/dialogue_act.dart';
import 'conversation_topic.dart';
import 'conversation_topic_tracker.dart';

/// Instantánea inmutable del estado pragmático y temático de una conversación.
final class ConversationDialogueState {
  final DialogueAct? lastUserAct;
  final DialogueAct? lastAgentAct;
  final String? lastAgentStatement;
  final ConversationTopic? activeTopic;
  final bool hasPendingQuestion;
  final int turnCount;
  final int lastUpdatedMs;

  const ConversationDialogueState({
    this.lastUserAct,
    this.lastAgentAct,
    this.lastAgentStatement,
    this.activeTopic,
    this.hasPendingQuestion = false,
    this.turnCount = 0,
    this.lastUpdatedMs = 0,
  });

  ConversationDialogueState copyWith({
    DialogueAct? lastUserAct,
    DialogueAct? lastAgentAct,
    String? lastAgentStatement,
    ConversationTopic? activeTopic,
    bool? hasPendingQuestion,
    int? turnCount,
    int? lastUpdatedMs,
  }) {
    return ConversationDialogueState(
      lastUserAct: lastUserAct ?? this.lastUserAct,
      lastAgentAct: lastAgentAct ?? this.lastAgentAct,
      lastAgentStatement: lastAgentStatement ?? this.lastAgentStatement,
      activeTopic: activeTopic ?? this.activeTopic,
      hasPendingQuestion: hasPendingQuestion ?? this.hasPendingQuestion,
      turnCount: turnCount ?? this.turnCount,
      lastUpdatedMs: lastUpdatedMs ?? this.lastUpdatedMs,
    );
  }
}

/// Administrador en memoria de estados de diálogo y temas por conversación.
final class DialogueStateTracker {
  final Map<String, ConversationDialogueState> _states = {};
  final ConversationTopicTracker topicTracker = ConversationTopicTracker();

  /// Consulta el estado actual de la conversación o un estado inicial vacío.
  ConversationDialogueState getState(String conversationId) {
    final state = _states[conversationId];
    if (state == null) return const ConversationDialogueState();
    final freshTopic = topicTracker.getActiveTopic(conversationId);
    return state.copyWith(activeTopic: freshTopic);
  }

  /// Registra el turno entrante del usuario, su acto clasificado y actualiza el tema.
  void recordUserTurn(String conversationId, DialogueAct act, {String userText = ''}) {
    if (_states.length > 50) {
      purgeStale();
    }
    final current = getState(conversationId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final topic = userText.trim().isNotEmpty
        ? topicTracker.recordUserTurn(
            conversationId: conversationId,
            userText: userText,
            currentTurn: current.turnCount + 1,
          )
        : current.activeTopic;

    _states[conversationId] = current.copyWith(
      lastUserAct: act,
      activeTopic: topic,
      turnCount: current.turnCount + 1,
      lastUpdatedMs: now,
    );
  }

  /// Registra el turno saliente del agente con su respuesta y si formuló pregunta.
  void recordAgentTurn({
    required String conversationId,
    required DialogueAct act,
    required String statement,
    bool isQuestion = false,
  }) {
    final current = getState(conversationId);
    final now = DateTime.now().millisecondsSinceEpoch;
    _states[conversationId] = current.copyWith(
      lastAgentAct: act,
      lastAgentStatement: statement,
      hasPendingQuestion: isQuestion,
      lastUpdatedMs: now,
    );
  }

  /// Limpia estados y temas expirados tras inactividad.
  void purgeStale({Duration maxAge = const Duration(hours: 2)}) {
    final threshold = DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    _states.removeWhere((_, state) => state.lastUpdatedMs < threshold);
    topicTracker.purgeStale();
  }

  /// Reinicia el estado y tema de una conversación específica.
  void reset(String conversationId) {
    _states.remove(conversationId);
    topicTracker.reset(conversationId);
  }
}

// conversation_topic_tracker.dart
//
// QUÉ HACE:
// Gestor en memoria del hilo temático y memoria de trabajo (`ConversationTopicTracker`)
// para mantener la continuidad contextual en conversaciones cotidianas.
//
// CÓMO FUNCIONA:
// - Registra y actualiza el tema activo por cada `conversationId`.
// - Provee réplicas empáticas y continuaciones naturales basadas en el dominio detectado
//   (salud, trabajo, planes, trámites, etc.) evitando respuestas desconectadas del contexto.
//
// POR QUÉ:
// Resuelve el problema donde el usuario relata un evento personal ("me caí de la moto")
// y en el siguiente turno Nano responde como si fuera un saludo nuevo o consulta aislada.
// Sigue SOLID (SRP), inmutable por consulta y estrictamente < 200 líneas.

library;

import 'conversation_topic.dart';
import 'conversation_topic_extractor.dart';

final class ConversationTopicTracker {
  ConversationTopicTracker({
    ConversationTopicExtractor extractor = const ConversationTopicExtractor(),
  }) : _extractor = extractor;

  final ConversationTopicExtractor _extractor;
  final Map<String, ConversationTopic> _topics = {};

  /// Consulta el tema activo de la conversación si sigue vigente.
  ConversationTopic? getActiveTopic(String conversationId) {
    final topic = _topics[conversationId];
    if (topic != null && topic.isFresh()) return topic;
    _topics.remove(conversationId);
    return null;
  }

  /// Actualiza el hilo temático a partir del turno entrante del usuario.
  ConversationTopic? recordUserTurn({
    required String conversationId,
    required String userText,
    int currentTurn = 0,
  }) {
    if (_topics.length > 50) {
      purgeStale();
    }
    final active = getActiveTopic(conversationId);
    final updated = _extractor.extractTopic(
      text: userText,
      activeTopic: active,
      currentTurn: currentTurn,
    );
    if (updated != null) {
      _topics[conversationId] = updated;
    }
    return updated;
  }

  /// Genera alternativas empáticas de seguimiento cotidiano ancladas al tema activo.
  List<String> getContextualFollowups(
    String conversationId, {
    required String userText,
  }) {
    final topic = getActiveTopic(conversationId);
    if (topic == null) return const [];

    return switch (topic.domain) {
      TopicDomain.healthWellbeing => const [
          'Uf parce, menos mal no pasó a mayores. Descansa y cuídate mucho.',
          'Qué alivio saber que estás bien. Tómate el tiempo de recuperarte.',
          'Menos mal te revisaron. Cualquier cosa que necesites me avisas.',
        ],
      TopicDomain.workProjects => const [
          'Ánimo con ese camello parce, que rinda bastante la jornada.',
          'Uf, pesado ese trote. Tómese un café y va saliendo con calma.',
          'Hágale con calma que todo va saliendo. Por acá pendiente si algo.',
        ],
      TopicDomain.plansOuting => const [
          '¡Qué buen plan parce! Que la pasen excelente por allá.',
          'De una, disfruten bastante el rato. Luego me cuentas qué tal.',
          'Hágale, que todo salga bien y descansen bastante.',
        ],
      TopicDomain.logisticsErrands => const [
          'Ojalá salga rápido esa vuelta y no te demoren mucho.',
          'Paciencia con esos trámites parce, que todo quede resuelto hoy.',
          'Hágale de una, que rinda el día con esas vueltas.',
        ],
      TopicDomain.socialPersonal => const [
          '¡Total parce! Qué buena anécdota, menos mal todo marchó bien.',
          'Imagínate eso, qué cosas pasan. Menos mal me contaste.',
          'De una parce, gracias por compartirme el cuento.',
        ],
      _ => const [],
    };
  }

  /// Limpia temas inactivos después de 45 minutos.
  void purgeStale({Duration maxAge = const Duration(minutes: 45)}) {
    _topics.removeWhere((_, topic) => !topic.isFresh(maxAge: maxAge));
  }

  /// Reinicia el tema activo de una conversación al cerrar el ciclo.
  void reset(String conversationId) {
    _topics.remove(conversationId);
  }
}

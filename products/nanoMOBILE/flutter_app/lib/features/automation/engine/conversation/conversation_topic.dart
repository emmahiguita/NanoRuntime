// conversation_topic.dart
//
// QUÉ HACE:
// Define el modelo inmutable de estado temático e hilo de conversación
// (`ConversationTopic`) para el seguimiento continuo de diálogos cotidianos.
//
// CÓMO FUNCIONA:
// - Clasifica el dominio conversacional (`TopicDomain`) entre áreas cotidianas
//   (salud/bienestar, trabajo/proyectos, planes/salidas, logística/trámites, etc.).
// - Mantiene las entidades clave activas en la memoria de trabajo (Working Memory),
//   la cantidad de turnos transcurridos en el mismo tema y su vigencia temporal.
//
// POR QUÉ:
// Resuelve la desconexión contextual entre turnos consecutivos (AUT-P2-TOPIC).
// Permite que Nano recuerde que el usuario habló de un accidente o un proyecto
// aunque el mensaje actual solo diga "sí, ya salí del médico".
// Sigue SOLID (SRP), inmutable y estrictamente < 200 líneas.

library;

/// Dominios temáticos cotidianos de conversación.
enum TopicDomain {
  healthWellbeing,
  workProjects,
  plansOuting,
  logisticsErrands,
  socialPersonal,
  casualGreeting,
  general,
}

/// Instantánea inmutable del hilo temático activo en una conversación.
final class ConversationTopic {
  final TopicDomain domain;
  final String label;
  final Set<String> keyEntities;
  final int startTurn;
  final int turnCount;
  final int lastUpdatedMs;

  const ConversationTopic({
    required this.domain,
    required this.label,
    this.keyEntities = const {},
    this.startTurn = 0,
    this.turnCount = 1,
    required this.lastUpdatedMs,
  });

  /// Crea un nuevo tema a partir de una detección inicial.
  factory ConversationTopic.initial({
    required TopicDomain domain,
    required String label,
    Set<String> keyEntities = const {},
    int currentTurn = 0,
  }) {
    return ConversationTopic(
      domain: domain,
      label: label,
      keyEntities: Set.unmodifiable(keyEntities),
      startTurn: currentTurn,
      turnCount: 1,
      lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Evalúa si el tema sigue vigente (máximo 45 minutos de inactividad).
  bool isFresh({Duration maxAge = const Duration(minutes: 45)}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastUpdatedMs) <= maxAge.inMilliseconds;
  }

  /// Produce un nuevo estado incorporando nuevas entidades del turno actual.
  ConversationTopic evolve({
    Set<String> newEntities = const {},
    int? currentTurn,
  }) {
    final updatedEntities = Set<String>.from(keyEntities)..addAll(newEntities);
    return ConversationTopic(
      domain: domain,
      label: label,
      keyEntities: Set.unmodifiable(updatedEntities),
      startTurn: startTurn,
      turnCount: turnCount + 1,
      lastUpdatedMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Comprueba si el texto entrante hace referencia a alguna de las entidades activas.
  bool containsEntityReference(String text) {
    final lower = text.toLowerCase();
    return keyEntities.any((entity) => lower.contains(entity.toLowerCase()));
  }

  @override
  String toString() =>
      'ConversationTopic(domain: $domain, label: "$label", entities: $keyEntities, turns: $turnCount)';
}

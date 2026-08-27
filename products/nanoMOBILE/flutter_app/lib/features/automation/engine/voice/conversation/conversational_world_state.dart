/// A16 — ConversationalWorldState: estado conversacional grounded de corta vida.
///
/// Referentes resueltos con EVIDENCIA (notificación/pantalla/memoria), no con
/// suposiciones. TTL acotado: no es vigilancia permanente. El LLM no adivina:
/// recibe la entidad resuelta desde aquí.
library;

import 'dart:async';

/// Origen verificado de una referencia resuelta.
enum ReferenceSource {
  notification,
  screenGraph,
  objectMemory,
  conversation,
  explicit,
}

/// Referencia resuelta: entidad + evidencia + confianza.
class ResolvedReference {
  final String entity;
  final ReferenceSource source;
  final double confidence;
  final DateTime timestamp;
  final String evidence;

  const ResolvedReference({
    required this.entity,
    required this.source,
    required this.confidence,
    required this.evidence,
    required this.timestamp,
  });
}

/// Estado del mundo conversacional. Guarda las entidades activas y los
/// referentes recientes con su evidencia. Se limpia por TTL.
class ConversationalWorldState {
  String? activeApp;
  String? activeConversation;
  String? activePerson;
  String? lastAction;
  String? lastUserIntent;

  /// Referentes recientes: "juan" → ResolvedReference (por label).
  final Map<String, ResolvedReference> referents = {};

  DateTime? _touchedAt;

  static const _ttl = Duration(minutes: 10);

  void touch() => _touchedAt = DateTime.now();

  bool get isStale =>
      _touchedAt == null || DateTime.now().difference(_touchedAt!) > _ttl;

  /// Fija la entidad activa (app/persona/conversación) tras una acción grounded.
  void setActive({String? app, String? conversation, String? person}) {
    if (app != null) activeApp = app;
    if (conversation != null) activeConversation = conversation;
    if (person != null) activePerson = person;
    touch();
  }

  /// Recuerda un referente por label, con su evidencia.
  void remember(String label, ResolvedReference ref) {
    referents[label.toLowerCase().trim()] = ref;
    touch();
  }

  /// Resuelve un label (nombre de persona/contacto) a la entidad grounded.
  ResolvedReference? resolve(String label) {
    final l = label.toLowerCase().trim();
    if (l.isEmpty) return null;
    return referents[l];
  }

  void clear() {
    activeApp = null;
    activeConversation = null;
    activePerson = null;
    lastAction = null;
    lastUserIntent = null;
    referents.clear();
    _touchedAt = null;
  }
}

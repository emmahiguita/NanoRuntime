// conversation_memory_models.dart
//
// QUÉ HACE:
// Define los modelos inmutables de datos para el historial y contexto de conversaciones:
// `ConversationMemoryEntryKind`, `ConversationMemoryEntry` y `ConversationMemory`.
//
// CÓMO FUNCIONA:
// - Representa estados fácticos observables: inbound, outboundVerified, outboundDispatched,
//   outboundObservedManual y effectUnknown.
// - Serializa y deserializa de forma segura JSON hacia/desde SQLite o SharedPreferences.
//
// POR QUÉ:
// Separa los DTOs de la lógica de persistencia y almacenamiento (Clean Architecture - SRP),
// garantizando tipado estricto e inmutabilidad con archivos menores a 200 líneas.

library;

import 'conversation_agent.dart';

/// Tipo factual de una entrada de memoria conversacional.
enum ConversationMemoryEntryKind {
  /// Mensaje entrante observado. Nunca éxito, nunca instrucción.
  inbound,

  /// Envío VERIFICADO contra el estado real (la memoria puede decir "Nano envió X").
  outboundVerified,

  /// Envío despachado (RemoteInput aceptado) sin verificación final.
  outboundDispatched,

  /// Mensaje saliente del dueño observado en la notificación sin despacho previo de Nano.
  outboundObservedManual,

  /// Efecto incierto: el envío pudo aterrizar o no. Nunca éxito.
  effectUnknown,
}

/// Entrada inmutable del historial de una conversación.
final class ConversationMemoryEntry {
  final ConversationMemoryEntryKind kind;
  final String text;
  final String sender;
  final int atMs;
  final String eventId;
  final String ruleId;

  const ConversationMemoryEntry({
    required this.kind,
    required this.text,
    this.sender = '',
    required this.atMs,
    this.eventId = '',
    this.ruleId = '',
  });

  Map<String, Object?> toJson() => {
    'k': kind.name,
    't': text,
    if (sender.isNotEmpty) 's': sender,
    'a': atMs,
    if (eventId.isNotEmpty) 'e': eventId,
    if (ruleId.isNotEmpty) 'r': ruleId,
  };

  factory ConversationMemoryEntry.fromJson(Map<String, dynamic> m) =>
      ConversationMemoryEntry(
        kind: ConversationMemoryEntryKind.values.byName(m['k'] as String),
        text: (m['t'] as String?) ?? '',
        sender: (m['s'] as String?) ?? '',
        atMs: (m['a'] as num?)?.toInt() ?? 0,
        eventId: (m['e'] as String?) ?? '',
        ruleId: (m['r'] as String?) ?? '',
      );
}

/// Vista inmutable del historial de UNA conversación lógica en orden cronológico.
final class ConversationMemory {
  final String conversationId;
  final String scopeId;
  final ConversationAgentId? agentId;
  final List<ConversationMemoryEntry> entries;
  final int lastAtMs;
  final List<String> unresolvedObligations;
  final String? activeTopic;
  final int? lastManualInterventionMs;

  const ConversationMemory({
    required this.conversationId,
    this.scopeId = '',
    this.agentId,
    required this.entries,
    required this.lastAtMs,
    this.unresolvedObligations = const [],
    this.activeTopic,
    this.lastManualInterventionMs,
  });

  bool get isEmpty => entries.isEmpty;

  ConversationMemoryEntry? get last => entries.isEmpty ? null : entries.last;

  factory ConversationMemory.fromJson(Map<String, dynamic> m) =>
      ConversationMemory(
        conversationId: (m['id'] as String?) ?? '',
        scopeId: (m['scopeId'] as String?) ?? '',
        agentId: m['agentId'] is String
            ? ConversationAgentId.fromName(m['agentId'] as String)
            : null,
        entries: [
          for (final e in (m['entries'] as List?) ?? const [])
            ConversationMemoryEntry.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
        ],
        lastAtMs: (m['lastAtMs'] as num?)?.toInt() ?? 0,
        unresolvedObligations: [
          for (final o in (m['obligations'] as List?) ?? const []) o.toString(),
        ],
        activeTopic: m['topic'] as String?,
        lastManualInterventionMs: (m['manualAt'] as num?)?.toInt(),
      );

  Map<String, Object?> toJson() => {
    'id': conversationId,
    if (scopeId.isNotEmpty) 'scopeId': scopeId,
    if (agentId != null) 'agentId': agentId!.name,
    'entries': [for (final e in entries) e.toJson()],
    'lastAtMs': lastAtMs,
    if (unresolvedObligations.isNotEmpty) 'obligations': unresolvedObligations,
    if (activeTopic != null && activeTopic!.isNotEmpty) 'topic': activeTopic,
    if (lastManualInterventionMs != null) 'manualAt': lastManualInterventionMs,
  };
}

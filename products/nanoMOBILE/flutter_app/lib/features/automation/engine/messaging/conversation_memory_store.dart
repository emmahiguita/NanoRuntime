// conversation_memory_store.dart
//
// QUÉ HACE:
// Contrato de interfaz formal para el repositorio de memoria de conversaciones:
// `ConversationMemoryStore`.
//
// CÓMO FUNCIONA:
// - Define métodos para hidratar (`load`), consultar (`memoryFor`, `knownConversationIds`),
//   y registrar mensajes entrantes (`appendInbound`), salientes (`appendOutbound`),
//   obligaciones y reconciliaciones.
//
// POR QUÉ:
// Aplica el principio de Inversión de Dependencias (SOLID - DIP), permitiendo desacoplar
// el consumo del almacén de la tecnología de persistencia subyacente (SQLite/Memoria/SharedPreferences).

library;

import 'conversation_agent.dart';
import 'conversation_memory_models.dart';
import 'incoming_message.dart';

/// Almacén de memoria por conversación lógica.
abstract interface class ConversationMemoryStore {
  /// Hidrata el estado persistido (al arrancar el provider).
  Future<void> load();

  /// Snapshot de la conversación; null si nunca se observó nada.
  ConversationMemory? memoryFor(String conversationId);

  /// Ids de conversaciones con historial retenido.
  Set<String> knownConversationIds({ConversationAgentId? agentId});

  /// Registra la observación de un mensaje entrante.
  void appendInbound(IncomingMessage message, {required int atMs});

  /// Registra un intento de envío con su honestidad real.
  void appendOutbound(
    String conversationId,
    String text, {
    required ConversationMemoryEntryKind kind,
    String? ruleId,
    required int atMs,
  });

  /// Registra una obligación o petición pendiente aún no resuelta.
  void addUnresolvedObligation(String conversationId, String obligation);

  /// Resuelve obligaciones atendidas.
  void resolveObligations(String conversationId, List<String> resolved);

  /// Limpia todas las obligaciones pendientes de la conversación.
  void clearObligations(String conversationId);

  /// Registra una intervención manual del dueño en WhatsApp.
  void recordManualIntervention(String conversationId, int atMs);

  /// Reconcilia un mensaje saliente observado en notificaciones.
  void reconcileOutbound(
    String conversationId,
    String text, {
    required int atMs,
  });
}

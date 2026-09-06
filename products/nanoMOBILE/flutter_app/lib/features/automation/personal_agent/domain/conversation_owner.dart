/// PERSONA-HANDOFF-03 — ownership de conversación (patrón Chatwoot).
///
/// Cada conversación tiene UN dueño. Por defecto el bot es dueño (el runtime
/// responde solo, paridad con el comportamiento actual). Cuando el humano
/// toma el control explícitamente, el bot puede preparar drafts pero JAMÁS
/// envía: el DecisionEngine retiene (holdForApproval) mientras `human`
/// sea el dueño. Soltar la conversación la devuelve al bot.
///
/// La persistencia llega en PERSONA-STORAGE-04 (sección
/// `conversation_ownership`); mientras tanto el store vive en memoria del
/// proceso.
library;

/// Quién maneja la conversación ahora.
enum ConversationOwner { bot, human }

/// Estado de ownership de una conversación.
final class ConversationOwnership {
  final String conversationId;

  /// Dueño actual. null = nunca se declaró control humano → bot.
  final ConversationOwner owner;

  /// Marca de cuándo cambió por última vez (ms epoch, 0 = nunca).
  final int updatedAtMs;

  const ConversationOwnership({
    required this.conversationId,
    required this.owner,
    required this.updatedAtMs,
  });

  bool get humanOwns => owner == ConversationOwner.human;
}

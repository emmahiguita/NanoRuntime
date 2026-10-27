/// PERSONA-HANDOFF-03 — ownership de conversación (patrón Chatwoot).
///
/// Cada conversación tiene UN dueño. Por defecto el bot es dueño (el runtime
/// responde solo, paridad con el comportamiento actual). Cuando el humano
/// toma el control explícitamente, la automatización se pausa y JAMÁS
/// envía: el DecisionEngine retiene (holdForApproval) mientras `human`
/// sea el dueño. Soltar la conversación la devuelve al bot.
///
/// Se persiste en SQLite (sección `ownership`), compartida por UI y headless.
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

  /// La pausa no caduca: solo una activación explícita devuelve el chat al bot.
  /// Mantiene el argumento anterior para no romper los consumidores existentes.
  bool isHumanActive([int? nowMs]) => owner == ConversationOwner.human;

  bool get humanOwns => isHumanActive();
}

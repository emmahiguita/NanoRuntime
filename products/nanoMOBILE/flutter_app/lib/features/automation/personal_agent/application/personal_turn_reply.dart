// personal_turn_reply.dart
//
// QUÉ HACE:
// Encapsula la respuesta del Agente Personal junto con sus opciones seleccionables y análisis contextual.
//
// CÓMO FUNCIONA:
// Estructura inmutable que transporta el texto principal, el objeto `ConversationUnderstanding`,
// la lista de alternativas `suggestions` y la bandera `isFast`.
//
// POR QUÉ:
// Desacopla la entidad de respuesta del orquestador conversacional, garantizando SRP (SOLID)
// y manteniendo `personal_conversation_resolver.dart` bajo el límite estricto de 200 líneas.

library;

import '../../engine/notifications/conversation_understanding.dart';

final class PersonalTurnReply {
  final String text;
  final ConversationUnderstanding understanding;
  final List<String> suggestions;
  final bool isFast;

  const PersonalTurnReply({
    required this.text,
    required this.understanding,
    this.suggestions = const [],
    this.isFast = true,
  });
}

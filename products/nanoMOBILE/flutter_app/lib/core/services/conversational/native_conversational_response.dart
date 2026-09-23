// native_conversational_response.dart — DTO de respuesta conversacional nativa sin LLM.
// QUÉ HACE: Encapsula el texto de respuesta, opciones interactivas sugeridas y origen del mensaje.
// CÓMO FUNCIONA: Objeto inmutable pasado desde el router conversacional a la capa de presentación.
// POR QUÉ: Permite comunicación reactiva rápida con opciones seleccionables cumpliendo SRP.
library;

import '../../models/chat_models.dart';

class NativeConversationalResponse {
  final String text;
  final List<String> suggestions;
  final MessageSource source;

  const NativeConversationalResponse({
    required this.text,
    required this.suggestions,
    this.source = MessageSource.device,
  });
}

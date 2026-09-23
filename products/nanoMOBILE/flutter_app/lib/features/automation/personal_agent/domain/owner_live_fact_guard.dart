/// Contrato factual para preguntas sobre el estado real del dueño.
///
/// QUÉ HACE: identifica turnos que no pueden responderse solo con estilo.
/// CÓMO: combina el intent tipado del fast path con señales conservadoras del texto.
/// POR QUÉ: una frase natural no convierte comida, ubicación o planes en hechos.
library;

import '../../engine/business/fact_selector.dart' show normalizeText;
import 'conversation_agent_role.dart' show isLiveStateQuestion;

/// Intenciones cuyo contenido requiere una fuente viva o aprobación del dueño.
const Set<String> ownerLiveFactIntentNames = {
  'askActivity',
  'askDay',
  'askTraining',
  'askRap',
  'invitation',
  'askPresence',
  'planReminder',
  'askAvailability',
  'askFood',
  'askPhysicalLocation',
  'askFamily',
  'askSleep',
  'askMusic',
  'askWeatherSocial',
  'askCall',
  'askLostOrMissing',
  'askOpinionSocial',
};

/// Valida intents sin acoplar la política al enum del motor lingüístico.
bool intentNeedsOwnerLiveFact(Iterable<String> intentNames) =>
    intentNames.any(ownerLiveFactIntentNames.contains);

/// Devuelve true cuando responder supondría afirmar un hecho personal no observado.
bool requiresOwnerLiveFact({
  required String messageText,
  String detectedIntent = '',
}) {
  final intents = detectedIntent
      .split('+')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty);
  if (intentNeedsOwnerLiveFact(intents) || isLiveStateQuestion(messageText)) {
    return true;
  }

  final text = normalizeText(messageText);
  if (text.isEmpty) return false;
  return _ownerFactSignals.any(text.contains);
}

/// Señales solo para cubrir entradas que no llegaron con intent estructurado.
const List<String> _ownerFactSignals = [
  'estas ocupado',
  'andas ocupado',
  'tienes tiempo',
  'puedes hablar',
  'estas libre',
  'ya comiste',
  'ya almorzaste',
  'ya cenaste',
  'ya desayunaste',
  'que comiste',
  'vas a comer',
  'donde estas',
  'por donde andas',
  'estas en la casa',
  'como esta tu familia',
  'como esta la familia',
  'como estan en la casa',
  'vas a dormir',
  'te vas a acostar',
  'sigues despierto',
  'que musica escuchas',
  'que estas escuchando',
  'como esta el clima por alla',
  'esta lloviendo por alla',
  'te puedo llamar',
  'puedo llamarte',
  'por que tan perdido',
  'que opinas',
  'que piensas',
];

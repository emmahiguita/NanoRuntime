// QUÉ: conserva la clasificación existente de saludos, sin variar sus filtros.
// CÓMO: comparte imports y vocabulario de la biblioteca original.
// POR QUÉ: aísla esta responsabilidad y mantiene archivos menores de 200 líneas.
part of 'conversation_agent_message_classifier.dart';

/// Identifica saludos sociales puros o con cortesía/vocativo/bienestar.
bool isGreetingLikeMessage(String messageText) {
  if (isLiveStateQuestion(messageText)) return false;
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty) return false;
  if (tokens.any(commercialIntentTokens.contains)) return false;
  if (supportPhrases.any(normalized.contains)) return false;
  if (correctionPhrases.any(normalized.contains)) return false;
  if (normalized.contains('vas a') || normalized.contains('iras a')) {
    return false;
  }

  const compoundTokens = {
    'haces',
    'haciendo',
    'haras',
    'hacer',
    'salir',
    'saldras',
    'iras',
    'tienes',
    'tenes',
    'todavia',
    'aun',
    'telefono',
    'celular',
    'hablaste',
    'dijiste',
    'viste',
    'fuiste',
    'pudiste',
    'sabes',
    'puedes',
    'quieres',
    'necesitas',
    'vendes',
    'compras',
    'llevas',
    'partido',
    'futbol',
    'programando',
    'programa',
    'programar',
    'codigo',
    'app',
    'aplicacion',
    'agente',
    'agentes',
    'trabajando',
    'trabajo',
    'camellando',
    'cansado',
    'cansada',
    'cansao',
    'cansaod',
    'agotado',
    'muerto',
    'gimnasio',
    'gym',
    'entrenando',
    'entreno',
    'pecho',
    'espalda',
    'pierna',
    'casa',
    'calle',
    'estoy',
    'ando',
    'sali',
    'fui',
    'tarea',
    'ayuda',
    'duda',
    'pregunta',
  };
  if (tokens.any(compoundTokens.contains)) return false;
  if (isPureGreeting(messageText)) return true;

  const explicitGreetingWords = {
    'hola',
    'holas',
    'buenas',
    'buenos',
    'hey',
    'oe',
    'saludos',
    'ola',
  };
  final hasGreeting =
      tokens.take(3).any(explicitGreetingWords.contains) ||
      (tokens.first != 'que' && greetingTokens.contains(tokens.first)) ||
      (tokens.first == 'que' && tokens.length >= 2 && tokens.contains('tal')) ||
      normalized.contains('como vas') ||
      normalized.contains('que tal') ||
      normalized.contains('todo bien');
  if (!hasGreeting) return false;

  final complexity = turnComplexityClassifier.classify(messageText);
  if (complexity.isNarrative ||
      complexity.isComplex ||
      complexity.isContextual) {
    return false;
  }
  return tokens.length <= 8;
}

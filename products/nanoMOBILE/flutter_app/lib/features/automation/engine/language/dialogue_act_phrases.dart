// dialogue_act_phrases.dart
//
// QUÉ HACE:
// Define los bancos léxicos deterministas de frases y marcadores conversacionales
// organizados por actos de diálogo (pragmática conversacional hispanohablante).
//
// CÓMO FUNCIONA:
// Provee listas inmutables normalizadas (sin tildes) consumidas por
// DialogueActClassifier para matching léxico directo en O(N) acotado (< 1ms).
//
// POR QUÉ:
// Mantiene DialogueActClassifier modular y estrictamente por debajo de 200 líneas (SOLID-SRP).
// Previene búsquedas externas para actos sociales, reparaciones o afirmaciones cotidianas.

library;

/// Frases que denotan reacción afectiva positiva ("me alegra", "qué bueno").
const kPositiveReactionPhrases = [
  'me alegra',
  'me alegro',
  'que bueno',
  'que bien',
  'super',
  'genial',
  'excelente',
  'que chimba',
  'que bacano',
  'maravilloso',
  'perfecto saberlo',
  'me alegra saberlo',
  'que bueno saberlo',
  'me alegro mucho',
  'me alegra mucho',
];

/// Frases que denotan reacción afectiva negativa o condolencia.
const kNegativeReactionPhrases = [
  'que mal',
  'que lastima',
  'que pesar',
  'grave',
  'que pena',
  'que embarrada',
];

/// Expresiones de gratitud social.
const kGratitudePhrases = [
  'gracias',
  'muchas gracias',
  'mil gracias',
  'te agradezco',
  'muy amable',
];

/// Fórmulas de despedida o cierre de conversación.
const kFarewellPhrases = [
  'chao',
  'adios',
  'hasta luego',
  'nos vemos',
  'hablamos',
  'descansa',
  'feliz noche',
  'buenas noches',
  'hasta manana',
  'que estes bien',
];

/// Saludos cordiales hispanohablantes.
const kGreetingPhrases = [
  'hola',
  'buenas',
  'buen dia',
  'buenos dias',
  'buenas tardes',
  'buenas noches',
  'que mas',
  'q mas',
  'quiubo',
  'hey',
  'oe',
  'saludos',
];

/// Fórmulas de reparación o solicitud de aclaración ante mensaje inesperado.
const kRepairPhrases = [
  '?',
  '¿?',
  '??',
  'como?',
  'que?',
  'no entendi',
  'como asi',
  'a que te refieres',
  'eso que tiene que ver',
  'de que hablas',
  'a que viene eso',
];

/// Correcciones explícitas de contexto hechas por el usuario.
const kCorrectionPhrases = [
  'eso no lo pregunte yo',
  'yo no pregunte eso',
  'eso no lo pregunte',
  'no pregunte eso',
  'no me refiero',
  'no me referia',
  'no era eso',
  'eso no fue lo que pregunte',
  'no, me referia',
  'al reves',
  'te equivocaste',
];

/// Aclaraciones reiterativas de información ya suministrada.
const kClarificationPhrases = [
  'ya te dije',
  'te acabo de decir',
  'te habia dicho',
  'te dije que',
];

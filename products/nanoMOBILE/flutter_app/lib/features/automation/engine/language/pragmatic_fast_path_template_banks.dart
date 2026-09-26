part of 'pragmatic_fast_path.dart';

/// Bancos inmutables de candidatos para cortesía, bienestar y despedidas.
///
/// **QUÉ HACE:**
/// Agrupa más de 10 respuestas alternativas por intención social: saludos,
/// bienestar personal, agradecimientos, despedidas y risas.
///
/// **CÓMO FUNCIONA:**
/// Provee listas constantes evaluadas en _PragmaticFastPathTemplates.
///
/// **POR QUÉ:**
/// Enriquece la conversación sin inflar la lógica ni rebasar 200 líneas por archivo.
const List<String> wellbeingRecentlyGreetedCandidates = [
  'Bien, gracias a Dios.',
  'Todo bien por acá, tranquilo.',
  'Bien por acá, todo en orden.',
  'Bien por ahora.',
  'Todo marchando bien por acá.',
  'Tranquilo por acá, todo bien.',
  'Bien gracias a Dios, aquí en casa.',
  'Todo bien y en orden por este lado.',
  'Bien, gracias por preguntar.',
  'Por acá todo bien y tranquilo.',
  'Bien, marchando todo bien.',
];

const List<String> wellbeingStandardCandidates = [
  'Bien, gracias a Dios, ¿y tú?',
  'Estoy bien, ¿y tú?',
  'Bien, gracias a Dios.',
  'Todo bien, gracias a Dios.',
  'Bien por ahora, ¿y tú?',
  'Todo bien por acá, ¿qué tal tú?',
  'Bien gracias a Dios, ¿cómo vas?',
  'Todo bien y en orden por acá, ¿y tú?',
  'Bien por acá, ¿todo bien contigo?',
  'Bien y tranquilo por acá, ¿tú qué tal?',
  'Bien, todo marchando bien, ¿y vos?',
];

const List<String> greetingRecentlyGreetedCandidates = [
  'Dime.',
  '¿Qué más? Cuéntame.',
  'Por acá sigo, cuéntame.',
  'Hola otra vez, cuéntame.',
  '¿Qué pasó? Dime.',
  '¿Qué cuentas?',
  'Dime, ¿qué hubo?',
  'Dime, te leo.',
  'Aquí estoy, dime.',
  'Cuéntame, te leo.',
];

const List<String> greetingStandardCandidates = [
  'Hola.',
  'Hola, ¿cómo estás?',
  'Buenas.',
  'Ey, ¿todo bien?',
  '¿Cómo vas?',
  'Hola, ¿qué haces?',
  '¡Hola! ¿Qué más?',
  'Buenas, ¿cómo te va?',
  'Hola, ¿todo bien por allá?',
  'Buenas, ¿qué tal?',
  '¡Hola! ¿Cómo andas?',
];

const List<String> thanksCandidates = [
  'Con gusto.',
  'Todo bien.',
  'De nada.',
  'Tranquilo.',
  'Dale, todo bien.',
  'Con todo gusto.',
  'No te preocupes.',
  'Para eso estamos.',
  'Dale, de una.',
  'Todo bien, con gusto.',
  'A la orden.',
];

const List<String> farewellNightCandidates = [
  'Dale, que descanses.',
  'Descansa pues, hablamos.',
  'Dale, feliz noche.',
  'Que descanses.',
  'Feliz noche, que descanses.',
  'Listo, descansa pues.',
  'Dale, nos hablamos mañana.',
  'Que duermas bien, hablamos.',
  'Feliz noche, cuídate.',
  'Listo, que descanses bastante.',
  'Descansa, nos vemos mañana.',
];

const List<String> farewellTomorrowCandidates = [
  'Dale, hablamos mañana.',
  'Listo, hablamos mañana.',
  'Hablamos mañana, cuídate.',
  'Listo, hasta mañana.',
  'Dale, hasta mañana entonces.',
  'Mañana nos hablamos, cuídate.',
  'Listo, mañana seguimos hablando.',
  'Dale, que pases buena noche, hasta mañana.',
  'Listo pues, hablamos mañana.',
  'Dale, mañana me escribes.',
  'Hablamos mañana sin falta.',
];

const List<String> farewellAfternoonCandidates = [
  'Dale, feliz tarde.',
  'Bueno, que tengas buena tarde.',
  'Hablamos pues, cuídate.',
  'Feliz tarde, cuídate bastante.',
  'Listo, que te rinda la tarde.',
  'Dale, nos hablamos más tarde.',
  'Bueno, buena tarde.',
  'Hablamos más tarde, cuídate.',
  'Que tengas una buena tarde.',
  'Dale, cualquier cosa me escribes, buena tarde.',
  'Listo, nos vemos más tarde.',
];

const List<String> farewellGeneralCandidates = [
  'Bueno, hablamos.',
  'Hablamos luego.',
  'Dale, cuídate.',
  'Bueno, nos hablamos.',
  'Listo, hablamos después.',
  'Dale, estamos en contacto.',
  'Nos vemos luego, cuídate.',
  'Listo, hablamos más tarde.',
  'Dale, que estés bien.',
  'Cualquier cosa me escribes, hablamos.',
  'Listo pues, nos hablamos.',
];

const List<String> laughterCandidates = [
  '😂',
  'Literal jaja',
  'Jaja tal cual',
  'Jajaja sí',
  'Jajaja total',
  'Jaja sí, tal cual',
  'Jajaja literal',
  'Jaja sí 😂',
  'Jajaja qué risa',
  'Tal cual jaja',
  'Jajaja así es',
];

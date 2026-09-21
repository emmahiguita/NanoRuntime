part of 'pragmatic_fast_path.dart';

/// Bancos inmutables de candidatos para consultas misceláneas de tiempo y asistencia.
///
/// **QUÉ HACE:**
/// Provee más de 10 opciones para recordatorios de planes, presencia,
/// ubicación y solicitudes de ayuda o tareas.
///
/// **CÓMO FUNCIONA:**
/// Define listas constantes que _PragmaticFastPathComposerMisc consulta de forma directa.
///
/// **POR QUÉ:**
/// Enriquece las respuestas prácticas sin saturar la lógica procedimental de fechas y horas.
const List<String> planReminderCandidates = [
  'Sí, déjame revisar bien y más tarde te confirmo.',
  'Sí claro, dame un rato y te aviso seguro.',
  'Sí, déjame ver cómo me desocupo y te digo.',
  'Listo, dame un rato y te confirmo bien eso.',
  'Sí, más tarde reviso y te aviso sin falta.',
  'Dale, déjame mirar cómo me organizo y te digo.',
  'Sí, más tardecito miro y te escribo.',
  'Listo, tengo eso pendiente, luego te confirmo.',
  'Sí, dame un tiempo y te respondo seguro.',
  'Dale, más tarde te aviso cómo cuadramos.',
  'Sí, déjame ver un pendiente y te digo.',
];

const List<String> presenceCandidates = [
  'Dime.',
  'Sí, aquí estoy.',
  'Por acá ando, cuéntame.',
  'Sí, dime.',
  'Aquí sigo, cuéntame qué pasó.',
  'Por acá ando, ¿qué necesitas?',
  'Sí, aquí estoy pendiente.',
  'Dime, te leo.',
  'Por acá ando en la casa, cuéntame.',
  'Sí, cuéntame qué pasó.',
  'Aquí estoy, dime.',
];

const List<String> helpTaskCandidates = [
  'De una, cuéntame.',
  'Dale, ¿de qué es la tarea?',
  'De una, dime de qué se trata.',
  'Cuéntame, ¿de qué materia o tema es?',
  'Dale, dime qué hay que hacer.',
  'De una, cuéntame a ver en qué te ayudo.',
  'Listo, dime qué necesitas para la tarea.',
  'Dale, cuéntame de qué se trata y miramos.',
  'De una, dime qué tema es.',
  'Cuéntame qué necesitas hacer.',
  'Listo, dime de qué es y le hacemos.',
];

const List<String> helpGeneralCandidates = [
  'Dime.',
  'De una, dime.',
  'Cuéntame.',
  'Claro, dime.',
  'Dime, ¿en qué te colaboro?',
  'Cuéntame qué necesitas.',
  'De una, ¿qué pasó?',
  'Dime a ver si te puedo ayudar.',
  'Cuéntame, te escucho.',
  'Claro, dime qué pasó.',
  'De una, cuéntame qué necesitas.',
];

const List<String> locationCandidates = [
  'Por acá en Medellín.',
  'En Medellín, Colombia.',
  'Por acá por Medellín.',
  'En Medellín por ahora.',
  'Por acá en Medellín tranquilo.',
  'En Medellín, en la casa.',
  'Por Medellín por acá.',
  'Acá en Medellín, ¿qué pasó?',
  'En Medellín, todo bien por acá.',
  'Por acá en Medellín, cuéntame.',
  'En la casa acá en Medellín.',
];

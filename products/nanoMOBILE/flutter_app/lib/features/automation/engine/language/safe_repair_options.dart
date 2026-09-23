/// Catálogo inmutable de opciones para reparación determinista de conversaciones.
///
/// **QUÉ HACE:**
/// Centraliza los bancos de frases alternativas seguras con más de 10 opciones
/// por categoría para evitar respuestas mecánicas o monótonas en turnos reparados.
///
/// **CÓMO FUNCIONA:**
/// Expone listas constantes para preguntas redundantes y aperturas de cortesía.
///
/// **POR QUÉ:**
/// Desacopla la lógica de matching de los bancos de candidatos de texto (SOLID - SRP),
/// previniendo archivos extensos y facilitando la adición de nuevas variantes coloquiales.
library;

/// Opciones de fallback cuando se limpia una pregunta redundante de reciprocidad.
const List<String> safeRepairRedundantOptions = [
  'Por acá todo bien también.',
  'Todo en orden por acá.',
  'Bien, todo tranquilo.',
  'Todo bien, gracias a Dios.',
  'Bien por acá, todo en orden.',
  'Tranquilo por acá, todo bien.',
  'Por acá bien, gracias por preguntar.',
  'Todo marchando bien por acá.',
  'Bien también por acá.',
  'Todo en orden, gracias a Dios.',
  'Por acá tranquilo, todo marchando.',
  'Bien, todo marcha en orden.',
];

/// Opciones para reemplazar aperturas o muletillas de call-center con saludo personal.
const List<String> safeRepairCallCenterGreetingOptions = [
  '¡Hola!',
  'Hola, ¿cómo estás?',
  '¡Buenas! ¿Todo bien?',
  'Hola, ¿qué tal?',
  '¡Hola! ¿Cómo te va?',
  'Buenas, ¿todo bien por allá?',
  'Hola, ¿cómo va todo?',
  '¡Buenas! ¿Qué tal todo?',
  'Hola, ¿qué más?',
  '¡Hola! ¿Cómo andas?',
  'Buenas, ¿qué cuentas?',
  'Hola, ¿cómo va el día?',
];

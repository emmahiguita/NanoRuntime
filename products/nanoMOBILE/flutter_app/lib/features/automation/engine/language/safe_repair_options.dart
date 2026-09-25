/// Catálogo inmutable de opciones para reparación determinista de conversaciones.
///
/// **QUÉ HACE:**
/// Centraliza los bancos de frases alternativas seguras con más de 10 opciones
/// por categoría para evitar respuestas mecánicas o monótonas en turnos reparados.
///
/// **CÓMO FUNCIONA:**
/// Expone listas constantes para preguntas sobre planes/actividades, desplazamientos,
/// estado general en vivo, preguntas redundantes y aperturas de cortesía.
///
/// **POR QUÉ:**
/// Desacopla la lógica de matching de los bancos de candidatos de texto (SOLID - SRP),
/// previniendo archivos extensos y facilitando la adición de nuevas variantes coloquiales.
library;

/// Opciones para preguntas sobre planes, actividades o qué hará el dueño.
/// Todas admiten honestamente el estado sin inventar compromisos ni alucinar planes.
const List<String> safeRepairActivityOptions = [
  'Todavía no sé qué voy a hacer hoy; luego te cuento.',
  'Aún no lo he definido, más tarde te confirmo.',
  'No sé todavía qué plan tendré hoy.',
  'Todavía no tengo claro qué haré hoy.',
  'Aún no estoy seguro; cuando lo sepa te aviso.',
  'Por ahora no lo sé con certeza.',
  'No lo he decidido todavía, te cuento después.',
  'Todavía estoy mirando qué hacer hoy.',
  'Aún no tengo un plan confirmado.',
  'No sé qué haré todavía; luego lo reviso.',
  'Todavía no puedo confirmarte un plan.',
  'Aún no lo tengo claro, te aviso cuando sepa.',
];

/// Opciones para preguntas de desplazamiento físico, salidas o asistencia ("vas a ir").
const List<String> safeRepairGoingOptions = [
  'Todavía no sé si voy a ir hoy.',
  'Aún no sé si voy a ir.',
  'No sé todavía si vaya a ir hoy.',
  'Aún no confirmo si salgo más tarde.',
  'No estoy seguro todavía si voy.',
  'No sé si pueda ir hoy, más tarde te aviso.',
  'Todavía no sé si salgo hoy.',
  'Aún no sé si voy, tengo cosas pendientes.',
  'No estoy seguro de ir hoy, luego te confirmo.',
  'No sé la verdad si vaya hoy.',
  'Todavía no defino si voy a ir más tarde.',
  'Aún no sé si saldré hoy, luego te digo.',
];

/// Opciones para preguntas generales de estado en vivo del dueño sin fuente viva.
const List<String> safeRepairGeneralLiveStateOptions = [
  'Todavía no lo tengo decidido.',
  'Aún no lo sé con certeza.',
  'Todavía no defino eso bien.',
  'No sé todavía la verdad.',
  'Aún no estoy seguro de eso.',
  'No lo tengo muy claro todavía.',
  'Todavía no sé, más tarde miro bien.',
  'Aún no sé qué decirte de eso.',
  'No estoy seguro de eso por ahora.',
  'Todavía no tengo eso claro.',
  'Aún no lo he pensado bien.',
  'No sé con certeza por ahora.',
];

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

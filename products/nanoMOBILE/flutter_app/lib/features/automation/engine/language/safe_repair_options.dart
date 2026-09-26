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
  'Todavía no sé qué hacer hoy; luego te cuento.',
  'Aún no sé, no lo he definido; más tarde te confirmo.',
  'No sé todavía qué plan tendré hoy.',
  'Todavía no sé, no tengo claro qué haré hoy.',
  'Aún no tengo certeza; cuando lo sepa te aviso.',
  'Por ahora no lo sé con certeza.',
  'No lo he decidido todavía, no sé qué haré.',
  'Todavía no sé qué hacer hoy; te aviso más tarde.',
  'Aún no sé, no tengo un plan confirmado.',
  'No sé qué haré todavía; luego lo reviso.',
  'Todavía no sé, no puedo confirmarte un plan.',
  'Aún no sé, no lo tengo claro; te aviso cuando sepa.',
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

/// Opciones de reparación cuando el usuario corrige ("eso no lo pregunté yo", "no pregunté eso").
const List<String> safeRepairCorrectionOptions = [
  '¡Uy, qué pena! Me enredé ahí. Cuéntame, ¿qué era lo que me decías?',
  'Qué pena contigo parce, me crucé de tema. Dime qué necesitas y lo miramos.',
  '¡Ah, disculpa! Me confundí de mensaje. Decime qué era lo que necesitabas.',
  '¡Uy, qué pena! Respondí lo que no era. ¿En qué íbamos?',
  'Qué pena, me embolaté con el mensaje. Cuéntame qué pasó.',
  '¡Ah qué pena! Me crucé ahí. Dime y te pongo atención.',
  'Disculpa la confusión, me enredé. ¿Qué era lo que me comentabas?',
  '¡Uy qué pena contigo! Se me cruzaron los cables. Cuéntame bien.',
  'Qué pena, leí mal el mensaje. Decime qué necesitas con calma.',
  'Disculpa, respondí otra cosa. Dime qué era lo que me decías.',
  '¡Uy, me equivoqué ahí! Cuéntame qué era.',
  'Qué pena la confusión. Dime de nuevo y lo revisamos.',
];

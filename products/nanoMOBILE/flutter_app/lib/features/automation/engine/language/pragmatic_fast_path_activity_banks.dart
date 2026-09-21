part of 'pragmatic_fast_path.dart';

/// Bancos inmutables de respuestas para actividad y planes cotidianos.
///
/// **QUÉ HACE:**
/// Provee más de 10 opciones variadas y naturales para consultas sobre planes
/// del día, intenciones de salida, bienestar combinado y rutinas en curso.
///
/// **CÓMO FUNCIONA:**
/// Define listas constantes referenciadas directamente por _PragmaticFastPathActivity.
///
/// **POR QUÉ:**
/// Asegura una variabilidad conversacional fluida que evita respuestas repetitivas
/// y mantiene los archivos de lógica por debajo del umbral de 200 líneas (SOLID - SRP).
const List<String> activityPlansCandidates = [
  'No sé, estaré en casa.',
  'Estaré en casa, tengo cosas que hacer.',
  'No sé, estaré en casa, tengo cosas que hacer.',
  'Por ahora nada especial, aquí en la casa.',
  'Nada, por ahora aquí tranquilo en la casa.',
  'Aún no sé qué voy a hacer hoy, estaré en casa.',
  'Aquí haciendo unas cosas en la casa.',
  'No sé todavía, por acá trabajando en unas cosas.',
  'Aún no sé, tengo unas cosas que hacer en casa.',
  'No estoy seguro todavía, por ahora en casa tranquilo.',
  'Voy a ver qué hago más tarde, por ahora en la casa.',
  'No sé la verdad, por ahora aquí tranquilo.',
];

const List<String> activityGoingCandidates = [
  'Tal vez vaya, aún no sé.',
  'Creo que sí voy.',
  'Si puedo voy.',
  'Puede que vaya más tarde.',
  'Voy a ver qué hago.',
  'Hoy estoy algo ocupado, más tarde te aviso.',
  'Aún no sé seguro, más tarde te confirmo.',
  'Todavía no sé si salgo hoy.',
  'Más tarde miro si voy y te digo.',
  'No sé todavía si alcance a ir.',
  'Por ahora no sé seguro si vaya.',
  'Aún no lo tengo claro, luego te aviso.',
];

const List<String> activityGreetingWithWellbeingCandidates = [
  'Hola, bien, gracias a Dios. Aquí en el celular viendo memes.',
  'Hola, bien, gracias a Dios. Haciendo algo de programación.',
  'Hola. Bien, aquí molestando en el computador.',
  'Hola. Estoy bien, aquí en la casa tranquilo.',
  'Buenas. Todo bien, aquí en cama descansando.',
  'Hola, bien, gracias a Dios. Voy a comer, ¿y tú?',
  'Hola, todo bien por acá. En la casa haciendo unas cosas.',
  'Buenas, bien gracias a Dios. Por acá trabajando un rato.',
  'Hola, bien por acá. Tranquilo en la casa, ¿qué cuentas?',
  'Buenas, todo en orden. Por acá relajado en la casa.',
  'Hola, bien gracias a Dios. Leyendo unas cosas por acá.',
];

const List<String> activityGreetingCandidates = [
  'Hola. Aquí en el celular viendo memes.',
  'Hola. Haciendo algo de programación.',
  'Buenas. Nada, molestando en el computador.',
  'Hola. Estoy en la casa.',
  'Hola. Estoy en cama descansando.',
  'Hola. Voy a comer, ¿y tú?',
  'Buenas. Aquí trabajando en unas cosas.',
  'Hola. Por acá en la casa tranquilo.',
  'Buenas. Nada raro, por acá en la casa.',
  'Hola. Haciendo unas cosas por acá, dime.',
  'Hola. Por acá relajado un rato.',
];

const List<String> activityWithWellbeingCandidates = [
  'Bien, gracias a Dios. Aquí en el celular viendo memes.',
  'Bien, gracias a Dios. Haciendo algo de programación.',
  'Todo bien. Nada, molestando en el computador.',
  'Estoy bien. Aquí en cama descansando.',
  'Bien por ahora. Estoy en la casa tranquilo.',
  'Bien, gracias a Dios. Voy a comer, ¿y tú?',
  'Todo bien por acá. Haciendo unas cosas en la casa.',
  'Bien gracias a Dios. Por acá trabajando un rato.',
  'Todo en orden. Por acá relajado en la casa.',
  'Bien, todo marchando tranquilo en casa.',
  'Bien gracias a Dios. Aquí descansando un rato.',
];

const List<String> activityGeneralCandidates = [
  'Aquí en el celular viendo memes.',
  'Estoy haciendo algo de programación.',
  'Nada, molestando en el computador.',
  'Estoy en la casa.',
  'Estoy en cama descansando.',
  'Voy a comer, ¿y tú?',
  'Aquí trabajando un rato.',
  'Nada, aquí tranquilo en la casa.',
  'Por acá en la casa haciendo unas cosas.',
  'Terminando unas cosas por acá.',
  'Por acá relajado en la casa.',
  'Haciendo unas cosas aquí en la casa.',
];

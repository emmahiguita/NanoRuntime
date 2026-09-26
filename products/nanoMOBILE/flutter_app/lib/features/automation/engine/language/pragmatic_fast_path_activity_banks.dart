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
  'Todavía no tengo planes definidos para hoy; luego te cuento.',
  'Aún no sé, no lo he definido; más tarde te confirmo.',
  'No sé todavía qué plan tendré hoy, más tarde miramos.',
  'Por ahora sin planes fijos para hoy, ¿qué cuentas?',
  'Aún no tengo nada planeado para hoy, ¿tú qué tal?',
  'Todavía no he cuadrado nada para hoy; luego te digo.',
  'Por ahora nada fijo hoy, cuéntame qué tal tu día.',
  'Aún no tengo un plan claro para hoy; más tarde te aviso.',
  'No sé todavía, no tengo nada cuadrado por ahora.',
  'Por ahora sin planes concretos para hoy, ¿qué hay de nuevo?',
  'Todavía no sé qué resulte para hoy, luego charlamos.',
  'Aún no he definido planes para hoy, ¿y tú?',
];

const List<String> activityGoingCandidates = [
  'Tal vez vaya, aún no sé.',
  'Creo que sí voy.',
  'Si puedo voy.',
  'Puede que vaya más tarde.',
  'Más tarde miro y te confirmo.',
  'Hoy tengo el día apretado, más tarde te aviso.',
  'Aún no sé seguro, más tarde te confirmo.',
  'Todavía no sé si salgo hoy.',
  'Más tarde miro si voy y te digo.',
  'No sé todavía si alcance a ir.',
  'Por ahora no sé seguro si vaya.',
  'Aún no lo tengo claro, luego te aviso.',
];

const List<String> activityGreetingWithWellbeingCandidates = [
  'Hola, bien, gracias a Dios. Por acá atento, ¿y tú?',
  'Hola, bien, gracias a Dios. Todo tranquilo por acá, ¿qué cuentas?',
  'Hola. Bien por acá, ¿cómo vas tú?',
  'Buenas. Todo bien, gracias a Dios, ¿qué más?',
  'Hola, todo bien por acá. Cuéntame, ¿cómo va todo?',
  'Buenas, bien gracias a Dios. ¿Cómo te ha ido?',
  'Hola, bien por acá. ¿Qué cuentas?',
  'Buenas, todo en orden por acá, ¿y tú?',
  'Hola, bien gracias a Dios. Dime, ¿qué tal todo?',
  'Hola, todo tranquilo gracias a Dios, ¿cómo vas?',
];

const List<String> activityGreetingCandidates = [
  'Hola. Todo tranquilo por acá, ¿qué cuentas?',
  'Hola. Por acá atento, dime.',
  'Buenas. Todo en orden por acá, ¿y tú?',
  'Hola. ¿Qué más? Cuéntame.',
  'Buenas. Por acá pendiente, ¿cómo vas?',
  'Hola. Todo bien por acá, dime.',
  'Buenas. ¿Qué tal todo? Cuéntame.',
  'Hola. Aquí atento, ¿qué me cuentas?',
  'Hola. Todo tranquilo, ¿cómo te va?',
  'Buenas. Dime, ¿cómo va todo?',
];

const List<String> activityWithWellbeingCandidates = [
  'Bien, gracias a Dios. Todo tranquilo por acá, ¿y tú?',
  'Bien, gracias a Dios. Por acá atento, ¿qué cuentas?',
  'Todo bien. Por acá pendiente, ¿cómo vas?',
  'Bien por ahora, gracias a Dios. ¿Qué tal tú?',
  'Todo bien por acá. Cuéntame, ¿cómo va todo?',
  'Bien gracias a Dios. ¿Cómo te ha ido?',
  'Todo en orden por acá, ¿y tú qué cuentas?',
  'Bien, todo marchando tranquilo, ¿cómo vas?',
  'Bien gracias a Dios. Dime, ¿qué necesitas?',
  'Todo tranquilo gracias a Dios, ¿y tú?',
];

const List<String> activityGeneralCandidates = [
  'Por acá tranquilo, ¿qué cuentas?',
  'Todo en orden por acá, dime.',
  'Por acá atento, ¿qué más?',
  'Nada extraordinario por ahora, ¿y tú qué cuentas?',
  'Por acá pendiente, cuéntame.',
  'Todo tranquilo por acá, ¿cómo vas?',
  'Aquí atento, dime qué necesitas.',
  'Todo bien por acá, ¿qué me cuentas?',
  'Por ahora tranquilo, ¿y tú?',
  'Todo en orden, cuéntame.',
];

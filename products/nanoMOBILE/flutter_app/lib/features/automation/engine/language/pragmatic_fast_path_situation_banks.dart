part of 'pragmatic_fast_path.dart';

/// Bancos inmutables de candidatos para situaciones cotidianas ampliadas.
///
/// **QUÉ HACE:**
/// Provee más de 10 opciones para disponibilidad, comida, casa, familia,
/// descanso/sueño, música, clima, llamadas, ausencia y opinión.
///
/// **CÓMO FUNCIONA:**
/// Expone listas constantes consumidas en _PragmaticFastPathSituations.
///
/// **POR QUÉ:**
/// Enriquece la conversación cotidiana con vocabulario natural y no repetitivo,
/// desacoplando los textos de la lógica situacional.
const List<String> availabilityCandidates = [
  'Ahora estoy algo ocupado, cuéntame.',
  'Estoy ocupado con unas cosas, ¿qué pasó?',
  'Dime, tengo un momento.',
  'Estoy un poco ocupado, más tarde hablamos bien.',
  'Por acá ando algo ocupado, dime.',
  'Un poco ocupado por acá, pero cuéntame.',
  'En unas cosas ocupado, ¿qué necesitas?',
  'Por acá haciendo unas cosas, dime rápido si quieres.',
  'Algo ocupado por acá, cuéntame qué pasó.',
  'Dime, por acá ando medio ocupado pero te leo.',
  'Estoy con unas tareas pendientes, dime.',
];

const List<String> lunchCandidates = [
  'Sí, ya almorcé.',
  'Ya almorcé hace un rato.',
  'Aún no, en esas ando.',
  'Todavía no, más tarde como algo.',
  'Sí, ya almorcé por acá.',
  'Ya comí hace un ratico, gracias por preguntar.',
  'Aún no he almorzado, ya casi.',
  'Todavía no he almorzado, en un rato como algo.',
  'Sí, almorcé hace poco.',
  'Apenas voy a almorzar en un rato.',
  'Sí, ya almorcé por acá, todo bien.',
];

const List<String> dinnerCandidates = [
  'Sí, ya cené.',
  'Ya comí algo hace un rato.',
  'Aún no, más tarde ceno.',
  'Todavía no, en esas ando.',
  'Sí, ya cené por acá tranquilo.',
  'Aún no ceno, más tardecito.',
  'Ya comí hace un rato por acá.',
  'Todavía no, voy a ver qué como ahora.',
  'Sí, ya comí algo ligero.',
  'Apenas voy a cenar en un rato.',
  'Ya cené hace un rato, todo bien.',
];

const List<String> foodGeneralCandidates = [
  'Sí, ya comí.',
  'Ya comí hace un rato.',
  'Aún no, en esas ando.',
  'Todavía no, más tarde como algo.',
  'Sí, todo bien por ese lado.',
  'Ya comí hace un ratico.',
  'Aún no he comido, más tarde miro.',
  'Sí, ya comí algo por acá.',
  'Todavía no, voy a comer algo en un momento.',
  'Apenas voy a comer algo ahora.',
  'Sí, ya comí por acá tranquilo.',
];

const List<String> physicalLocationCandidates = [
  'Aquí en la casa.',
  'Por acá en la casa, tranquilo.',
  'En la casa, ¿qué pasó?',
  'Por acá en la casa, cuéntame.',
  'En la casa, todo bien.',
  'Por acá en la casa descansando.',
  'Aquí en la casa haciendo unas cosas.',
  'En la casa por ahora, tranquilo.',
  'Por acá en la casa relajado.',
  'Aquí en casa, ¿qué cuentas?',
  'En la casa tranquilo, dime.',
];

const List<String> familyCandidates = [
  'Todo bien por acá, gracias a Dios.',
  'Todos bien por acá, gracias por preguntar.',
  'Todo en orden en la casa, gracias a Dios.',
  'Bien, gracias a Dios, todos bien.',
  'Por acá todos bien y tranquilos.',
  'Todo marchando bien con todos, gracias a Dios.',
  'Todos bien por la casa, gracias a Dios.',
  'Muy bien todos por acá, gracias por preguntar.',
  'En orden por acá todos, gracias a Dios.',
  'Todos tranquilos por acá, gracias a Dios.',
  'Bien gracias a Dios, todo en orden por la familia.',
];

const List<String> sleepCandidates = [
  'Sí, ya casi me voy a dormir.',
  'Por acá todavía despierto, haciendo unas cosas.',
  'Sí, ya me va a dar sueño.',
  'Aquí terminando algo y ya me acuesto.',
  'Aún despierto por acá, tranquilo.',
  'Ya casi me acuesto a descansar.',
  'Por acá despierto un ratico más.',
  'Sí, terminando unas cosas para irme a dormir.',
  'Aún despierto, viendo unas cosas en el celular.',
  'Ya casi a dormir, un poco cansado.',
  'Por acá terminando el día para irme a dormir.',
];

const List<String> musicCandidates = [
  'Por acá escuchando un rap tranquilo.',
  'Un poco de música variada para concentrarme.',
  'Escuchando unas instrumentales por acá.',
  'Un poco de todo por acá.',
  'Escuchando algo de rap por acá tranquilo.',
  'Unas instrumentales y beats por acá.',
  'Un poco de música para pasar el rato.',
  'Escuchando música relajada por acá.',
  'Un poco de rap y beats para camellar.',
  'Variado por acá, escuchando música tranquila.',
  'Por acá con algo de música de fondo.',
];

const List<String> weatherSocialCandidates = [
  'Por acá está fresco el clima.',
  'Por acá todo tranquilo con el clima.',
  'Un poco nublado por acá.',
  'Por acá normal, clima tranquilo.',
  'Está haciendo un clima fresco por acá.',
  'Por acá fresco, no hace tanto calor.',
  'Está agradable el clima por acá hoy.',
  'Clima fresco por este lado.',
  'Por acá templado, todo tranquilo.',
  'Un poco frío por acá, pero bien.',
  'Por acá fresco y calmado el clima.',
];

const List<String> callCandidates = [
  'Por ahora mejor por mensaje, estoy algo ocupado.',
  'Escríbeme por acá mejor, dime.',
  'Ahora no puedo llamada, cuéntame por acá.',
  'Más tarde si algo me marcas, ahora ando ocupado.',
  'Mejor por chat ahora, estoy ocupado con unas cosas.',
  'Dime por acá mejor, no puedo contestar llamada ahora.',
  'Por ahora texto mejor, cuéntame.',
  'Estoy en unas cosas, escríbeme por acá mejor.',
  'Por mensaje mejor ahora, ¿qué necesitas?',
  'Ahora no alcanzo a llamada, cuéntame por chat.',
  'Escríbeme por mensaje y te voy respondiendo.',
];

const List<String> lostOrMissingCandidates = [
  'Aquí ando, ocupado con unas cosas.',
  'Jaja nada, aquí en lo mío, cuéntame.',
  'Por acá sigo, ocupado trabajando.',
  'Jaja por aquí en la casa, ¿qué cuentas?',
  'Aquí ando camellando en unas cosas, cuéntame.',
  'Jaja nada, algo ocupado por acá pero todo bien.',
  'Aquí en la casa tranquilo, ¿qué más?',
  'Aquí sigo en lo mío, ¿qué hubo?',
  'Jaja por acá ando, ocupado con unas tareas.',
  'Nada perdido jaja, por acá trabajando.',
  'Aquí ando firme, ¿qué cuentas?',
];

const List<String> opinionSocialCandidates = [
  'Se ve bien, me gusta.',
  'Está bueno, me parece que queda bien.',
  'Se ve bacano.',
  'Me parece que está bien así.',
  'Sí, aguanta bastante.',
  'Queda muy bien así, me gusta.',
  'Se ve chévere, me parece bien.',
  'Sí, está bacano así.',
  'Me parece que está bien.',
  'Se ve súper bien la verdad.',
  'Sí, me gusta, queda muy bien.',
];

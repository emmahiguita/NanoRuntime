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
  'Todo bien por acá, gracias por preguntar, ¿y tú ya almorzaste?',
  'Por acá todo en orden, ¿qué tal estuvo tu almuerzo?',
  'Todo tranquilo por acá, ¿y tú qué almorzaste?',
  'Por acá pendiente de mis cosas, ¿tú ya almorzaste?',
  'Todo bien gracias a Dios, ¿qué tal el almuerzo por allá?',
  'Por acá todo tranquilo, gracias por preguntar, ¿y tú?',
  'Todo en orden por este lado, ¿ya comiste tú?',
  'Por acá bien gracias a Dios, ¿y tú qué tal vas con el almuerzo?',
  'Todo tranquilo, cuéntame qué tal va tu tarde.',
  'Por acá al pendiente, ¿y tú ya almorzaste bien?',
  'Todo muy bien por acá, ¿qué cuentas tú?',
];

const List<String> dinnerCandidates = [
  'Todo bien por acá, gracias por preguntar, ¿y tú ya cenaste?',
  'Por acá todo tranquilo, ¿qué tal estuvo tu cena?',
  'Todo en orden por este lado, ¿y tú ya comiste algo?',
  'Por acá bien gracias a Dios, ¿qué tal la noche por allá?',
  'Todo tranquilo por acá, ¿y tú qué cenaste?',
  'Por acá al pendiente, gracias por preguntar, ¿y tú?',
  'Todo bien gracias a Dios, ¿cómo va tu noche?',
  'Por acá todo en orden, ¿ya descansando por allá?',
  'Todo tranquilo, cuéntame qué tal estuvo tu día.',
  'Por acá bien, ¿y tú ya cenaste tranquilo?',
  'Todo muy bien por acá, ¿qué cuentas esta noche?',
];

const List<String> foodGeneralCandidates = [
  'Todo bien por acá, gracias por preguntar, ¿y tú ya comiste?',
  'Por acá todo en orden, ¿y tú qué tal vas con eso?',
  'Todo tranquilo por este lado, ¿ya comiste tú?',
  'Por acá bien gracias a Dios, ¿y tú qué cuentas?',
  'Todo en orden, gracias por preguntar, ¿qué tal tu día?',
  'Por acá tranquilo, ¿y tú ya comiste algo rico?',
  'Todo bien por acá, cuéntame qué tal todo por allá.',
  'Por acá al pendiente, ¿y tú cómo vas hoy?',
  'Todo muy bien gracias a Dios, ¿y tú?',
  'Por acá todo tranquilo, dime qué cuentas.',
  'Todo bien por ese lado, ¿y tú qué tal?',
];

const List<String> physicalLocationCandidates = [
  'Por acá ocupado con unas cosas, dime qué pasó.',
  'Por acá en mis vueltas, cuéntame qué necesitas.',
  'Aquí pendiente del mensaje, ¿qué pasó?',
  'Por acá en unas diligencias, cuéntame.',
  'Aquí al pendiente, dime qué cuentas.',
  'Por acá ocupado un momento, ¿qué necesitas?',
  'En mis cosas por ahora, cuéntame.',
  'Por acá pendiente, dime rápido si quieres.',
  'Aquí atento a lo que me digas, ¿qué pasó?',
  'Por acá en lo mío, ¿qué cuentas?',
  'Pendiente por acá, dime.',
];

const List<String> familyCandidates = [
  'Todo bien por acá, gracias a Dios.',
  'Todos bien por acá, gracias por preguntar.',
  'Todo en orden en la familia, gracias a Dios.',
  'Bien, gracias a Dios, todos bien.',
  'Por acá todos bien y tranquilos.',
  'Todo marchando bien con todos, gracias a Dios.',
  'Todos bien gracias a Dios, ¿y por allá cómo están?',
  'Muy bien todos por acá, gracias por preguntar.',
  'En orden por acá todos, gracias a Dios.',
  'Todos tranquilos por acá, gracias a Dios.',
  'Bien gracias a Dios, todo en orden por la familia.',
];

const List<String> sleepCandidates = [
  'Por acá todavía pendiente un momento, dime.',
  'Aquí atento al mensaje, ¿qué pasó?',
  'Por acá cerrando unas pendientes, cuéntame.',
  'Aquí te leo, dime qué necesitas.',
  'Todavía atento por acá, ¿qué cuentas?',
  'Por acá pendiente antes de desconectarme, dime.',
  'Aquí estoy atento un ratico, cuéntame.',
  'Por acá revisando el mensaje, ¿qué pasó?',
  'Todavía pendiente por acá, dime.',
  'Aquí te leo rápido, cuéntame qué pasó.',
  'Por acá atento todavía, dime.',
];

const List<String> musicCandidates = [
  'Me gusta escuchar un buen rap tranquilo o instrumentales.',
  'Un poco de música variada cuando toca concentrarse.',
  'Me traman las instrumentales y los buenos beats.',
  'Un poco de todo, sobre todo rap y música relajada.',
  'Siempre aguanta algo de rap tranquilo o beats.',
  'Me gustan las instrumentales y beats para concentrarme.',
  'Un poco de buena música variada siempre viene bien.',
  'Me gusta la música relajada y el buen rap, ¿y a ti?',
  'Un poco de rap y beats cuando estoy concentrado.',
  'Variado, me gusta la música tranquila y con buen ritmo.',
  'Siempre suma buena música de fondo, ¿qué escuchas tú?',
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
  'Por acá sigo, ocupado con unos pendientes.',
  'Jaja por aquí al pendiente, ¿qué cuentas?',
  'Aquí ando en unas cosas, cuéntame.',
  'Jaja nada, algo ocupado por acá pero todo bien.',
  'Aquí tranquilo en mis cosas, ¿qué más?',
  'Aquí sigo en lo mío, ¿qué hubo?',
  'Jaja por acá ando, ocupado con unas tareas.',
  'Nada perdido jaja, por acá al pendiente.',
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

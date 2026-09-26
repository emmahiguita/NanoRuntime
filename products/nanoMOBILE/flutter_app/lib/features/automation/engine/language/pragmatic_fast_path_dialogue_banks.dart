part of 'pragmatic_fast_path.dart';

/// Bancos inmutables de candidatos para interacciones de diálogo unificado.
///
/// **QUÉ HACE:**
/// Provee más de 10 opciones para preguntas recíprocas, invitaciones, rap,
/// aclaraciones, entrenamiento y estado del día.
///
/// **CÓMO FUNCIONA:**
/// Expone listas constantes consumidas en _PragmaticFastPathComposer.
///
/// **POR QUÉ:**
/// Maximiza la riqueza conversacional y mantiene el compositor en < 120 líneas.
const List<String> reciprocalCandidates = [
  'Bien, gracias a Dios.',
  'Todo bien, gracias a Dios.',
  'Bien también, todo tranquilo.',
  'Bien también, gracias a Dios.',
  'Bien por ahora.',
  'Todo bien por acá, tranquilo.',
  'Bien por acá, todo en orden.',
  'Bien gracias a Dios, aquí en casa.',
  'Todo marchando bien por acá.',
  'Bien por acá, ¿tú qué tal?',
  'Tranquilo por acá, todo bien.',
  'Bien gracias a Dios, todo en orden.',
];

const List<String> userWellbeingActivityCandidates = [
  'Qué bueno. Aquí haciendo unas cosas.',
  'Me alegra. Aquí trabajando un rato.',
  'Qué bien. Nada, aquí tranquilo.',
  'Qué bueno. Aquí en la casa.',
  'Me alegra. Por acá en lo mío.',
  'Qué bueno. Por acá relajado en la casa.',
  'Me alegra mucho. Aquí terminando unas cosas.',
  'Qué bien. Por acá haciendo unas cosas pendientes.',
  'Qué bueno, me alegra. Por acá tranquilo.',
  'Excelente. Por acá en casa trabajando.',
  'Me alegra. Nada raro por acá, en casa.',
];

/// Respuestas deterministas para reaseguros sociales o empatía del interlocutor ("me alegra", "qué bueno",
/// "calma mi amor", "tranquila", "no te pongas así"). Evita contra-preguntas o frases de call center;
/// cierra con calidez y reciprocidad natural (> 15 opciones mezcladas para variedad).
const List<String> socialReassuranceCandidates = [
  '¡Sisas parce!',
  '¡De una!',
  '¡Total!',
  '¡A mí también!',
  '¡Qué bien!',
  '¡Así es!',
  '¡Un abrazo!',
  '¡Cualquier cosa me avisás!',
  '¡Dale pues!',
  '¡Listo pues!',
  '¡Hablamos!',
  '¡Claro que sí!',
  // Respuestas afectivas para "Calma mi amor", "Tranquila", "No te pongas así":
  'Tranquilo amor, acá estoy.',
  'Calma, todo bien. ¿Qué pasó?',
  'Todo bien, no te preocupes.',
  'Aquí estoy, sin drama.',
  'Calma parce, todo en orden.',
  'Ya, ya. Todo bien por acá.',
];

const List<String> rapCandidates = [
  'Sí, quiero ir a rapear.',
  'Quiero ir a rapear un rato.',
  'Sí, vamos a rapear.',
  'Puede ser, hace rato no rapeo.',
  'Quiero tirar unas rimas.',
  'De una, vamos a rapear.',
  'Sí, aguanta ir a rapear un rato.',
  'Hagámosle, vamos a rapear.',
  'De una, saquemos unas rimas.',
  'Sí, de una, vamos a tirar rimas y free.',
  'Totalmente, vamos a rapear.',
];

const List<String> invitationCandidates = [
  'Sí, vamos.',
  '¿Vamos?',
  'Sí, hagámosle.',
  'Dale, vamos.',
  'Puede ser, ¿a qué hora?',
  'Listo, vamos.',
  'De una, hagámosle.',
  'Listo, me parece bien.',
  'Hagámosle pues, ¿cuándo?',
  'Sí, de una, me avisas y vamos.',
  'Dale de una, me sirve.',
];

const List<String> wellbeingClarificationCandidates = [
  'Ah bueno jaja.',
  'Ah listo jaja.',
  'Jaja bueno, qué bien.',
  'Ah bueno, todo bien.',
  'Listo pues jaja.',
  'Jaja qué bien.',
  'Ah ya entendí jaja, todo bien.',
  'Jaja listo, todo en orden.',
  'Ah bueno, me alegra saberlo.',
  'Jaja dale, todo bien pues.',
  'Ah listo, menos mal.',
];

const List<String> userWellbeingPureCandidates = [
  'Qué bueno.',
  'Me alegra.',
  'Qué bien.',
  'Ah bueno, me alegra.',
  'Qué bueno, todo bien.',
  'Me alegra mucho.',
  'Excelente, me alegra.',
  'Qué bueno saberlo.',
  'Me alegra bastante.',
  'Qué bien, todo en orden.',
  'Súper, me alegra mucho.',
];

const List<String> trainingCandidates = [
  'Aún no sé seguro si voy a entrenar hoy, más tarde confirmo.',
  'Por ahora no estoy seguro del entreno de hoy.',
  'Aún no sé si entreno hoy, más tarde miro.',
  'Aún no sé, más tarde confirmo.',
  'Todavía no sé si voy a entrenar hoy.',
  'No estoy seguro si entreno hoy, luego te aviso.',
  'Aún no defino lo del entreno de hoy.',
  'No sé todavía si alcance a entrenar hoy.',
  'Más tarde miro si entreno y te digo.',
  'Por ahora no sé seguro si voy a entrenar.',
  'Aún no sé, tengo unas cosas que hacer antes.',
];

const List<String> trainingWithGreetingCandidates = [
  'Hola. Todo bien por acá, el día va tranquilo. Aún no sé seguro si entreno hoy.',
  'Hola, todo en orden. Todavía no sé seguro lo del entreno de hoy.',
  'Buenas. Por acá todo bien, tranquilo. Aún no confirmo si entreno.',
  'Hola, por acá todo bien. Más tarde miro si voy a entrenar hoy.',
  'Buenas, todo en orden por acá. Aún no sé seguro lo del entreno.',
  'Hola, el día va bien. Todavía no tengo seguro si entreno hoy.',
  'Buenas, todo marchando bien. Más tarde te confirmo si entreno.',
  'Hola, todo tranquilo. Aún no sé si vaya a entrenar hoy.',
  'Buenas, todo bien gracias a Dios. Todavía no confirmo entreno.',
  'Hola, por acá todo bien. Aún no sé qué haré con el entreno hoy.',
  'Buenas, el día va tranquilo. Más tarde miro si entreno hoy.',
];

const List<String> dayCandidates = [
  'El día va bien y tranquilo por acá.',
  'Todo bien por acá, el día va marchando bien.',
  'Va bien por acá, tranquilo.',
  'Por acá todo en orden con el día.',
  'Va marchando bien el día por acá.',
  'Tranquilo por acá, todo bien con el día.',
  'Bien gracias a Dios, el día va marchando.',
  'Todo en orden por acá, día tranquilo.',
  'Va bien el día, gracias a Dios.',
  'Por acá todo bien y en orden.',
  'El día va marchando tranquilo por acá.',
];

const List<String> dayWithGreetingCandidates = [
  'Hola, el día va bien y tranquilo por acá.',
  'Hola. Todo bien por acá, el día va marchando bien.',
  'Buenas. Por acá el día va bien.',
  'Hola, todo en orden por acá con el día.',
  'Buenas, va marchando bien el día por acá.',
  'Hola, todo tranquilo por acá gracias a Dios.',
  'Buenas, el día va marchando bien y en orden.',
  'Hola, por acá el día va marchando tranquilo.',
  'Buenas, todo bien por acá con el día.',
  'Hola, gracias a Dios el día va marchando bien.',
  'Buenas, tranquilo por acá el día.',
];

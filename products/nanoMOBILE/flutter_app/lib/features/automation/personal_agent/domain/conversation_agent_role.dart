/// AUTO-02 — rol de especialización conversacional del turno.
///
/// DISTINTO de `AgentRole` (engine/agents/agent_role.dart): aquel orquesta
/// roles internos de ejecución del chat (planner, perception, executor...);
/// este clasifica el DOMINIO del turno entrante (personal/sales/support/
/// general). No es un motor: es un selector determinista PURO (sección 47:
/// jamás un router LLM con modelos pequeños). El mensaje actual SIEMPRE
/// manda (sección 26): el rol se recalcula cada turno, nunca se arrastra.
///
/// Los agentes no son bots distintos: ROL + PERSONA + MEMORIA + POLÍTICA
/// sobre el mismo Nano Core. Aquí solo nace el ROL; persona/memoria/política
/// ya viven en PersonaContext, convstate y ConversationDecisionEngine.
///
/// P0-ROUTE (2026-09-06) — INVARIANTE NUEVO: NO COMMERCIAL INTENT = NO
/// SALES CONTEXT. La entidad lingüística NO basta: "los pongo a chupar la
/// crema alpina" matchea un producto del catálogo pero NO es una consulta
/// comercial. SALES exige producto (o producto activo de la conversación)
/// Y una señal comercial verificable (precio/stock/envío/pedido). Además:
/// identidad del dueño → PERSONAL, corrección del cliente → PERSONAL,
/// rechazo de ayuda → PERSONAL, queja de pedido → SUPPORT.
library;

import '../../engine/business/business_facts.dart';
import '../../engine/business/fact_selector.dart'
    show normalizeText, tokenizeText;
import '../../engine/language/turn_complexity_classifier.dart'
    show turnComplexityClassifier;
import '../../engine/messaging/conv_turn_state.dart'
    show contextSignalsFor, greetingTokens, isPureGreeting;

/// Especialización que atiende el turno.
enum ConversationAgentRole {
  /// Conversación social/estilo del dueño (amigos, contactos registrados,
  /// identidad, correcciones y rechazos de ayuda).
  personal,

  /// Conversación comercial (productos, precios, horario, envío).
  sales,

  /// Conversación de problema con un pedido o queja (política de soporte).
  support,

  /// Conversación sin señales específicas (desconocidos, miscelánea).
  general,
}

/// Resultado del routing: rol + razones legibles para la traza [agent].
///
/// P0-MULTI (2026-09-06) — [commercialIntent] es ORTOGONAL al rol: un turno
/// multi-dominio ("hola bro, ¿está Emmanuel y todavía tienen el Negro?")
/// rutea PERSONAL (identidad manda) PERO lleva intención comercial real
/// (producto + señal de stock/precio). El writer gatea <DATOS DEL NEGOCIO>
/// por rol sales O commercialIntent: UNA respuesta con estilo del dueño y
/// facts reales, jamás un chat entre agentes.
final class ConversationAgentRouting {
  final ConversationAgentRole role;
  final List<String> reasons;
  final bool commercialIntent;

  /// CONV-STATE-02 — el mensaje responde la PREGUNTA PENDIENTE de Nano
  /// (≤3 tokens, sin señal comercial). El writer lo usa para dejar entrar
  /// el bloque <PREGUNTA PENDIENTE> en turnos personales: es diálogo del
  /// propio dueño, jamás contexto de negocio.
  final bool pendingReply;

  const ConversationAgentRouting({
    required this.role,
    required this.reasons,
    this.commercialIntent = false,
    this.pendingReply = false,
  });
}

/// P0-ROUTE — señales de INTENCIÓN COMERCIAL. Un producto matcheado sin
/// ninguna de estas señales NO es una consulta de venta (casual, broma,
/// mención al pasar): el turno no recibe contexto comercial.
const Set<String> commercialIntentTokens = {
  'cuanto',
  'cuantos',
  'cuantas',
  'vale',
  'valen',
  'precio',
  'precios',
  'coste',
  'cuesta',
  'tienen',
  'tienes',
  'tenes',
  'hay',
  'stock',
  'disponible',
  'disponibilidad',
  'talla',
  'tallas',
  'envio',
  'envios',
  'entrega',
  'pedido',
  'pedidos',
  'comprar',
  'compro',
  'reservar',
  'apartar',
  'referencia',
  'referencias',
};

/// P0-SOCIAL-2 — marca de traza para producto mencionado SIN intención
/// comercial. El writer la consulta: un turno mixto (social + producto)
/// conserva el prompt completo aunque el rol sea personal; el prompt social
/// mínimo respondería solo al lado social e ignoraría el producto.
const String productMentionedWithoutCommerce =
    'producto mencionado sin señal comercial (no es venta)';

/// P0-ROUTE — frases de CORRECCIÓN meta-conversacional ("¿cuál negro de qué
/// hablas?"): el cliente está deshaciendo/pidiendo aclaración del turno
/// anterior. Es conversación PERSONAL, jamás una consulta de catálogo.
const List<String> correctionPhrases = [
  'de que hablas',
  'no me refiero',
  'no pregunte eso',
  'no es eso',
  'no te pedi',
];

/// P0-ROUTE — frases de QUEJA/PROBLEMA de pedido: dominio SUPPORT, no
/// SALES ("mi pedido llegó malo" no consulta catálogo aunque diga pedido).
const List<String> supportPhrases = [
  'llego mal',
  'llegado mal',
  'mal llego',
  'no llego',
  'no me llego',
  'danado',
  'dano',
  'problema',
  'reclamo',
  'devolver',
  'reembolso',
  'queja',
  'malo',
  'mala',
];

/// P0-SOCIAL (2026-09-06) — tokens de conversación casual coloquial que el
/// set de saludo puro (CONTEXT-GATE-01) no cubre: "que haces", "jajaja",
/// "bro". Señal social = mensaje CORTO (≤3 tokens) y TODOS sus tokens en
/// greetingTokens ∪ socialCasualTokens. Evidencia viva del fallo: "hola" y
/// "como estas" cayeron a GENERAL por la rama "saludo puro sin relación
/// registrada" y el 1.5B respondió call-center ("¿En qué más puedo
/// ayudarte?"). SOCIAL PURO ES PERSONAL, sin relación de por medio.
const Set<String> socialCasualTokens = {
  'haces',
  'haciendo',
  'jajaja',
  'jajaj',
  'jaja',
  'jeje',
  'jajajaja',
  'bro',
  'parce',
  'parcero',
  'mano',
  'amigo',
  'amiga',
  'socio',
  'cuentame',
  'contame',
};

/// P0-SOCIAL-2 (2026-09-06) — reacciones/continuaciones sociales más
/// largas que el casual corto: "me alegra que estes bien", "que bueno",
/// "gracias", "dale, listo". Evidencia viva: "Me alegra que estes bien"
/// (respuesta al "Estoy bien" del dueño) cayó a GENERAL — el casual corto
/// exige ≤3 tokens y el mensaje trae 5. Sin señales de negocio (los gates
/// comerciales ya salieron antes en la cadena), un token de reacción
/// social marca conversación social pura → PERSONAL.
const Set<String> socialReactionTokens = {
  'alegra',
  'alegro',
  'alegras',
  'alegre',
  'alegran',
  // PROD-SOCIAL-03 (2026-09-07) — respuesta al saludo de Nano: "bien y tu
  // como estas?" cayó a GENERAL porque 'bien' faltaba (solo 'bueno'/'buena'
  // estaban, evidencia previa de "me alegra que estes bien"). "bien" es LA
  // respuesta al "¿cómo estás?" — reacción social pura por excelencia.
  'bien',
  'bueno',
  'buena',
  'genial',
  'excelente',
  'perfecto',
  'perfecta',
  'gracias',
  'dale',
  'listo',
  'vale',
  'claro',
  'obvio',
  'chevere',
  'bacano',
  'tranqui',
  'feliz',
  'contento',
  'contenta',
  'encanta',
  'gusto',
  'ok',
  'okay',
  'entendido',
  // PROD-SOCIAL-04 (2026-09-07) — tokens de risa y vocativos también como
  // reacción (sin límite de longitud): "si creo mano jajajaja" (4 tokens)
  // cayó a GENERAL porque 'jajajaja' solo estaba en el casual corto (≤3).
  // Tercera evidencia del mismo bug estructural: un token social lo es con
  // cualquier longitud. Los mensajes comerciales salieron antes por SALES.
  'haces',
  'haciendo',
  'jajaja',
  'jajaj',
  'jaja',
  'jeje',
  'jajajaja',
  'bro',
  'parce',
  'parcero',
  'mano',
  'amigo',
  'amiga',
  'socio',
  'cuentame',
  'contame',
};

/// P0-FAMILY (2026-09-06) — personas del entorno del dueño. "¿está tu
/// papá?" NO menciona al dueño por nombre ni es saludo puro: sin esta señal
/// caía a GENERAL (evidencia viva: "ESTA TU PAPA EN CASA" respondido con
/// fallback genérico). Familia + verbo de presencia/ubicación → PERSONAL
/// (identidad doméstica, jamás consulta de catálogo). "¿está el Negro?" NO
/// dispara: 'negro' no es familiar (y el producto activo ya tiene su ruta).
const Set<String> familyTokens = {
  'papa',
  'mama',
  'mami',
  'papi',
  'tio',
  'tia',
  'hermano',
  'hermana',
  'hijo',
  'hija',
  'esposa',
  'esposo',
  'marido',
  'novia',
  'novio',
  'jefe',
  'familia',
};

/// Verbos de presencia/ubicación para la señal familiar.
const Set<String> presenceVerbs = {
  'esta',
  'estas',
  'estan',
  'anda',
  'donde',
  'vino',
  'llego',
  'regreso',
  'encuentra',
};

/// AUTO-02 — routing híbrido determinista (DETERMINISTIC SIGNALS; el
/// STRUCTURED UNDERSTANDING del LLM no añade otra pasada: alimenta la
/// decisión en el engine, no el routing).
///
/// Señales, en orden (el mensaje actual manda — P0-ROUTE):
/// 1. Corrección meta-conversacional ("¿de qué hablas?") → PERSONAL.
/// 2. Menciona al dueño por nombre ("¿está Emmanuel?") → PERSONAL/IDENTIDAD.
/// 3. Rechazo de ayuda ("no quiero que me ayudes") → PERSONAL (social).
/// 4. Queja de pedido ("mi pedido llegó malo") → SUPPORT.
/// 5. Producto explícito (selector REAL de WA-BUSINESS-02, misma fuente que
///    el gating) Y señal comercial (precio/stock/envío) → SALES. Producto
///    SIN señal comercial NO es venta (invariante NO COMMERCIAL = NO SALES).
/// 6. Saludo puro (isPureGreeting de CONTEXT-GATE-01) → PERSONAL SIEMPRE
///    (P0: "hola"/"como estas"/"oe"/"estas ahi"/"todo bien?" son social
///    puro; jamás call-center general). Evidencia del fallo anterior:
///    la rama "saludo puro sin relación registrada" → GENERAL.
/// 7. Referencia/respuesta corta con producto activo en la conversación
///    ("¿y ese todavía está?") → SALES (A05).
/// 8. Social casual corto ("que haces", "jajaja", "bro") → PERSONAL.
/// 9. Reacción social más larga ("me alegra que estes bien", "gracias",
///    "dale") → PERSONAL (P0-SOCIAL-2, sin límite de tokens).
/// 10. Familia del dueño con verbo de presencia ("¿está tu papá?") →
///    PERSONAL (identidad doméstica).
/// 11. Respuesta a la pregunta pendiente de Nano (≤3 tokens): el cliente
///    devuelve el dato pedido ("M", "mañana", "la negra") → jamás GENERAL.
///    Con producto explícito → SALES (la elección pide facts del producto
///    activo); sin producto → PERSONAL con [ConversationAgentRouting.pendingReply].
/// 12. Contacto con relación registrada, sin señal comercial → PERSONAL
///    (A02 "Hola bro qué haces", A04 "gracias bro").
/// 13. Resto → GENERAL.
ConversationAgentRouting routeConversationAgent({
  required String messageText,
  required BusinessFacts facts,
  required bool hasRelationship,
  required bool hasActiveProduct,
  String ownerName = '',
  bool hasPendingQuestion = false,
}) {
  final reasons = <String>[];
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  final signals = contextSignalsFor(messageText, facts);
  // P0-MULTI — intención comercial ORTOGONAL al rol: se calcula UNA vez y
  // viaja en el routing aunque el rol final sea personal (turno mixto).
  final commercialIntent =
      signals.explicitProduct && tokens.any(commercialIntentTokens.contains);

  if (correctionPhrases.any(normalized.contains)) {
    reasons.add('corrección del cliente (meta-conversación)');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
    );
  }

  // P0-ROUTE — identidad: el dueño es mencionado por su nombre. No se mira
  // el catálogo ni la relación: preguntar por Emmanuel es SIEMPRE personal.
  final ownerToken = ownerName.trim().split(' ').first.toLowerCase();
  if (ownerToken.length >= 3 && tokens.contains(ownerToken)) {
    reasons.add('menciona al dueño por nombre (identidad)');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
    );
  }

  // P0-ROUTE — rechazo de ayuda: señal social explícita ("no quiero que me
  // ayudes"). Personal incluso sin relación registrada: el límite manda.
  if (tokens.contains('no') &&
      (tokens.contains('quiero') || tokens.contains('necesito')) &&
      tokens.any((t) => t.startsWith('ayud'))) {
    reasons.add('rechazo de ayuda (social)');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
    );
  }

  if (supportPhrases.any(normalized.contains)) {
    reasons.add('queja o problema de pedido');
    return ConversationAgentRouting(
      role: ConversationAgentRole.support,
      reasons: reasons,
    );
  }

  if (commercialIntent) {
    reasons.add('producto explícito + señal comercial');
    return ConversationAgentRouting(
      role: ConversationAgentRole.sales,
      reasons: reasons,
      commercialIntent: true,
    );
  }
  if (signals.explicitProduct) {
    // P0-ROUTE — producto SIN intención comercial: la entidad existe
    // lingüísticamente pero el turno NO es de venta. Cae a las señales
    // sociales (relación → PERSONAL; sin relación → GENERAL).
    reasons.add(productMentionedWithoutCommerce);
  }
  if (isGreetingLikeMessage(messageText)) {
    // P0 — social puro es PERSONAL SIEMPRE: el turno lo atiende la persona
    // del dueño (MI ESTILO), jamás el fallback general. La relación no
    // decide: un desconocido que saluda también es conversación social.
    reasons.add('saludo puro (social)');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: commercialIntent,
    );
  }
  if (hasActiveProduct && (signals.reference || signals.dependent)) {
    reasons.add('referencia o respuesta corta sobre el producto activo');
    return ConversationAgentRouting(
      role: ConversationAgentRole.sales,
      reasons: reasons,
      commercialIntent: commercialIntent,
    );
  }
  // CONV-STATE-02 — respuesta a la pregunta pendiente de Nano: el dato
  // pedido ("M", "mañana", "la negra") es la continuación del diálogo del
  // propio dueño. Sin esta rama caía a GENERAL (evidencia: el cliente
  // responde la talla y el 1.5B recibe el dato sin la pregunta → inventa).
  // Producto explícito ("la negra") → SALES: la elección se resuelve con
  // los facts del producto activo, no con el bloque de pregunta suelto.
  if (hasPendingQuestion &&
      tokens.isNotEmpty &&
      tokens.length <= 3 &&
      !commercialIntent) {
    if (signals.explicitProduct) {
      reasons.add('elección de producto respondiendo la pregunta pendiente');
      return ConversationAgentRouting(
        role: ConversationAgentRole.sales,
        reasons: reasons,
        commercialIntent: commercialIntent,
      );
    }
    reasons.add('respuesta a la pregunta pendiente de Nano');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: commercialIntent,
      pendingReply: true,
    );
  }
  // P0-SOCIAL — casual corto ("que haces", "jajaja", "bro"): todos los
  // tokens en saludo+casual y ≤3 tokens → conversación social. Va DESPUÉS
  // de comercial/referencia para que "jaja cuánto vale el negro" siga
  // siendo venta.
  final allCasual =
      tokens.isNotEmpty &&
      tokens.length <= 3 &&
      tokens.every(
        (t) => greetingTokens.contains(t) || socialCasualTokens.contains(t),
      );
  if (allCasual) {
    reasons.add('social casual corto');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: commercialIntent,
    );
  }
  // PROD-SOCIAL-05 — risa desordenada ("Jajajsjsjsja"): el teclado real
  // intercala ruido que ningún token exacto cubre (evidencia física
  // 14:23:50: risa con typo cayó a GENERAL). Patrón determinista acotado
  // (sílaba de risa repetida), no NLU: la risa es social puro → PERSONAL
  // (P0-ROUTE-02).
  if (isLooseLaughterMessage(messageText)) {
    reasons.add('risa (patrón desordenado)');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: commercialIntent,
    );
  }
  // P0-SOCIAL-2 — reacción/continuación social ("me alegra que estes
  // bien", "gracias", "dale"): sin señales de negocio (ya salieron), un
  // token de reacción social marca conversación social pura.
  if (tokens.any(socialReactionTokens.contains)) {
    reasons.add('reacción social (continuación)');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: commercialIntent,
    );
  }
  // P0-FAMILY — disponibilidad de la gente del dueño ("¿está tu papá?"):
  // familia + verbo de presencia → identidad doméstica. Antes de la rama de
  // relación para que aplique también a desconocidos.
  final familyMention =
      tokens.any(familyTokens.contains) && tokens.any(presenceVerbs.contains);
  if (familyMention) {
    reasons.add('familia del dueño con verbo de presencia');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: commercialIntent,
    );
  }
  if (hasRelationship) {
    reasons.add('relación registrada sin señal comercial');
    return ConversationAgentRouting(
      role: ConversationAgentRole.personal,
      reasons: reasons,
      commercialIntent: commercialIntent,
    );
  }
  reasons.add('sin señales específicas');
  return ConversationAgentRouting(
    role: ConversationAgentRole.general,
    reasons: reasons,
    commercialIntent: commercialIntent,
  );
}

/// P0-CORRECTION — helper para el writer: un turno de corrección
/// ("¿cuál negro de qué hablas?") entra con el historial LIMPIO igual que
/// el saludo puro: la conversación previa del producto está siendo
/// deshecha por el cliente y solo incita eco del tema viejo.
bool isCorrectionMessage(String messageText) =>
    correctionPhrases.any(normalizeText(messageText).contains);

/// R5-GREETING-01 (2026-09-07) — saludo EXTENDIDO: el saludo puro exacto
/// (isPureGreeting, todos los tokens en greetingTokens) no cubre el saludo
/// real con nombre de contacto: "Hola como estas emma?" falla por 'emma'
/// (evidencia física 16:17:20: cayó a GENERAL con prompt completo, JSON
/// recortado e intent="" → turno retenido y el cliente sin saludo).
///
/// Regla estructural (no frase-keyword): el PRIMER token es de saludo, el
/// mensaje es CORTO (≤4 tokens) y el resto no trae señales de contenido
/// (comercial, queja o corrección). "hola, ¿cuánto vale el negro?" NO es
/// saludo ('cuanto' es señal comercial); "hola como estas emma?" SÍ lo es
/// (el nombre propio no es señal de dominio). Las ramas del router que
/// cambian de dominio (identidad, corrección, soporte, comercial) corren
/// ANTES de la rama de saludo, así que esta función solo afina el límite
/// saludo-vs-general.
bool isGreetingLikeMessage(String messageText) {
  if (isPureGreeting(messageText)) return true;
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty) return false;
  if (tokens.any(commercialIntentTokens.contains)) return false;
  if (supportPhrases.any(normalized.contains)) return false;
  if (correctionPhrases.any(normalized.contains)) return false;
  const explicitGreetingWords = {
    'hola',
    'holas',
    'buenas',
    'buenos',
    'hey',
    'oe',
    'saludos',
    'ola',
  };
  final hasGreeting = tokens.take(3).any(explicitGreetingWords.contains) ||
      greetingTokens.contains(tokens.first);
  if (!hasGreeting) return false;

  // Saludo corto (hasta 4 tokens, ej. "hola emma como estas")
  if (tokens.length <= 4) return true;

  // Si contiene palabras sustantivas/narrativas o turno complejo, NO es solo un saludo;
  // es un turno conversacional que requiere memoria factual completa.
  final complexity = turnComplexityClassifier.classify(messageText);
  if (complexity.isNarrative ||
      complexity.isComplex ||
      complexity.isContextual) {
    return false;
  }

  const substantiveTokens = {
    'programando', 'programa', 'programar', 'codigo', 'app', 'aplicacion',
    'agente', 'agentes', 'trabajando', 'trabajo', 'camellando', 'cansado',
    'cansada', 'cansao', 'cansaod', 'agotado', 'muerto', 'gimnasio', 'gym',
    'entrenando', 'entreno', 'pecho', 'espalda', 'pierna', 'casa', 'calle',
    'estoy', 'ando', 'sali', 'fui', 'tarea', 'ayuda', 'duda', 'pregunta',
  };
  if (tokens.any(substantiveTokens.contains)) return false;

  return true;
}

/// P0-SOCIAL-2 — helper para el writer: reacción/continuación social
/// ("me alegra", "gracias", "dale"). Igual que el saludo puro usa el
/// prompt social mínimo: el prompt completo (JSON + reglas) empuja al
/// 1.5B al default de operador (evidencia viva 19:49:51: "¿Cómo puedo
/// ayudarte hoy?" retenido por el guard) en un turno que el router ya
/// marcó social puro.
bool isSocialReactionMessage(String messageText) =>
    tokenizeText(normalizeText(messageText)).any(socialReactionTokens.contains);

/// R5-04 (2026-09-07) — LIVE STATE: ¿el mensaje pregunta por la actividad
/// o ubicación PRESENTE/FUTURA del dueño? Patrones deterministas acotados
/// (sin NLU): 'que' + verbo de hacer, 'hoy' + verbo, o ubicación ('donde'/
/// 'ahi' + verbo de presencia).
///
/// Evidencia física QUESTION MIRROR 4/4: "y que vas hacer hoy?" → "¿Qué
/// actividades tienes planeadas para hoy?", "que haras hoy" → "¿Qué te
/// gustaría saber?", "hoy iras a rapear?" → "¿Qué día es hoy?". El sistema
/// NO tiene fuente viva del estado del dueño (R5-04 LIVE OWNER STATE SOURCE
/// = NOT FOUND): afirmar qué hace, dónde está o qué hará es inventar. Esta
/// señal activa la regla de honestidad de los prompts y el gate de
/// liveStateRequired en la decisión (R5-05).
bool isLiveStateQuestion(String messageText) {
  final normalized = normalizeText(messageText);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty) return false;
  const activityVerbs = {
    'haces',
    'haciendo',
    'haras',
    'hacer',
    'iras',
    'vas',
    'planeas',
    'saldras',
    'entrenas',
  };
  final hasActivityVerb = tokens.any(activityVerbs.contains);
  if (tokens.contains('que') && hasActivityVerb) return true;
  if (tokens.contains('hoy') && hasActivityVerb) return true;
  if (tokens.any((t) => t == 'donde' || t == 'ahi') &&
      tokens.any(presenceVerbs.contains)) {
    return true;
  }
  // Consultas directas de planes futuros sin necesidad de 'que' o 'hoy'
  if (normalized.contains('vas a') ||
      normalized.contains('iras a') ||
      tokens.contains('planeas') ||
      (tokens.contains('vas') && tokens.contains('ir'))) {
    return true;
  }
  return false;
}

/// PROD-SOCIAL-05 — risa desordenada ("Jajajsjsjsja"): sílaba de risa
/// repetida (ja/je/ji/jo) con ruido intercalado. Misma señal que usa el
/// router para la rama de risa; el writer la usa para la exención de
/// intent en turnos sociales cortos (PROD-SOCIAL-03).
final RegExp _looseLaughter = RegExp(r'(ja){2,}|(je){2,}|(ji){2,}|(jo){2,}');

bool isLooseLaughterMessage(String messageText) =>
    _looseLaughter.hasMatch(normalizeText(messageText));

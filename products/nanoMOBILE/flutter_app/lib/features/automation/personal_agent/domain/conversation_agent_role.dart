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

  const ConversationAgentRouting({
    required this.role,
    required this.reasons,
    this.commercialIntent = false,
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
/// 11. Contacto con relación registrada, sin señal comercial → PERSONAL
///    (A02 "Hola bro qué haces", A04 "gracias bro").
/// 12. Resto → GENERAL.
ConversationAgentRouting routeConversationAgent({
  required String messageText,
  required BusinessFacts facts,
  required bool hasRelationship,
  required bool hasActiveProduct,
  String ownerName = '',
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
  if (isPureGreeting(messageText)) {
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

/// P0-SOCIAL-2 — helper para el writer: reacción/continuación social
/// ("me alegra", "gracias", "dale"). Igual que el saludo puro usa el
/// prompt social mínimo: el prompt completo (JSON + reglas) empuja al
/// 1.5B al default de operador (evidencia viva 19:49:51: "¿Cómo puedo
/// ayudarte hoy?" retenido por el guard) en un turno que el router ya
/// marcó social puro.
bool isSocialReactionMessage(String messageText) =>
    tokenizeText(normalizeText(messageText)).any(socialReactionTokens.contains);

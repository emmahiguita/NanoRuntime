// conversation_agent_tokens.dart
//
// QUÉ HACE:
// Diccionario determinista de tokens y frases clave para clasificar el dominio
// del turno entrante (comercial, soporte, identidad, familiar y social).
//
// CÓMO FUNCIONA:
// - Define conjuntos de palabras normalizadas (sin tildes) optimizados para O(1) lookup.
// - Discierne intención comercial real (precio, stock, envío, comprar) para no confundir
//   menciones coloquiales con consultas de compra reales.
//
// POR QUÉ:
// En modelos de lenguaje compactos locales (0.5B / 1.5B), el enrutamiento semántico debe ser
// 100% determinista, ultra veloz (< 1ms) y libre de alucinaciones.

library;

/// Señales explícitas de intención comercial (producto, servicio, compra o cotización).
const Set<String> commercialIntentTokens = {
  'cuanto', 'cuantos', 'cuantas', 'vale', 'valen', 'precio', 'precios',
  'coste', 'cuesta', 'stock', 'disponible', 'disponibles', 'disponibilidad',
  'producto', 'productos', 'talla', 'tallas', 'envio', 'envios', 'entrega',
  'pedido', 'pedidos', 'comprar', 'compro', 'reservar', 'apartar', 'referencia',
  'referencias', 'catalogo', 'catalogos', 'servicio', 'servicios', 'cotizar',
  'cotizacion', 'contratar', 'agendar', 'asesor', 'adquirir', 'promocion',
  'promociones', 'oferta', 'ofertas', 'despacho', 'despachos', 'domicilio',
  'domicilios', 'venden', 'vendes',
};

/// Traza cuando se nombra un producto pero sin intención de compra concreta.
const String productMentionedWithoutCommerce =
    'producto mencionado sin señal comercial (no es venta)';

/// Frases de corrección meta-conversacional ("no me refería a eso").
const List<String> correctionPhrases = [
  'de que hablas', 'no me refiero', 'no me referia', 'no me refería',
  'me referia a', 'me refería a', 'no pregunte eso', 'no es eso', 'no te pedi',
];

/// Frases de queja o reclamo post-venta (dominio Soporte).
const List<String> supportPhrases = [
  'llego mal', 'llegado mal', 'mal llego', 'no llego', 'no me llego',
  'danado', 'dano', 'problema', 'reclamo', 'devolver', 'reembolso',
  'queja', 'malo', 'mala',
];

/// Tokens sociales casuales y coloquiales de longitud corta.
const Set<String> socialCasualTokens = {
  'haces', 'haciendo', 'jajaja', 'jajaj', 'jaja', 'jeje', 'jajajaja',
  'bro', 'parce', 'parcero', 'mano', 'amigo', 'amiga', 'socio',
  'cuentame', 'contame',
};

/// Reacciones sociales de continuación o agradecimiento.
const Set<String> socialReactionTokens = {
  'alegra', 'alegro', 'alegras', 'alegre', 'alegran', 'bien', 'bueno',
  'buena', 'genial', 'excelente', 'perfecto', 'perfecta', 'gracias',
  'dale', 'listo', 'vale', 'claro', 'obvio', 'chevere', 'bacano',
  'tranqui', 'feliz', 'contento', 'contenta', 'encanta', 'gusto',
  'ok', 'okay', 'entendido', 'haces', 'haciendo', 'jajaja', 'jajaj',
  'jaja', 'jeje', 'jajajaja', 'bro', 'parce', 'parcero', 'mano',
  'amigo', 'amiga', 'socio', 'cuentame', 'contame',
};

/// Miembros del núcleo familiar para preguntas de identidad doméstica.
const Set<String> familyTokens = {
  'papa', 'mama', 'mami', 'papi', 'tio', 'tia', 'hermano', 'hermana',
  'hijo', 'hija', 'esposa', 'esposo', 'marido', 'novia', 'novio',
  'jefe', 'familia',
};

/// Verbos de presencia o ubicación física.
const Set<String> presenceVerbs = {
  'esta', 'estas', 'estan', 'anda', 'donde', 'vino', 'llego',
  'regreso', 'encuentra',
};

/// QUÉ HACE:
/// Controla el filtrado, formateo y compuertas de relevancia contextual (gating)
/// para decidir si la memoria previa debe inyectarse o no al prompt del modelo.
///
/// CÓMO FUNCIONA:
/// Analiza tokens de saludo, respuestas dependientes y referencias anafóricas.
/// Solo inyecta el recuerdo del producto o la pregunta pendiente cuando el mensaje
/// actual realmente lo necesita, evitando contaminar saludos puros o temas nuevos.
///
/// POR QUÉ:
/// "Memoria disponible != Memoria relevante". Si se inyecta contexto en saludos
/// como "Hola", modelos pequeños como 1.5B cometen eco indebido del último producto.
library;

import '../business/business_facts.dart';
import '../business/fact_selector.dart';
import 'conv_turn_state_models.dart';

/// Tokens de saludo puro: si todos los tokens del mensaje pertenecen a este set,
/// es un saludo y jamás reactiva contexto comercial.
const Set<String> greetingTokens = {
  'hola', 'holas', 'buenas', 'buenos', 'dias', 'tardes', 'noches',
  'buen', 'dia', 'tarde', 'noche', 'hey', 'saludos', 'que', 'tal',
  'mas', 'como', 'estas', 'esta', 'todo', 'bien', 'vos', 'tu', 'ola',
  'oe', 'ahi', 'y', 'ti', 'usted', 'parce', 'emma', 'emm',
};

/// ¿Es un saludo puro? Determinista: cada token pertenece a [greetingTokens].
bool isPureGreeting(String messageText) {
  final tokens = tokenizeText(normalizeText(messageText));
  if (tokens.isEmpty) return false;
  return tokens.every(greetingTokens.contains);
}

/// Tokens de respuesta corta dependiente ("sí", "dale", "cuánto").
const Set<String> dependentReplyTokens = {
  'si', 'no', 'dale', 'listo', 'ok', 'okay', 'perfecto', 'cuanto',
  'cuantos', 'cuantas', 'cual', 'cuales', 'cuando', 'manana', 'hoy',
};

/// Tokens de referencia explícita a lo conversado antes ("ese", "el anterior").
const Set<String> referenceTokens = {
  'ese', 'esa', 'esos', 'esas', 'aquel', 'aquella', 'aquellos', 'aquellas',
  'anterior', 'mismo', 'misma', 'dije', 'pregunte', 'pregunto', 'dicho', 'contaste',
};

/// Tokens de consulta de precio directa.
const Set<String> priceQuestionTokens = {
  'cuanto', 'cuantos', 'cuantas', 'precio', 'precios', 'coste', 'cuesta',
};

/// Extrae las señales deterministas de gating para el mensaje actual.
({bool reference, bool dependent, bool explicitProduct}) contextSignalsFor(
  String messageText,
  BusinessFacts facts,
) {
  final tokens = tokenizeText(normalizeText(messageText));
  return (
    reference: tokens.any(referenceTokens.contains),
    dependent:
        tokens.isNotEmpty &&
        tokens.length <= 2 &&
        tokens.every(dependentReplyTokens.contains),
    explicitProduct: selectFactsForMessage(
      messageText,
      facts,
    ).products.isNotEmpty,
  );
}

/// Construye el bloque de memoria de producto anterior formateado para el prompt.
String formatClientContextBlock(ClientContextEntry? entry) {
  final product = entry?.product;
  if (product == null) return '';
  final days = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(entry!.atMs))
      .inDays;
  final when = days <= 0
      ? 'hoy'
      : days == 1
      ? 'ayer'
      : 'hace $days días';
  return '''
<CONTEXTO DEL CLIENTE>
Consulta anterior de ESTE cliente: ${product.label} por ${product.priceLabel}
($when). Usa este recuerdo para resolver referencias como "el que te
pregunté", "ese teléfono", "la negra". Si el cliente pide algo distinto o el
recuerdo no aplica, ignóralo por completo.
</CONTEXTO DEL CLIENTE>''';
}

/// Construye el bloque de pregunta pendiente para que respuestas breves resuelvan.
String formatPendingQuestionBlock(ClientContextEntry entry) {
  final pending = entry.pendingQuestion.trim();
  if (pending.isEmpty) return '';
  final kindHint = switch (entry.pendingKind) {
    'confirm' =>
      ' Es una pregunta de confirmación: espera un sí/no/dale corto, '
          'no una frase completa.',
    'value' =>
      ' Es una pregunta de dato: espera una respuesta corta (talla, '
          'número, cantidad, fecha), no una frase completa.',
    _ => '',
  };
  return '''
<PREGUNTA PENDIENTE>
Nano preguntó antes: "$pending". El mensaje actual del cliente probablemente
la responde ("sí", "no", "M", "mañana" = respuesta a ESTA pregunta, no una
consulta nueva).$kindHint Responde a partir de ella. Si el mensaje no encaja
con la pregunta, ignórala por completo.
</PREGUNTA PENDIENTE>''';
}

/// Decide deterministamente qué bloque de contexto debe viajar al turno actual.
String clientContextBlockForTurn({
  required ClientContextEntry? entry,
  required String messageText,
  required BusinessFacts facts,
}) {
  if (entry?.product == null && (entry?.pendingQuestion ?? '').isEmpty) {
    return '';
  }
  final signals = contextSignalsFor(messageText, facts);
  if (signals.reference) return formatClientContextBlock(entry);
  if (signals.explicitProduct) return '';
  final tokens = tokenizeText(normalizeText(messageText));
  if (tokens.isNotEmpty && tokens.any(priceQuestionTokens.contains)) {
    return formatClientContextBlock(entry);
  }
  if ((entry?.pendingQuestion ?? '').isNotEmpty &&
      tokens.isNotEmpty &&
      tokens.length <= 3) {
    return formatPendingQuestionBlock(entry!);
  }
  if (signals.dependent &&
      entry?.topicStatus != 'resolved' &&
      entry?.product != null) {
    return formatClientContextBlock(entry);
  }
  return '';
}

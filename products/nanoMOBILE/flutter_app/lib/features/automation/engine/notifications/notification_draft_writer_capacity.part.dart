part of 'notification_draft_writer.dart';

// QUÉ: reduce instrucciones redundantes, no el historial ni el mensaje actual.
// CÓMO: MNN se identifica por catálogo; LiteRT por el paquete KV auditado.
// POR QUÉ: MNN CPU tardó 44.8 s en prefill y repite ese costo al regenerar.
// No comparte caché entre chats ni presupone que todos los Qwen sean iguales.
bool _needsCompactPersonalSystem(String? path) =>
    NeuralCatalog.backendForPath(path) == ModelBackendType.mnn ||
    path?.replaceAll('\\', '/').split('/').last ==
        'qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm';

// QUÉ: incluye estilo habilitado sin aumentar los 280 caracteres de KV mínimo.
// CÓMO: reserva espacio para la forma de hablar y limita el resto por palabra.
// POR QUÉ: el estilo antes se leía pero no llegaba al modelo local habitual.
// Un corte por palabra no garantiza conservar una frase completa; estos datos
// siguen subordinados a la política factual, sin recortar mensaje ni historial.
const int _tinyKvPersonaChars = 280;
String _personaForCapacity(String path, String persona, {String? style}) {
  // Solo el paquete ekv1280; MNN (KV 2048) conserva la persona completa.
  final isTinyKv =
      path.replaceAll('\\', '/').split('/').last ==
      'qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm';
  final cleanStyle = style?.trim() ?? '';
  final styleBlock = cleanStyle.isEmpty
      ? ''
      : 'Estilo (solo forma): ${_boundedPersonaText(cleanStyle, isTinyKv ? 100 : 280)}';
  final budget = isTinyKv ? _tinyKvPersonaChars : persona.length;
  final factsBudget = isTinyKv ? budget - styleBlock.length - 1 : budget;
  return [
    if (persona.trim().isNotEmpty) _boundedPersonaText(persona, factsBudget),
    if (styleBlock.isNotEmpty) styleBlock,
  ].join('\n');
}

/// Recorte auxiliar exclusivo del perfil/estilo; no toca la petición recibida.
String _boundedPersonaText(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  final cut = text.substring(0, maxChars);
  final lastSpace = cut.lastIndexOf(' ');
  return cut.substring(0, lastSpace > 0 ? lastSpace : maxChars).trimRight();
}

// No contiene respuestas modelo ni ejemplos a copiar; conserva las barreras.
String _capacityPersonalSystem({required bool structured}) => [
  PersonalPromptPolicy.base,
  if (structured)
    'Devuelve JSON: {"reply":"","intent":"","relation":"",'
        '"missingFacts":[],"requiresAction":false}. Si falta un dato o '
        'hace falta actuar, requiresAction=true y explica qué falta en missingFacts.'
  else
    PersonalPromptPolicy.plainOutput,
].join('\n');


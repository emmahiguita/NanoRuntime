/// Normalización compartida para comparar preguntas y saludos sin crear una
/// intención distinta por cada URL recibida.
library;

import '../../engine/business/fact_selector.dart' show normalizeText;

final _linkPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);

/// Acepta solo una entrada conversacional con contenido humano verificable y señal reusable.
/// Los enlaces aislados, eventos de estados, códigos numéricos o párrafos únicos extensos
/// no enseñan una intención reusable.
bool isLearnablePersonalPrompt(String raw) {
  final clean = raw.trim();
  if (clean.isEmpty || clean.length > 280) return false;
  final withoutLinks = clean.replaceAll(_linkPattern, ' ');
  final words = normalizePersonalLearningText(withoutLinks);
  if (words.isEmpty) return false;
  // Descartar cadenas puramente numéricas, códigos o una sola letra sin valor semántico
  if (RegExp(r'^[0-9\s]+$').hasMatch(words)) return false;
  if (words.length < 2) return false;

  final normalized = normalizeText(clean);
  final spanishStatusReaction =
      normalized.contains('tu estado') &&
      (normalized.contains('reacciono') || normalized.contains('gusta'));
  return !normalized.contains('status@broadcast') &&
      !spanishStatusReaction &&
      !normalized.contains('liked your status') &&
      !normalized.contains('reacted to your status');
}

/// Normalización canónica que colapsa puntuación, signos, mayúsculas y elongaciones
/// coloquiales ("hola", "Hola", "hola!", "¡Hola!", "holaa", "holaaa" → "hola").
String normalizePersonalLearningText(String raw) {
  final semanticText = raw.replaceAll(_linkPattern, ' enlace ');
  final base = normalizeText(semanticText)
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (base.isEmpty) return '';
  return base.split(' ').map(_canonicalizeToken).where((t) => t.isNotEmpty).join(' ');
}

String _canonicalizeToken(String token) {
  if (token.isEmpty) return '';
  // Normalizar risas coloquiales ("jajaja", "jajajaja", "jejeje") a una forma canónica
  if (RegExp(r'^(?:ja){2,}j?$').hasMatch(token)) return 'jaja';
  if (RegExp(r'^(?:je){2,}j?$').hasMatch(token)) return 'jeje';
  // Colapsar vocales repetidas ("holaa" → "hola", "buenaaas" → "buenas", "siii" → "si")
  var out = token.replaceAllMapped(RegExp(r'([aeiou])\1+'), (m) => m.group(1)!);
  // Colapsar consonantes triplicadas ("okkk" → "ok", "bueeennno" → "bueno")
  out = out.replaceAllMapped(RegExp(r'([b-df-hj-np-tv-z])\1{2,}'), (m) => m.group(1)!);
  // Colapsar consonantes dobles al final de palabra ("holisss"/"okisss"/"biennn" → "bien")
  if (token == 'app' || out == 'ap') return 'app';
  if (out == 'holi' || out == 'holis' || out == 'holas' || out == 'ola') {
    return 'hola';
  }
  return out;
}

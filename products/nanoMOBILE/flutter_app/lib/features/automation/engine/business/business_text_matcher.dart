// business_text_matcher.dart
//
// QUÉ HACE: centraliza la normalización y los tokens útiles de negocio.
// CÓMO: elimina diacríticos, tokeniza y descarta conectores genéricos.
// POR QUÉ: todos los analizadores deben comparar texto con la misma regla.

const Set<String> _nonSpecificProductTokens = {
  'con',
  'para',
  'por',
  'que',
  'como',
  'este',
  'esta',
  'esto',
  'tiene',
  'tienen',
  'quiero',
  'necesito',
  'saber',
  'hola',
  'gracias',
  'producto',
  'productos',
  'servicio',
  'servicios',
  'precio',
  'precios',
};

/// Evita que una palabra genérica identifique por error un producto.
bool isSpecificBusinessToken(String token) =>
    token.length >= 3 && !_nonSpecificProductTokens.contains(token);

/// Normaliza texto removiendo acentos para comparaciones uniformes.
String normalizeText(String raw) {
  const withAccents = 'áéíóúñüÁÉÍÓÚÑÜ';
  const without = 'aeiounuAEIOUNU';
  final buffer = StringBuffer();
  for (final ch in raw.split('')) {
    final index = withAccents.indexOf(ch);
    buffer.write(index >= 0 ? without[index] : ch);
  }
  return buffer.toString().toLowerCase();
}

/// Extrae tokens alfanuméricos únicos, incluso desde párrafos largos.
Set<String> tokenizeText(String normalized) => RegExp(
  r'[a-z0-9]+',
).allMatches(normalized).map((match) => match.group(0)!).toSet();

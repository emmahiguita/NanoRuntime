// business_product_matcher.dart
//
// QUÉ HACE: relaciona un mensaje con productos realmente configurados.
// CÓMO: compara nombre, detalles, SKU, categoría y variantes con tokens útiles.
// POR QUÉ: evita seleccionar artículos por conectores comunes o texto incidental.

import 'business_facts.dart';
import 'business_text_matcher.dart';

/// Devuelve verdadero solo si existe evidencia textual discriminante.
bool matchesBusinessProduct(
  String normalized,
  Set<String> tokens,
  BusinessProduct product,
) {
  final nameTokens = tokenizeText(
    normalizeText(product.name),
  ).where(isSpecificBusinessToken).toSet();
  if (nameTokens.isNotEmpty && nameTokens.every(tokens.contains)) return true;

  for (final token in tokens) {
    if (isSpecificBusinessToken(token) && nameTokens.contains(token)) {
      return true;
    }
  }

  if (_matchesDescriptiveField(tokens, product.details)) return true;

  final sku = product.sku?.trim() ?? '';
  if (sku.isNotEmpty) {
    final normalizedSku = normalizeText(sku);
    if (normalized.contains(normalizedSku) || tokens.contains(normalizedSku)) {
      return true;
    }
  }

  if (_matchesDescriptiveField(tokens, product.category ?? '')) return true;

  for (final variant in product.variants) {
    final normalizedVariant = normalizeText(variant);
    if (normalizedVariant.length >= 2 &&
        normalized.contains(normalizedVariant)) {
      return true;
    }
  }
  return false;
}

bool _matchesDescriptiveField(Set<String> tokens, String value) {
  if (value.trim().isEmpty) return false;
  final fieldTokens = tokenizeText(normalizeText(value));
  for (final token in tokens) {
    if (token.length >= 4 &&
        isSpecificBusinessToken(token) &&
        fieldTokens.contains(token)) {
      return true;
    }
  }
  return false;
}

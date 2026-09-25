// fact_selector.dart
//
// QUÉ HACE:
// Selector determinista de hechos comerciales relevantes para el mensaje entrante.
// Filtra el catálogo de productos, horarios, cobertura de envíos, métodos de pago y ubicación.
//
// CÓMO FUNCIONA:
// 1. Normaliza y tokeniza el mensaje recibido.
// 2. Busca coincidencias semánticas y de variantes sobre el catálogo de productos.
// 3. PRIORIZA productos específicos: si se menciona un producto concreto ("Samsung negro"),
//    únicamente se inyecta dicho producto, anulando el volcado masivo del catálogo.
// 4. Si no hay productos específicos y el usuario pide catálogo ("¿qué tienen?"), vuelca las opciones.
// 5. Asocia información de despacho, horarios, pagos y ubicación según las preguntas del turno.
//
// POR QUÉ:
// En modelos locales (0.5B/1.5B) con ventana de contexto limitada, volcar el catálogo completo ante
// palabras generales como "tienen" o "precio" desborda el contexto e induce alucinaciones.

library;

import 'business_facts.dart';
import 'business_fact_signals.dart';
import 'business_text_matcher.dart';

export 'business_text_matcher.dart'
    show isSpecificBusinessToken, normalizeText, tokenizeText;

/// Contenedor de hechos comerciales autorizados para el turno.
final class FactSelection {
  final String businessName;
  final List<BusinessProduct> products;
  final String hours;
  final String delivery;
  final String payments;
  final String location;

  const FactSelection({
    this.businessName = '',
    this.products = const [],
    this.hours = '',
    this.delivery = '',
    this.payments = '',
    this.location = '',
  });

  bool get isEmpty =>
      businessName.isEmpty &&
      products.isEmpty &&
      hours.isEmpty &&
      delivery.isEmpty &&
      payments.isEmpty &&
      location.isEmpty;

  bool get isNotEmpty => !isEmpty;

  String render() => buildBusinessBlock(
    businessName: businessName,
    products: products,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
  );
}

/// Selecciona los hechos precisos que deben entrar al prompt del modelo.
FactSelection selectFactsForMessage(String message, BusinessFacts facts) {
  final normalized = normalizeText(message);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty || facts.isEmpty) return const FactSelection();
  final signals = detectBusinessFactSignals(normalized, tokens);

  // 1. Detección de productos específicos primero
  final specificMatches = [
    for (final p in facts.products)
      if (_productMatches(tokens, p)) p,
  ];

  // 2. Si hay productos específicos que calzan, aislarlos para no saturar con el catálogo entero
  List<BusinessProduct> selectedProducts;
  if (specificMatches.isNotEmpty) {
    selectedProducts = specificMatches;
  } else if (signals.wantsList) {
    // Solo cuando no hay producto específico y la intención es ver opciones generales
    selectedProducts = facts.products;
  } else {
    selectedProducts = const [];
  }

  final hours = signals.wantsHours ? facts.hours.trim() : '';
  final delivery = (signals.wantsDelivery || selectedProducts.isNotEmpty)
      ? facts.delivery.trim()
      : '';
  final payments = signals.wantsPayments ? facts.payments.trim() : '';
  final location = signals.wantsLocation ? facts.location.trim() : '';

  return FactSelection(
    businessName: facts.businessName.trim(),
    products: selectedProducts,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
  );
}

/// Verifica si los tokens del mensaje hacen match con el nombre, categoría, SKU o variante/detalles del producto.
bool _productMatches(Set<String> messageTokens, BusinessProduct product) {
  final nameTokens = tokenizeText(normalizeText(product.name));
  final detailTokens = tokenizeText(normalizeText(product.details));
  final categoryTokens = product.category != null
      ? tokenizeText(normalizeText(product.category!))
      : const <String>{};
  final skuTokens = product.sku != null
      ? tokenizeText(normalizeText(product.sku!))
      : const <String>{};
  final variantTokens = {
    for (final v in product.variants) ...tokenizeText(normalizeText(v)),
  };

  for (final token in messageTokens) {
    if (!isSpecificBusinessToken(token)) continue;
    if (nameTokens.contains(token) ||
        detailTokens.contains(token) ||
        categoryTokens.contains(token) ||
        skuTokens.contains(token) ||
        variantTokens.contains(token)) {
      return true;
    }
  }
  return false;
}

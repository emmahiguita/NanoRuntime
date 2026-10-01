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
import 'business_intent_patterns.dart';
import 'business_product_matcher.dart';
import 'business_profile.dart';
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
  final BusinessProfile profile;

  const FactSelection({
    this.businessName = '',
    this.products = const [],
    this.hours = '',
    this.delivery = '',
    this.payments = '',
    this.location = '',
    this.profile = const BusinessProfile(),
  });

  // QUÉ HACE: indica si la consulta encontró un dato comercial que pueda responderla.
  // CÓMO FUNCIONA: el nombre y perfil globales siguen en render(), pero no cuentan como coincidencia.
  // POR QUÉ: evita enrutar mensajes personales a ventas solo porque el negocio esté configurado.
  bool get isEmpty =>
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
    profile: profile,
  );
}

/// Selecciona los hechos precisos que deben entrar al prompt del modelo.
FactSelection selectFactsForMessage(String message, BusinessFacts facts) {
  final normalized = normalizeText(message);
  final tokens = tokenizeText(normalized);
  if (tokens.isEmpty || facts.isEmpty) return const FactSelection();
  // Usa el mismo vocabulario que el resolutor para evitar clasificaciones divergentes.
  final signals = detectBusinessIntentSignals(normalized, tokens);

  // 1. Detección de productos específicos primero
  final specificMatches = [
    for (final p in facts.products)
      if (p.isAvailable && matchesBusinessProduct(normalized, tokens, p)) p,
  ];

  // 2. Si hay productos específicos que calzan, aislarlos para no saturar con el catálogo entero
  List<BusinessProduct> selectedProducts;
  if (specificMatches.isNotEmpty) {
    selectedProducts = specificMatches;
  } else if (signals.isCatalogAsk) {
    // Solo cuando no hay producto específico y la intención es ver opciones generales
    selectedProducts = facts.products.where((p) => p.isAvailable).toList();
  } else {
    selectedProducts = const [];
  }

  final hours = signals.isHoursAsk ? facts.hours.trim() : '';
  final delivery = (signals.isDeliveryAsk || selectedProducts.isNotEmpty)
      ? facts.delivery.trim()
      : '';
  final payments = signals.isPaymentAsk ? facts.payments.trim() : '';
  final location = signals.isLocationAsk ? facts.location.trim() : '';

  return FactSelection(
    businessName: facts.businessName.trim(),
    products: selectedProducts,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
    profile: facts.profile,
  );
}

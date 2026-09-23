// business_conversation_models.dart
//
// QUÉ HACE:
// Define los modelos de datos y resultados para la comprensión y resolución conversacional comercial.
//
// CÓMO FUNCIONA:
// - Encapsula los tópicos comerciales detectados en el turno (saludo, catálogo, envíos, pagos, horarios, ubicación, asesor humano).
// - Provee la estructura [BusinessTurnReply] con la respuesta principal redactada y 3 opciones interactivas de respuesta rápida.
//
// POR QUÉ:
// Aplica SOLID (SRP) desacoplando la estructura de datos del algoritmo de redacción para cumplir el estándar < 200 líneas.

import '../business/business_facts.dart';

/// Análisis estructurado de las intenciones comerciales presentes en el mensaje del cliente.
final class BusinessMessageAnalysis {
  final bool isGreeting;
  final bool isHumanRequest;
  final bool isCatalogAsk;
  final bool isDeliveryAsk;
  final bool isPaymentAsk;
  final bool isHoursAsk;
  final bool isLocationAsk;
  final List<BusinessProduct> matchedProducts;
  final int totalIntentsCount;

  const BusinessMessageAnalysis({
    required this.isGreeting,
    required this.isHumanRequest,
    required this.isCatalogAsk,
    required this.isDeliveryAsk,
    required this.isPaymentAsk,
    required this.isHoursAsk,
    required this.isLocationAsk,
    required this.matchedProducts,
    required this.totalIntentsCount,
  });

  bool get hasCommercialIntent =>
      isGreeting ||
      isHumanRequest ||
      isCatalogAsk ||
      isDeliveryAsk ||
      isPaymentAsk ||
      isHoursAsk ||
      isLocationAsk ||
      matchedProducts.isNotEmpty;

  bool get isMultiIntent => totalIntentsCount > 1;
}

/// Respuesta comercial completa: texto articulado + 3 opciones sugeridas.
final class BusinessTurnReply {
  final String text;
  final List<String> suggestions;
  final bool isDirectResolution;

  const BusinessTurnReply({
    required this.text,
    required this.suggestions,
    this.isDirectResolution = true,
  });
}

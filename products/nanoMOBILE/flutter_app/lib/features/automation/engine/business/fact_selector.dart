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

const List<String> _listAskTokens = [
  'catalogo', 'modelos', 'opciones', 'disponibles', 'producto', 'productos',
  'tienes', 'tienen', 'vendes', 'ofrece', 'ofrecen', 'manejas', 'manejan',
  'dispone', 'hay', 'cual', 'precio', 'precios', 'valor', 'valores',
  'cuesta', 'cuestan', 'sale', 'salen',
];

const List<String> _hoursAskTokens = [
  'horario', 'abren', 'abre', 'abiertos', 'abierto', 'cierran', 'cierra',
  'atienden', 'atiende', 'atencion', 'jornada', 'horas',
];

const List<String> _deliveryAskTokens = [
  'envio', 'envios', 'envian', 'domi', 'domicilio', 'domicilios', 'despacho',
  'entrega', 'entregas', 'entregan', 'llevan', 'mandan', 'mandar', 'cobertura',
  'flete', 'ruta', 'traen',
];

const List<String> _paymentsAskTokens = [
  'pago', 'pagos', 'pagar', 'cuenta', 'cuentas', 'transferir', 'transferencia',
  'nequi', 'daviplata', 'bancolombia', 'tarjeta', 'efectivo', 'contraentrega',
  'metodo', 'metodos', 'medio', 'medios',
];

const List<String> _locationAskTokens = [
  'donde', 'ubicados', 'ubicacion', 'direccion', 'tienda', 'local', 'sede',
  'quedan', 'queda', 'llegar', 'recoger', 'recogida', 'ciudad', 'punto',
];

/// Contenedor de hechos comerciales autorizados para el turno.
final class FactSelection {
  final List<BusinessProduct> products;
  final String hours;
  final String delivery;
  final String payments;
  final String location;

  const FactSelection({
    this.products = const [],
    this.hours = '',
    this.delivery = '',
    this.payments = '',
    this.location = '',
  });

  bool get isEmpty =>
      products.isEmpty &&
      hours.isEmpty &&
      delivery.isEmpty &&
      payments.isEmpty &&
      location.isEmpty;

  bool get isNotEmpty => !isEmpty;

  String render() => buildBusinessBlock(
    products: products,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
  );
}

/// Selecciona los hechos precisos que deben entrar al prompt del modelo.
FactSelection selectFactsForMessage(String message, BusinessFacts facts) {
  final tokens = tokenizeText(normalizeText(message));
  if (tokens.isEmpty || facts.isEmpty) return const FactSelection();

  final wantsHours = tokens.any(_hoursAskTokens.contains);
  final wantsDelivery = tokens.any(_deliveryAskTokens.contains);
  final wantsPayments = tokens.any(_paymentsAskTokens.contains);
  final wantsLocation = tokens.any(_locationAskTokens.contains);
  final wantsList = tokens.any(_listAskTokens.contains);

  // 1. Detección de productos específicos primero
  final specificMatches = [
    for (final p in facts.products)
      if (_productMatches(tokens, p)) p,
  ];

  // 2. Si hay productos específicos que calzan, aislarlos para no saturar con el catálogo entero
  List<BusinessProduct> selectedProducts;
  if (specificMatches.isNotEmpty) {
    selectedProducts = specificMatches;
  } else if (wantsList) {
    // Solo cuando no hay producto específico y la intención es ver opciones generales
    selectedProducts = facts.products;
  } else {
    selectedProducts = const [];
  }

  final hours = wantsHours ? facts.hours.trim() : '';
  final delivery = (wantsDelivery || selectedProducts.isNotEmpty)
      ? facts.delivery.trim()
      : '';
  final payments = wantsPayments ? facts.payments.trim() : '';
  final location = wantsLocation ? facts.location.trim() : '';

  return FactSelection(
    products: selectedProducts,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
  );
}

/// Verifica si los tokens del mensaje hacen match con el nombre o variante/detalles del producto.
bool _productMatches(Set<String> messageTokens, BusinessProduct product) {
  final nameTokens = tokenizeText(normalizeText(product.name));
  final detailTokens = tokenizeText(normalizeText(product.details));
  for (final token in messageTokens) {
    if (token.length < 3) continue; // Descarta conectores como "el", "de", "en"
    if (nameTokens.contains(token) || detailTokens.contains(token)) {
      return true;
    }
  }
  return false;
}

/// Normaliza texto removiendo acentos diacríticos para comparación uniforme.
String normalizeText(String raw) {
  const withAccents = 'áéíóúñüÁÉÍÓÚÑÜ';
  const without = 'aeiounuAEIOUNU';
  final buffer = StringBuffer();
  for (final ch in raw.split('')) {
    final i = withAccents.indexOf(ch);
    buffer.write(i >= 0 ? without[i] : ch);
  }
  return buffer.toString().toLowerCase();
}

/// Extrae tokens alfanuméricos únicos.
Set<String> tokenizeText(String normalized) =>
    RegExp(r'[a-z0-9]+').allMatches(normalized).map((m) => m.group(0)!).toSet();

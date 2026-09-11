/// WA-BUSINESS-02 — selector determinista de hechos relevantes.
///
/// Lógica real sin LLM extra (una pasada, WA-CONVERSATION-01): el mensaje
/// entrante decide QUÉ parte del catálogo entra al bloque <DATOS DEL
/// NEGOCIO>. Un catálogo grande no se mete entero al prompt (tokens + el
/// modelo se confunde entre productos parecidos); solo viajan los productos
/// mencionados (por nombre O variante/color) y horario/envío cuando aplican.
///
/// Puro y sin estado: recibe texto + hechos, devuelve la selección. El
/// producto referido por contexto ("¿y el negro?") matchea por la variante
/// ("negro") aunque el nombre no aparezca: las variantes son tokens de
/// match, no decoración.
library;

import 'business_facts.dart';

const List<String> _listAskTokens = [
  'catálogo', 'catalogo', 'modelos', 'opciones', 'disponibles',
  'tienes', 'vendes', 'manejas', 'hay', 'cuál', 'cual',
];

const List<String> _hoursAskTokens = [
  'horario', 'abren', 'abre', 'abiertos', 'abierto', 'cierran', 'cierra',
  'atienden', 'atiende', 'atención', 'atencion',
];

const List<String> _deliveryAskTokens = [
  'envío', 'envio', 'domicilio', 'despacho', 'llevan', 'mandan',
];

const List<String> _paymentsAskTokens = [
  'pago', 'pagos', 'pagar', 'cuenta', 'cuentas', 'transferir', 'transferencia',
  'nequi', 'daviplata', 'bancolombia', 'tarjeta', 'efectivo', 'contraentrega',
  'metodo', 'metodos', 'cobro', 'cobran', 'medio', 'medios',
];

const List<String> _locationAskTokens = [
  'donde', 'ubicados', 'ubicacion', 'dirección', 'direccion', 'tienda', 'local',
  'sede', 'quedan', 'queda', 'llegar', 'recoger', 'recogida', 'ciudad',
];

/// Qué entra al bloque autorizado del prompt.
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

  String render() => buildBusinessBlock(
    products: products,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
  );
}

/// Selecciona hechos relevantes para [message] contra [facts].
FactSelection selectFactsForMessage(String message, BusinessFacts facts) {
  final tokens = tokenizeText(normalizeText(message));
  if (tokens.isEmpty || facts.isEmpty) return const FactSelection();

  final wantsList = tokens.any(_listAskTokens.contains);
  final wantsHours = tokens.any(_hoursAskTokens.contains);
  final wantsDelivery = tokens.any(_deliveryAskTokens.contains);
  final wantsPayments = tokens.any(_paymentsAskTokens.contains);
  final wantsLocation = tokens.any(_locationAskTokens.contains);

  List<BusinessProduct> products;
  if (wantsList) {
    // "¿qué teléfonos tienes?": no hay producto mencionado → catálogo
    // completo (el agente lo resume con verdad).
    products = facts.products;
  } else {
    products = [
      for (final p in facts.products)
        if (_productMatches(tokens, p)) p,
    ];
  }

  final hours = wantsHours ? facts.hours.trim() : '';
  final delivery = (wantsDelivery || products.isNotEmpty)
      ? facts.delivery.trim()
      : '';
  final payments = wantsPayments ? facts.payments.trim() : '';
  final location = wantsLocation ? facts.location.trim() : '';
  return FactSelection(
    products: products,
    hours: hours,
    delivery: delivery,
    payments: payments,
    location: location,
  );
}

bool _productMatches(Set<String> messageTokens, BusinessProduct product) {
  final nameTokens = tokenizeText(normalizeText(product.name));
  final detailTokens = tokenizeText(normalizeText(product.details));
  for (final token in messageTokens) {
    if (token.length < 3) continue; // "el", "de" nunca matchean solos
    if (nameTokens.contains(token) || detailTokens.contains(token)) {
      return true;
    }
  }
  return false;
}

/// Normaliza texto para matching determinista (minúsculas, sin tildes).
/// Pública desde CONTEXT-GATE-01: el gating de relevancia del turno
/// (conv_turn_state) reusa la MISMA normalización — una sola fuente.
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

Set<String> tokenizeText(String normalized) =>
    RegExp(r'[a-z0-9]+').allMatches(normalized).map((m) => m.group(0)!).toSet();

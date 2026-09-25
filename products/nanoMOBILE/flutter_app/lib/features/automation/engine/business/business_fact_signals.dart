// business_fact_signals.dart
//
// QUÉ HACE: detecta qué datos reales solicita el cliente.
// CÓMO: combina tokens exactos y frases normalizadas por cada categoría.
// POR QUÉ: limita los hechos enviados al modelo y reduce respuestas incoherentes.

const _listTokens = {
  'catalogo',
  'catalogos',
  'modelos',
  'disponibles',
  'producto',
  'productos',
  'servicio',
  'servicios',
  'precio',
  'precios',
  'valor',
  'valores',
  'cuesta',
  'cuestan',
  'cotizar',
  'cotizacion',
  'stock',
};
const _listPhrases = {
  'que tienen',
  'que ofrecen',
  'que vendes',
  'que venden',
  'que manejas',
  'que manejan',
  'tienen disponible',
  'tienen disponibles',
  'hay disponible',
  'hay stock',
  'tienen stock',
  'lista de precios',
  'lista de productos',
};
const _hoursTokens = {'horario', 'horarios', 'abren', 'cierran', 'jornada'};
const _hoursPhrases = {
  'horario de atencion',
  'a que hora abren',
  'a que hora cierran',
  'estan abiertos',
  'esta abierto',
  'atienden hoy',
  'abren hoy',
};
const _deliveryTokens = {
  'envio',
  'envios',
  'envian',
  'domi',
  'domicilio',
  'domicilios',
  'despacho',
  'despachos',
  'cobertura',
  'flete',
  'fletes',
};
const _deliveryPhrases = {
  'entrega a domicilio',
  'hacen envios',
  'hacen domicilio',
  'costo de envio',
  'valor del envio',
  'cuanto tarda el envio',
};
const _paymentsTokens = {
  'pago',
  'pagos',
  'pagar',
  'transferir',
  'transferencia',
  'nequi',
  'daviplata',
  'bancolombia',
  'contraentrega',
  'pse',
  'wompi',
};
const _paymentsPhrases = {
  'metodos de pago',
  'medios de pago',
  'formas de pago',
  'reciben tarjeta',
  'numero de cuenta',
  'datos de pago',
  'cuenta para transferir',
};
const _locationTokens = {'ubicacion', 'ubicados', 'sede', 'sedes'};
const _locationPhrases = {
  'donde quedan',
  'donde queda la tienda',
  'donde queda el local',
  'donde estan ubicados',
  'donde estan',
  'punto fisico',
  'punto de venta',
  'direccion de la tienda',
  'direccion del local',
  'recoger en tienda',
  'recogida en local',
  'tienda fisica',
};

/// Resultado inmutable de la detección de categorías solicitadas.
final class BusinessFactSignals {
  final bool wantsList;
  final bool wantsHours;
  final bool wantsDelivery;
  final bool wantsPayments;
  final bool wantsLocation;

  const BusinessFactSignals({
    required this.wantsList,
    required this.wantsHours,
    required this.wantsDelivery,
    required this.wantsPayments,
    required this.wantsLocation,
  });
}

/// Resuelve señales sin llamadas remotas ni estado compartido.
BusinessFactSignals detectBusinessFactSignals(
  String normalized,
  Set<String> tokens,
) => BusinessFactSignals(
  wantsList: _matches(normalized, tokens, _listTokens, _listPhrases),
  wantsHours: _matches(normalized, tokens, _hoursTokens, _hoursPhrases),
  wantsDelivery: _matches(
    normalized,
    tokens,
    _deliveryTokens,
    _deliveryPhrases,
  ),
  wantsPayments: _matches(
    normalized,
    tokens,
    _paymentsTokens,
    _paymentsPhrases,
  ),
  wantsLocation: _matches(
    normalized,
    tokens,
    _locationTokens,
    _locationPhrases,
  ),
);

bool _matches(
  String normalized,
  Set<String> tokens,
  Set<String> words,
  Set<String> phrases,
) => tokens.any(words.contains) || phrases.any(normalized.contains);

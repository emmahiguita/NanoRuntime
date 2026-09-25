// business_intent_patterns.dart
//
// QUÉ HACE: mantiene el vocabulario determinista de intenciones comerciales.
// CÓMO: reconoce palabras completas y frases dentro del mensaje normalizado.
// POR QUÉ: separa datos lingüísticos de la coordinación de la conversación.

const _greetings = {
  'hola',
  'buenas',
  'buenos',
  'dias',
  'tardes',
  'noches',
  'saludos',
  'que tal',
  'como estas',
  'como estan',
  'buen dia',
  'cordial saludo',
};
const _humanRequests = {
  'humano',
  'asesor',
  'asesora',
  'persona real',
  'atencion humana',
  'comunicar con un asesor',
  'hablar con alguien',
  'hablar con un asesor',
};
const _catalog = {
  'catalogo',
  'catalogos',
  'productos',
  'producto',
  'servicios',
  'servicio',
  'modelos',
  'disponibles',
  'que tienen',
  'que ofrecen',
  'que vendes',
  'que venden',
  'que manejan',
  'precio',
  'precios',
  'cuanto vale',
  'cuanto cuesta',
  'valor',
  'stock',
  'cotizar',
  'cotizacion',
  'comprar',
  'adquirir',
  'hacer pedido',
  'hacer un pedido',
};
const _delivery = {
  'envio',
  'envios',
  'domicilio',
  'domicilios',
  'despacho',
  'despachos',
  'cobertura',
  'flete',
  'fletes',
  'entrega a domicilio',
  'costo de envio',
  'valor del envio',
  'hacen envios',
  'hacen domicilio',
};
const _payments = {
  'pago',
  'pagos',
  'pagar',
  'transferir',
  'transferencia',
  'nequi',
  'daviplata',
  'bancolombia',
  'tarjeta',
  'contraentrega',
  'efectivo',
  'pse',
  'wompi',
  'metodos de pago',
  'medios de pago',
  'formas de pago',
  'reciben tarjeta',
  'datos de pago',
  'numero de cuenta',
  'cuenta para transferir',
};
const _hours = {
  'horario',
  'horarios',
  'abren',
  'abre',
  'abiertos',
  'abierto',
  'cierran',
  'cierra',
  'atienden',
  'atiende',
  'horario de atencion',
  'jornada de atencion',
  'abren hoy',
  'atienden hoy',
  'a que hora abren',
  'a que hora cierran',
};
const _locations = {
  'ubicados',
  'ubicacion',
  'punto fisico',
  'punto de venta',
  'sede',
  'sedes',
  'donde estan ubicados',
  'donde estan',
  'donde quedan',
  'donde queda la tienda',
  'donde queda el local',
  'direccion de la tienda',
  'direccion del local',
  'recoger en tienda',
  'recogida en local',
  'tienda fisica',
};

/// Señales independientes: un párrafo puede contener varias a la vez.
final class BusinessIntentSignals {
  final bool isGreeting;
  final bool isHumanRequest;
  final bool isCatalogAsk;
  final bool isDeliveryAsk;
  final bool isPaymentAsk;
  final bool isHoursAsk;
  final bool isLocationAsk;

  const BusinessIntentSignals({
    required this.isGreeting,
    required this.isHumanRequest,
    required this.isCatalogAsk,
    required this.isDeliveryAsk,
    required this.isPaymentAsk,
    required this.isHoursAsk,
    required this.isLocationAsk,
  });
}

/// Analiza todas las categorías sin detenerse en la primera coincidencia.
BusinessIntentSignals detectBusinessIntentSignals(
  String normalized,
  Set<String> tokens,
) => BusinessIntentSignals(
  isGreeting: _hasMatch(normalized, tokens, _greetings),
  isHumanRequest: _hasMatch(normalized, tokens, _humanRequests),
  isCatalogAsk: _hasMatch(normalized, tokens, _catalog),
  isDeliveryAsk: _hasMatch(normalized, tokens, _delivery),
  isPaymentAsk: _hasMatch(normalized, tokens, _payments),
  isHoursAsk: _hasMatch(normalized, tokens, _hours),
  isLocationAsk: _hasMatch(normalized, tokens, _locations),
);

bool _hasMatch(String normalized, Set<String> tokens, Set<String> patterns) {
  for (final pattern in patterns) {
    if (pattern.contains(' ')) {
      if (normalized.contains(pattern)) return true;
    } else if (tokens.contains(pattern)) {
      return true;
    }
  }
  return false;
}

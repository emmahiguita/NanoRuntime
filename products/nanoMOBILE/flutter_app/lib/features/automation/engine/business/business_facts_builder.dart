// business_facts_builder.dart
//
// QUÉ HACE:
// Generador determinista del bloque de hechos reales del negocio (<DATOS DEL NEGOCIO>)
// para inyección en memoria contextual y prompts del agente de ventas.
//
// CÓMO FUNCIONA:
// - Filtra y sanitiza strings de horarios, cobertura de envíos, métodos de pago y ubicación.
// - Serializa cada producto autorizado mediante su `promptLine()`.
// - Retorna cadena vacía si no existen hechos configurados, evitando inyecciones ruidosas.
//
// POR QUÉ:
// Única fuente de verdad compartida entre el volcado general de catálogo y el selector
// dinámico de hechos (`FactSelection`), garantizando consistencia y cero duplicación.

library;

import 'business_product.dart';

/// Ensambla el bloque canónico <DATOS DEL NEGOCIO> para el modelo de lenguaje local.
String buildBusinessBlock({
  required List<BusinessProduct> products,
  required String hours,
  required String delivery,
  String businessName = '',
  String payments = '',
  String location = '',
}) {
  final cleanName = businessName.trim();
  final cleanHours = hours.trim();
  final cleanDelivery = delivery.trim();
  final cleanPayments = payments.trim();
  final cleanLocation = location.trim();

  if (cleanName.isEmpty &&
      products.isEmpty &&
      cleanHours.isEmpty &&
      cleanDelivery.isEmpty &&
      cleanPayments.isEmpty &&
      cleanLocation.isEmpty) {
    return '';
  }

  final buffer = StringBuffer('<DATOS DEL NEGOCIO>\n');
  if (cleanName.isNotEmpty) {
    buffer.writeln('Nombre comercial: $cleanName');
  }
  if (products.isNotEmpty) {
    buffer
      ..writeln('Productos en venta:')
      ..writeln(products.map((p) => p.promptLine()).join('\n'));
  }
  if (cleanHours.isNotEmpty) {
    buffer.writeln('Horario: $cleanHours');
  }
  if (cleanDelivery.isNotEmpty) {
    buffer.writeln('Envío: $cleanDelivery');
  }
  if (cleanPayments.isNotEmpty) {
    buffer.writeln('Métodos de pago: $cleanPayments');
  }
  if (cleanLocation.isNotEmpty) {
    buffer.writeln('Ubicación: $cleanLocation');
  }
  buffer.write('</DATOS DEL NEGOCIO>');
  return buffer.toString();
}

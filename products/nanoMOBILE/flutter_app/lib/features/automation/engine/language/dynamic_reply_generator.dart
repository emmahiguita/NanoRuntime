// dynamic_reply_generator.dart
//
// Generador de opciones respaldadas por información real del negocio.
// - ¿Qué hace?: Produce variantes únicamente cuando el mensaje coincide con
//   productos, precios, envíos, pagos u horarios guardados por el usuario.
// - ¿Cómo funciona?: FactSelection selecciona primero los hechos aplicables y
//   esta clase solo cambia su redacción; nunca completa un dato desconocido.
// - ¿Por qué?: La conversación personal pertenece al compositor contextual.
//   Devolver acuses genéricos aquí ocultaba preguntas que el motor no entendió.

library;

import '../business/business_facts.dart';
import '../business/fact_selector.dart';

/// Generador determinista de opciones comerciales basadas en hechos.
final class DynamicReplyGenerator {
  const DynamicReplyGenerator();

  /// Analiza [incomingText] y genera opciones inteligentes con respaldo en [facts].
  List<String> generateOptions({
    required String incomingText,
    required BusinessFacts facts,
    String? senderName,
  }) {
    final raw = incomingText.trim();
    if (raw.isEmpty) return const [];

    final options = <String>[];
    final selection = facts.isEmpty
        ? const FactSelection()
        : selectFactsForMessage(raw, facts);

    // Sin hechos seleccionados no hay respuesta segura. El compositor con
    // memoria y modelo real decide el turno personal; aquí no se lo tapa.
    if (selection.isEmpty) return const [];

    // Las tres variantes usan exactamente el mismo conjunto de hechos.
    if (selection.isNotEmpty) {
      final productInfo = selection.products.isNotEmpty
          ? selection.products
                .take(2)
                .map((p) => '${p.name} (${p.priceLabel})')
                .join(' y ')
          : '';

      // Opción A: Resolutiva directa (Responde todo con datos concretos)
      final bufA = StringBuffer();
      if (productInfo.isNotEmpty) bufA.write('El valor es: $productInfo. ');
      if (selection.delivery.isNotEmpty) {
        bufA.write('Envíos: ${selection.delivery}. ');
      }
      if (selection.payments.isNotEmpty) {
        bufA.write('Recibimos: ${selection.payments}. ');
      }
      if (selection.hours.isNotEmpty) {
        bufA.write('Horario: ${selection.hours}. ');
      }
      options.add(bufA.toString().trim());

      // Opción B: Consultiva amable (Invita a continuar la orden o aclara dudas)
      final bufB = StringBuffer();
      if (productInfo.isNotEmpty) {
        bufB.write('Tenemos disponible $productInfo. ');
      }
      if (selection.delivery.isNotEmpty) {
        bufB.write('Manejamos despacho a domicilio. ');
      }
      bufB.write('¿Para cuándo o a qué dirección lo necesitarías?');
      options.add(bufB.toString().trim());

      // Opción C: Práctica / Ejecutiva (Ágil para confirmación inmediata)
      final bufC = StringBuffer();
      bufC.write('Claro que sí, tenemos disponibilidad');
      if (selection.payments.isNotEmpty) {
        bufC.write(' y recibimos ${selection.payments}');
      }
      bufC.write('. ¿Deseas que te tomemos los datos de una?');
      options.add(bufC.toString().trim());
    }

    // Deduplicar manteniendo el orden de relevancia.
    final unique = <String>[];
    for (final opt in options) {
      final clean = opt.trim();
      if (clean.isNotEmpty && !unique.contains(clean)) {
        unique.add(clean);
      }
    }
    return unique;
  }
}

/// Instancia constante global reutilizable sin costo de alocación de memoria.
const dynamicReplyGenerator = DynamicReplyGenerator();

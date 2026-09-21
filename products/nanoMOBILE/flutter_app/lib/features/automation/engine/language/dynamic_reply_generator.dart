// dynamic_reply_generator.dart
// 
// Motor conversacional inteligente para generación de opciones de respuesta humanas.
// - ¿Qué hace?: Analiza mensajes entrantes (desde un simple 'hola' hasta párrafos largos)
//   y genera 3 opciones de respuesta naturales, factuales y no robóticas.
// - ¿Cómo funciona?: Descompone el mensaje en intenciones concurrentes (saludo, productos,
//   precios, envíos, métodos de pago, horarios, agradecimiento) mediante FactSelection y
//   síntesis lingüística multi-tono (Resolutiva, Consultiva, Ejecutiva).
// - ¿Por qué?: Reemplaza los bloques 'if/else' estáticos de la UI, respeta SOLID (SRP)
//   y mantiene el archivo bajo 200 líneas de código limpio y mantenible.

library;

import '../business/business_facts.dart';
import '../business/fact_selector.dart';

/// Generador determinista y multi-tono de opciones de respuesta sin frases robóticas.
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

    final norm = raw.toLowerCase();
    final options = <String>[];
    final selection = facts.isEmpty ? const FactSelection() : selectFactsForMessage(raw, facts);

    final hasGreeting = norm.contains('hola') || norm.contains('buenas') || norm.contains('que mas') || norm.contains('quiubo');
    final hasStatusAsk = norm.contains('como estas') || norm.contains('como te va') || norm.contains('que tal') || norm.contains('todo bien');
    final hasThanks = norm.contains('gracias') || norm.contains('agradezco');

    // 1. Mensaje con hechos factuales concretos (productos, precios, envíos, pagos)
    if (selection.isNotEmpty) {
      final productInfo = selection.products.isNotEmpty
          ? selection.products.take(2).map((p) => '${p.name} (${p.priceLabel})').join(' y ')
          : '';

      // Opción A: Resolutiva directa (Responde todo con datos concretos)
      final bufA = StringBuffer();
      if (hasGreeting) bufA.write('¡Hola! ');
      if (productInfo.isNotEmpty) bufA.write('El valor es: $productInfo. ');
      if (selection.delivery.isNotEmpty) bufA.write('Envíos: ${selection.delivery}. ');
      if (selection.payments.isNotEmpty) bufA.write('Recibimos: ${selection.payments}. ');
      if (selection.hours.isNotEmpty) bufA.write('Horario: ${selection.hours}. ');
      options.add(bufA.toString().trim());

      // Opción B: Consultiva amable (Invita a continuar la orden o aclara dudas)
      final bufB = StringBuffer();
      if (hasGreeting) bufB.write('¡Buenas tardes! Con gusto te colaboro. ');
      if (productInfo.isNotEmpty) bufB.write('Tenemos disponible $productInfo. ');
      if (selection.delivery.isNotEmpty) bufB.write('Manejamos despacho a domicilio. ');
      bufB.write('¿Para cuándo o a qué dirección lo necesitarías?');
      options.add(bufB.toString().trim());

      // Opción C: Práctica / Ejecutiva (Ágil para confirmación inmediata)
      final bufC = StringBuffer();
      bufC.write('Claro que sí, tenemos disponibilidad');
      if (selection.payments.isNotEmpty) bufC.write(' y recibimos ${selection.payments}');
      bufC.write('. ¿Deseas que te tomemos los datos de una?');
      options.add(bufC.toString().trim());
    }

    // 2. Mensajes sociales puros (saludos, bienestar, preguntas cotidianas)
    if (options.isEmpty && (hasGreeting || hasStatusAsk)) {
      final namePrefix = (senderName != null && senderName.trim().isNotEmpty) ? ' ${senderName.trim()}' : '';
      options.addAll([
        '¡Hola$namePrefix! Todo muy bien por acá gracias a Dios, ¿en qué te puedo colaborar hoy?',
        '¡Buenas! Por acá todo tranquilo y en orden, cuéntame qué necesitas.',
        'Hola$namePrefix, con gusto te atiendo. ¿Qué consulta o pedido tienes en mente?',
      ]);
    }

    // 3. Consultas sobre actividad, tareas o planes cotidianos
    if (options.isEmpty && (norm.contains('haces') || norm.contains('hacer') || norm.contains('haciendo') || norm.contains('andas'))) {
      options.addAll([
        'Por acá tranquilo adelantando cosas pendientes, ¿y tú qué tal?',
        'Aquí en la rutina de siempre. Cuéntame, ¿qué planes tienes o qué hay para hacer?',
        'Todo bien por acá en lo mío. Más tardecito te voy avisando con calma.',
      ]);
    }

    // 4. Preguntas de ayuda, dudas o solicitudes generales
    if (options.isEmpty && (norm.contains('ayuda') || norm.contains('favor') || norm.contains('duda') || norm.contains('pregunta') || norm.contains('tarea'))) {
      options.addAll([
        '¡De una! Cuéntame de qué se trata y lo miramos de inmediato.',
        'Claro que sí, con mucho gusto. Dime en qué te puedo colaborar.',
        'Explícame con calma y con gusto te doy una mano.',
      ]);
    }

    // 5. Agradecimientos o cierres de conversación
    if (options.isEmpty && hasThanks) {
      options.addAll([
        '¡Con mucho gusto! Quedamos a la orden para lo que necesites.',
        '¡De una, un placer colaborarte! Cualquier otra inquietud me avisas.',
        'A ti por escribirnos, que tengas un excelente día.',
      ]);
    }

    // 6. Mensajes largos descriptivos no estructurados (párrafos grandes sin coincidencia directa)
    if (options.isEmpty && raw.length > 50) {
      options.addAll([
        'Entendido perfectamente. Déjame revisar los detalles que me mencionas y ya mismo te confirmo.',
        'Recibido con claridad. Te preparo la información completa para darte una respuesta precisa.',
        'De una, gracias por el detalle. Ya lo estoy revisando para confirmarte los siguientes pasos.',
      ]);
    }

    // 7. Fallback conciso conversacional en lugar de frases mudas o robóticas
    if (options.isEmpty) {
      options.addAll([
        'Dale, de una.',
        'Perfecto, entendido.',
        'Listo, muchas gracias.',
      ]);
    }

    // Deduplicar manteniendo el orden de relevancia
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

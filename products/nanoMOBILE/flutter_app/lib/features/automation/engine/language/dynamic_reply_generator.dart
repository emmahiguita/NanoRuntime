// dynamic_reply_generator.dart
//
// QUÉ HACE:
// Genera variantes comerciales únicamente desde hechos configurados.
//
// CÓMO FUNCIONA:
// - Analiza la entrada con `BusinessIntentAnalyzer` y selecciona hechos con `selectFactsForMessage`.
// - Los saludos puros quedan en el compositor contextual, sin frases enlatadas.
// - Para consultas reales combina precio, envío, pago, horario y ubicación.
// - Una solicitud humana no produce una promesa ficticia de transferencia.
//
// POR QUÉ:
// Evita opciones que afirmen stock, descuentos o acciones no observadas (< 180 líneas).

library;

import '../business/business_facts.dart';
import '../business/business_intent_analyzer.dart';
import '../business/fact_selector.dart';
import '../messaging/tone_profile.dart';

/// Generador determinista de opciones comerciales basadas en hechos.
final class DynamicReplyGenerator {
  final BusinessIntentAnalyzer _analyzer;

  const DynamicReplyGenerator({
    BusinessIntentAnalyzer analyzer = const BusinessIntentAnalyzer(),
  }) : _analyzer = analyzer;

  /// Analiza [incomingText] y genera opciones inteligentes con respaldo en [facts].
  List<String> generateOptions({
    required String incomingText,
    required BusinessFacts facts,
    ToneProfile tone = const ToneProfile(),
  }) {
    final raw = incomingText.trim();
    if (raw.isEmpty) return const [];

    final analysis = _analyzer.analyze(raw, facts);

    // Saludos y solicitudes humanas dependen del compositor/traspaso real.
    if (analysis.isHumanRequest ||
        analysis.totalIntentsCount == 1 && analysis.isGreeting) {
      return const [];
    }

    // Resolver con hechos comerciales específicos
    final selection = facts.isEmpty
        ? const FactSelection()
        : selectFactsForMessage(raw, facts);
    final options = <String>[];

    if (selection.isNotEmpty) {
      final productInfo = selection.products.isNotEmpty
          ? selection.products
                .take(2)
                .map((p) => '${p.name} (${p.priceLabel})')
                .join(' y ')
          : '';

      // Opción A: Resolutiva directa con datos concretos
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
      if (selection.location.isNotEmpty) {
        bufA.write('Ubicación: ${selection.location}. ');
      }
      if (bufA.isNotEmpty) options.add(bufA.toString().trim());

      // Opción B: misma evidencia, con una pregunta contextual verificable.
      final bufB = StringBuffer();
      if (productInfo.isNotEmpty) {
        bufB.write('La información registrada es $productInfo. ');
      }
      if (selection.delivery.isNotEmpty) {
        bufB.write('${selection.delivery}. ');
      }
      if (productInfo.isNotEmpty || selection.delivery.isNotEmpty) {
        bufB.write(
          tone.warmth == ToneWarmth.cercano
              ? '¿Qué dato necesitas confirmar?'
              : '¿Qué información desea confirmar?',
        );
      }
      options.add(bufB.toString().trim());

      // Opción C: versión breve, sin afirmar stock ni acciones inexistentes.
      final bufC = StringBuffer();
      if (productInfo.isNotEmpty) bufC.write(productInfo);
      if (selection.payments.isNotEmpty) {
        if (bufC.isNotEmpty) bufC.write('. ');
        bufC.write(selection.payments);
      }
      if (selection.hours.isNotEmpty) {
        if (bufC.isNotEmpty) bufC.write('. ');
        bufC.write(selection.hours);
      }
      if (bufC.isNotEmpty) options.add('${bufC.toString().trim()}.');
    }

    // Deduplicar manteniendo orden de relevancia
    final unique = <String>[];
    for (final opt in options) {
      final clean = opt.trim();
      if (clean.isNotEmpty && !unique.contains(clean)) {
        unique.add(clean);
      }
    }
    return unique.take(3).toList();
  }
}

/// Instancia constante global reutilizable sin costo de alocación de memoria.
const dynamicReplyGenerator = DynamicReplyGenerator();

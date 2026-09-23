// business_conversation_resolver.dart
//
// QUÉ HACE:
// Orquestador y generador de respuestas comerciales automáticas para WhatsApp y atención al cliente.
//
// CÓMO FUNCIONA:
// - Analiza la entrada con [BusinessIntentAnalyzer] detectando desde un "Hola" hasta párrafos multi-pregunta.
// - Aplica el perfil de tono [ToneProfile] (persuasivo vs natural, tuteo vs formal, emojis, extensión).
// - Ensambla respuestas fluidas con todos los datos consultados y produce 3 opciones interactivas de respuesta.
//
// POR QUÉ:
// Evita respuestas robóticas o estáticas, elimina cuellos de botella y garantiza atención inmediata (< 200 líneas).

import '../messaging/tone_profile.dart';
import 'business_conversation_models.dart';
import 'business_facts.dart';
import 'business_intent_analyzer.dart';

class BusinessConversationResolver {
  final BusinessIntentAnalyzer analyzer;

  const BusinessConversationResolver({
    this.analyzer = const BusinessIntentAnalyzer(),
  });

  BusinessTurnReply? resolve({
    required String message,
    required BusinessFacts facts,
    required ToneProfile tone,
    String? businessName,
  }) {
    final clean = message.trim();
    if (clean.isEmpty) return null;

    final analysis = analyzer.analyze(clean, facts);
    if (!analysis.hasCommercialIntent && facts.isEmpty) return null;

    final isTuteo = tone.warmth == ToneWarmth.cercano;
    final isPersuasive = tone.sales == ToneSales.persuasivo;
    final useEmojis = tone.emojis;
    final bName = businessName?.trim().isNotEmpty == true ? businessName!.trim() : 'nuestra tienda';

    final textBuffer = StringBuffer();
    final suggestions = <String>[];

    // 1. Manejo de solicitud de asesor humano
    if (analysis.isHumanRequest) {
      final msg = isTuteo
          ? '${useEmojis ? "👋 " : ""}¡Claro que sí! He avisado a nuestro equipo para que un asesor continúe contigo de inmediato.'
          : '${useEmojis ? "👋 " : ""}Con mucho gusto. Le informamos que un asesor se comunicará con usted a la brevedad para atenderle.';
      suggestions.addAll([
        'Esperar asesor',
        'Ver catálogo mientras tanto',
        'Dejar mensaje detallado',
      ]);
      return BusinessTurnReply(text: msg, suggestions: suggestions);
    }

    // 2. Saludo de apertura si aplica
    if (analysis.isGreeting) {
      final greeting = isTuteo
          ? '${useEmojis ? "👋 " : ""}¡Hola! Te damos la bienvenida a $bName.'
          : '${useEmojis ? "👋 " : ""}Un cordial saludo. Bienvenido/a a $bName.';
      textBuffer.write('$greeting ');
    }

    // 3. Productos / Catálogo
    if (analysis.matchedProducts.isNotEmpty) {
      final prodList = analysis.matchedProducts
          .take(3)
          .map((p) => '${p.name} por ${p.priceLabel}${p.stock != null && p.stock! > 0 ? " (disponible)" : ""}')
          .join(', ');
      final prodIntro = isTuteo
          ? (isPersuasive ? 'Tenemos disponible $prodList, ¡de excelente calidad!' : 'Contamos con $prodList.')
          : (isPersuasive ? 'Tenemos a su disposición $prodList con excelentes beneficios.' : 'Disponemos de $prodList.');
      textBuffer.write('$prodIntro ');
      suggestions.add('Confirmar pedido');
    } else if (analysis.isCatalogAsk && facts.products.isNotEmpty) {
      final topProds = facts.products.take(4).map((p) => '${p.name} (${p.priceLabel})').join(' · ');
      final catText = isTuteo
          ? 'En nuestro catálogo manejamos: $topProds.'
          : 'En nuestro catálogo disponemos de: $topProds.';
      textBuffer.write('$catText ');
      suggestions.add('Ver catálogo completo');
    }

    // 4. Envíos y Domicilios
    if (analysis.isDeliveryAsk && facts.delivery.trim().isNotEmpty) {
      final delPrefix = useEmojis ? '📦 ' : '';
      textBuffer.write('$delPrefix${facts.delivery.trim()}. ');
      suggestions.add('Consultar costo de envío');
    }

    // 5. Métodos de Pago
    if (analysis.isPaymentAsk && facts.payments.trim().isNotEmpty) {
      final payPrefix = useEmojis ? '💳 ' : '';
      textBuffer.write('$payPrefix${facts.payments.trim()}. ');
      suggestions.add('Ver cuentas de pago');
    }

    // 6. Horarios de Atención
    if (analysis.isHoursAsk && facts.hours.trim().isNotEmpty) {
      final hourPrefix = useEmojis ? '🕒 ' : '';
      textBuffer.write('$hourPrefix${facts.hours.trim()}. ');
      suggestions.add('Ver horarios');
    }

    // 7. Ubicación / Sede
    if (analysis.isLocationAsk && facts.location.trim().isNotEmpty) {
      final locPrefix = useEmojis ? '📍 ' : '';
      textBuffer.write('$locPrefix${facts.location.trim()}. ');
      suggestions.add('Ver ubicación');
    }

    // 8. Cierre comercial adaptado
    if (textBuffer.isNotEmpty) {
      final closing = isTuteo
          ? (isPersuasive ? '¿Te gustaría que te apartemos tu pedido de una vez?' : '¿En qué más te podemos ayudar?')
          : (isPersuasive ? '¿Desea que gestionemos su pedido en este momento?' : '¿Tiene alguna otra inquietud?');
      textBuffer.write(closing);
    } else if (analysis.isGreeting) {
      final defaultIntro = isTuteo
          ? '¿En qué te podemos colaborar hoy? Pregúntanos por productos, precios, envíos o formas de pago.'
          : '¿En qué podemos servirle el día de hoy? Con gusto le informamos sobre productos, precios, envíos y pagos.';
      textBuffer.write(defaultIntro);
    }

    final finalReply = textBuffer.toString().trim();
    if (finalReply.isEmpty) return null;

    // Completar 3 sugerencias interactivas ricas y variadas
    if (suggestions.length < 3) {
      final defaultOpts = isTuteo
          ? ['Ver Catálogo PDF', 'Ruleta de Descuentos', 'Hablar con un asesor']
          : ['Ver Catálogo en PDF', 'Girar Ruleta de Descuento', 'Comunicar con un asesor'];
      for (final opt in defaultOpts) {
        if (!suggestions.contains(opt)) suggestions.add(opt);
        if (suggestions.length >= 3) break;
      }
    }

    return BusinessTurnReply(
      text: finalReply,
      suggestions: suggestions.take(3).toList(),
      isDirectResolution: true,
    );
  }
}

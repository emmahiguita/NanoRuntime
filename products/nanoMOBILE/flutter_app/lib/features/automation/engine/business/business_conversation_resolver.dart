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
// Conserva un fallback factual cuando el modelo contextual no está disponible (< 200 líneas).

import '../messaging/tone_profile.dart';
import 'business_conversation_models.dart';
import 'business_facts.dart';
import 'business_intent_analyzer.dart';
import 'business_reply_phrases.dart';

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
    final missingFacts = <String>[
      if (analysis.isCatalogAsk && facts.products.isEmpty) 'catálogo',
      if (analysis.isDeliveryAsk && facts.delivery.trim().isEmpty) 'envíos',
      if (analysis.isPaymentAsk && facts.payments.trim().isEmpty)
        'medios de pago',
      if (analysis.isHoursAsk && facts.hours.trim().isEmpty) 'horarios',
      if (analysis.isLocationAsk && facts.location.trim().isEmpty) 'ubicación',
    ];

    final isTuteo = tone.warmth == ToneWarmth.cercano;
    final isPersuasive = tone.sales == ToneSales.persuasivo;
    final useEmojis = tone.emojis;
    final productLimit = switch (tone.verbosity) {
      ToneVerbosity.breve => 2,
      ToneVerbosity.media => 3,
      ToneVerbosity.extensa => 5,
    };
    final configuredName = businessName?.trim().isNotEmpty == true
        ? businessName!.trim()
        : facts.businessName.trim();
    final bName = configuredName.isNotEmpty ? configuredName : 'nuestra tienda';

    // 1. Manejo de solicitud de asesor humano
    if (analysis.isHumanRequest) {
      return BusinessTurnReply(
        text: businessHumanReply(tone, clean),
        suggestions: isTuteo
            ? const [
                'Ver catálogo mientras espero',
                'Consultar formas de pago',
                'Dejar mensaje',
              ]
            : const ['Ver catálogo', 'Medios de pago', 'Dejar mensaje'],
        isDirectResolution: false,
        needsHuman: true,
      );
    }

    // 2. Saludo puro: respuesta inmediata y amable sin esperar LLM
    if (analysis.isGreeting && analysis.totalIntentsCount == 1) {
      return BusinessTurnReply(
        text: businessGreeting(name: bName, tone: tone, message: clean),
        suggestions: const [
          'Ver catálogo',
          'Costos de envío',
          'Medios de pago',
        ],
        isDirectResolution: true,
      );
    }

    final textBuffer = StringBuffer();
    final suggestions = <String>[];

    // 3. Saludo de apertura cuando acompaña preguntas comerciales
    if (analysis.isGreeting) {
      final greeting = isTuteo
          ? '${useEmojis ? "👋 " : ""}¡Hola! Te damos la bienvenida a $bName.'
          : '${useEmojis ? "👋 " : ""}Un cordial saludo. Bienvenido/a a $bName.';
      textBuffer.write('$greeting ');
    }

    // 4. Productos / Catálogo
    if (analysis.matchedProducts.isNotEmpty) {
      final prodList = analysis.matchedProducts
          .take(productLimit)
          .map(
            (p) =>
                '${p.name} por ${p.priceLabel}${p.stock != null && p.stock! > 0 ? " (disponible)" : ""}',
          )
          .join(', ');
      final prodIntro = isTuteo
          ? 'Según el catálogo registrado: $prodList.'
          : 'Según la información registrada en el catálogo: $prodList.';
      textBuffer.write('$prodIntro ');
      suggestions.add('Confirmar pedido');
    } else if (analysis.isCatalogAsk && facts.products.isNotEmpty) {
      final topProds = facts.products
          .take(productLimit + 1)
          .map((p) => '${p.name} (${p.priceLabel})')
          .join(' · ');
      final catText = isTuteo
          ? 'En nuestro catálogo manejamos: $topProds.'
          : 'En nuestro catálogo disponemos de: $topProds.';
      textBuffer.write('$catText ');
      suggestions.add('Ver catálogo completo');
    }

    // 5. Envíos y Domicilios
    if (analysis.isDeliveryAsk && facts.delivery.trim().isNotEmpty) {
      final delPrefix = useEmojis ? '📦 ' : '';
      textBuffer.write('$delPrefix${facts.delivery.trim()}. ');
      suggestions.add('Consultar costo de envío');
    }

    // 6. Métodos de Pago
    if (analysis.isPaymentAsk && facts.payments.trim().isNotEmpty) {
      final payPrefix = useEmojis ? '💳 ' : '';
      textBuffer.write('$payPrefix${facts.payments.trim()}. ');
      suggestions.add('Ver medios de pago');
    }

    // 7. Horarios de Atención
    if (analysis.isHoursAsk && facts.hours.trim().isNotEmpty) {
      final hourPrefix = useEmojis ? '🕒 ' : '';
      textBuffer.write('$hourPrefix${facts.hours.trim()}. ');
    }

    // 8. Ubicación / Sede
    if (analysis.isLocationAsk && facts.location.trim().isNotEmpty) {
      final locPrefix = useEmojis ? '📍 ' : '';
      textBuffer.write('$locPrefix${facts.location.trim()}. ');
    }

    // 9. Cierre comercial adaptado
    if (textBuffer.isNotEmpty) {
      final closing = isTuteo
          ? (isPersuasive
                ? '¿Qué detalle quieres que revisemos para continuar?'
                : '¿En qué más te podemos ayudar?')
          : (isPersuasive
                ? '¿Qué detalle desea que revisemos para continuar?'
                : '¿Tiene alguna otra inquietud?');
      textBuffer.write(closing);
    } else if (missingFacts.isNotEmpty) {
      // Sin hechos reales, pregunta de forma honesta y no promete información.
      textBuffer.write(
        businessMissingReply(missing: missingFacts, tone: tone, message: clean),
      );
      suggestions.add('Hablar con un asesor');
    } else {
      // Consulta no comprendida o link/video: respuesta cortés y orientadora
      final fallbackNotice = businessUnknownReply(
        hasLink: RegExp(r'https?://|www\.').hasMatch(clean.toLowerCase()),
        tone: tone,
        message: clean,
      );
      textBuffer.write(fallbackNotice);
      suggestions.addAll(['Ver catálogo', 'Hablar con un asesor']);
    }

    final finalReply = textBuffer.toString().trim();
    if (finalReply.isEmpty) return null;

    if (suggestions.isEmpty) {
      suggestions.addAll(['Ver catálogo', 'Hablar con un asesor']);
    }

    return BusinessTurnReply(
      text: finalReply,
      suggestions: suggestions.take(3).toList(),
      isDirectResolution: true,
      missingFacts: missingFacts,
    );
  }
}

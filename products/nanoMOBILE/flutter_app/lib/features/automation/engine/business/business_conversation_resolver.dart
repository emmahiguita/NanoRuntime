// business_conversation_resolver.dart
//
// QUÉ HACE:
// Orquestador y generador de respuestas comerciales automáticas para WhatsApp y atención al cliente.
//
// CÓMO: analiza entradas breves o extensas, aplica el tono y compone opciones.
// POR QUÉ: conserva un fallback factual si el modelo contextual no está disponible.

import '../messaging/tone_profile.dart';
import 'business_conversation_models.dart';
import 'business_facts.dart';
import 'business_intent_analyzer.dart';
import 'business_product_reply.dart';
import 'business_profile_policy.dart';
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
    final availableProducts = facts.products
        .where((product) => product.isAvailable)
        .toList(growable: false);
    final missingFacts = <String>[
      if (analysis.isCatalogAsk && availableProducts.isEmpty) 'catálogo',
      if (analysis.isDeliveryAsk && facts.delivery.trim().isEmpty) 'envíos',
      if (analysis.isPaymentAsk && facts.payments.trim().isEmpty)
        'medios de pago',
      if (analysis.isHoursAsk && facts.hours.trim().isEmpty) 'horarios',
      if (analysis.isLocationAsk && facts.location.trim().isEmpty) 'ubicación',
    ];

    final isTuteo = tone.warmth == ToneWarmth.cercano;
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
    final requiresReview = !facts.profile.autoReply;

    // 1. Manejo de solicitud de asesor humano
    if (analysis.isHumanRequest) {
      return BusinessTurnReply(
        text: businessHumanReply(
          tone,
          clean,
          templates: facts.responseTemplates,
        ),
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

    // La política activa resuelve FAQ y límites sensibles con datos guardados.
    final policyReply = resolveBusinessProfilePolicy(clean, facts.profile);
    if (policyReply != null) {
      final needsHuman = policyReply.needsHuman || requiresReview;
      return BusinessTurnReply(
        text: policyReply.text,
        suggestions: policyReply.suggestions,
        isDirectResolution: !needsHuman,
        needsHuman: needsHuman,
      );
    }

    // 2. Saludo puro: respuesta inmediata y amable sin esperar LLM
    if (analysis.isGreeting && analysis.totalIntentsCount == 1) {
      return BusinessTurnReply(
        text: businessGreeting(
          name: bName,
          tone: tone,
          message: clean,
          templates: facts.responseTemplates,
        ),
        suggestions: const [
          'Ver catálogo',
          'Costos de envío',
          'Medios de pago',
        ],
        isDirectResolution: !requiresReview,
        needsHuman: requiresReview,
      );
    }

    final textBuffer = StringBuffer();
    final suggestions = <String>[];

    // 3. Saludo de apertura cuando acompaña preguntas comerciales
    if (analysis.isGreeting) {
      final greeting = businessGreetingPrefix(
        name: bName,
        tone: tone,
        templates: facts.responseTemplates,
      );
      textBuffer.write('$greeting ');
    }

    // 4. Productos / Catálogo
    if (analysis.matchedProducts.isNotEmpty) {
      final productReply = buildMatchedProductReply(
        products: analysis.matchedProducts,
        limit: productLimit,
        informal: isTuteo,
        templates: facts.responseTemplates,
      );
      textBuffer.write('${productReply.text} ');
      suggestions.add(productReply.suggestion);
    } else if (analysis.isCatalogAsk && availableProducts.isNotEmpty) {
      textBuffer.write(
        '${buildCatalogReply(products: availableProducts, limit: productLimit + 1, informal: isTuteo, templates: facts.responseTemplates)} ',
      );
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
      final closing = businessSalesClosing(
        tone: tone,
        templates: facts.responseTemplates,
      );
      textBuffer.write(closing);
    } else if (missingFacts.isNotEmpty) {
      // Sin hechos reales, pregunta de forma honesta y no promete información.
      textBuffer.write(
        businessMissingReply(
          missing: missingFacts,
          tone: tone,
          message: clean,
          templates: facts.responseTemplates,
        ),
      );
      suggestions.add('Hablar con un asesor');
    } else {
      // Consulta no comprendida o link/video: respuesta cortés y orientadora
      final fallbackNotice = businessUnknownReply(
        hasLink: RegExp(r'https?://|www\.').hasMatch(clean.toLowerCase()),
        tone: tone,
        message: clean,
        templates: facts.responseTemplates,
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
      isDirectResolution: !requiresReview,
      needsHuman: requiresReview,
      missingFacts: missingFacts,
    );
  }
}

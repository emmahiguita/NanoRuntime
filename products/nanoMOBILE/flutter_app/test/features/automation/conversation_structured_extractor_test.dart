// conversation_structured_extractor_test.dart
//
// QUÉ HACE:
// Pruebas unitarias para el motor de extracción estructurada de conversaciones.
//
// CÓMO FUNCIONA:
// - Valida detección determinista de presupuesto, urgencia, objeciones y calidad de lead.
// - Verifica resiliencia del parser de respuestas LLM con JSON puro y markdown.
// - Confirma integridad de serialización JSON del perfil de inteligencia comercial.
//
// POR QUÉ:
// Garantiza que la extracción opere a coste $0 con exactitud y sin fallos en tiempo de ejecución.

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/intelligence/conversation_intelligence_profile.dart';
import 'package:nanoai/features/automation/engine/business/intelligence/conversation_structured_extractor.dart';
import 'package:nanoai/features/automation/engine/messaging/canonical_message.dart';

void main() {
  group('ConversationStructuredExtractor Tests', () {
    const extractor = ConversationStructuredExtractor();

    test('extractDeterministic califica lead Hot con presupuesto y urgencia', () {
      final messages = [
        CanonicalMessage.observed(
          conversationId: 'conv_123',
          provider: CanonicalMessageProvider.whatsappWeb,
          sender: 'Cliente',
          body: 'Hola, tengo un presupuesto de 450 USD y lo necesito urgente para hoy mismo.',
          direction: CanonicalMessageDirection.inbound,
          occurredAtMs: 1729000000000,
        ),
      ];

      final profile = extractor.extractDeterministic(
        conversationId: 'conv_123',
        messages: messages,
      );

      expect(profile.leadQuality, LeadQuality.hot);
      expect(profile.budgetMentioned, 450.0);
      expect(profile.currency, 'USD');
      expect(profile.urgent, isTrue);
      expect(profile.confidenceScore, greaterThanOrEqualTo(0.8));
      expect(profile.nextRecommendedAction, contains('cotización formal'));
    });

    test('extractDeterministic detecta productos de interes y objeciones de precio', () {
      const facts = BusinessFacts(
        businessName: 'TechStore',
        products: [
          BusinessProduct(
            id: 'p1',
            name: 'Laptop Gamer X',
            details: 'Laptop de alta gama para gaming',
            price: 1200,
            isAvailable: true,
          ),
        ],
      );

      final messages = [
        CanonicalMessage.observed(
          conversationId: 'conv_456',
          provider: CanonicalMessageProvider.whatsappWeb,
          sender: 'Cliente',
          body: 'Me interesa la Laptop Gamer X pero se me hace un poco caro, tienen descuento?',
          direction: CanonicalMessageDirection.inbound,
          occurredAtMs: 1729000000000,
        ),
      ];

      final profile = extractor.extractDeterministic(
        conversationId: 'conv_456',
        messages: messages,
        facts: facts,
      );

      expect(profile.productsOfInterest, contains('Laptop Gamer X'));
      expect(profile.objections, contains('caro'));
      expect(profile.objections, contains('descuento'));
      expect(profile.leadQuality, LeadQuality.warm);
    });

    test('parseLlmResponse decodifica JSON limpio y envuelto en markdown', () {
      const rawJson = '''
      {
        "leadQuality": "hot",
        "budgetMentioned": 850,
        "currency": "EUR",
        "urgent": true,
        "humanHandoffRequested": false,
        "productsOfInterest": ["Curso Pro"],
        "painPoints": ["Falta de tiempo"],
        "objections": [],
        "nextRecommendedAction": "Cerrar venta vía Stripe",
        "confidenceScore": 0.95
      }
      ''';

      final profile1 = extractor.parseLlmResponse(
        rawJson,
        conversationId: 'conv_llm_1',
      );
      expect(profile1.leadQuality, LeadQuality.hot);
      expect(profile1.budgetMentioned, 850.0);
      expect(profile1.currency, 'EUR');
      expect(profile1.nextRecommendedAction, 'Cerrar venta vía Stripe');

      const markdownJson = 'Aquí está el resultado:\n```json\n$rawJson\n```\nFin.';
      final profile2 = extractor.parseLlmResponse(
        markdownJson,
        conversationId: 'conv_llm_2',
      );
      expect(profile2.leadQuality, LeadQuality.hot);
      expect(profile2.budgetMentioned, 850.0);
      expect(profile2.conversationId, 'conv_llm_2');
    });

    test('parseLlmResponse maneja fallos de sintaxis con fallback seguro', () {
      final fallback = ConversationIntelligenceProfile.initial('conv_err');
      final result = extractor.parseLlmResponse(
        'Esto no es un JSON válido',
        conversationId: 'conv_err',
        fallback: fallback,
      );

      expect(result.leadQuality, LeadQuality.unqualified);
      expect(result.conversationId, 'conv_err');
    });

    test('toJson y fromJson preservan todos los campos estructurados', () {
      final original = ConversationIntelligenceProfile(
        conversationId: 'conv_full',
        leadQuality: LeadQuality.warm,
        budgetMentioned: 300.0,
        currency: 'MXN',
        urgent: true,
        humanHandoffRequested: true,
        productsOfInterest: const ['Monitor 4K'],
        painPoints: const ['Pantalla rota'],
        objections: const ['Demora en envío'],
        nextRecommendedAction: 'Llamar al cliente',
        confidenceScore: 0.88,
        extractedAt: DateTime(2026, 10, 15, 12, 0),
      );

      final json = original.toJson();
      final restored = ConversationIntelligenceProfile.fromJson(json);

      expect(restored.conversationId, original.conversationId);
      expect(restored.leadQuality, original.leadQuality);
      expect(restored.budgetMentioned, original.budgetMentioned);
      expect(restored.currency, original.currency);
      expect(restored.urgent, original.urgent);
      expect(restored.humanHandoffRequested, original.humanHandoffRequested);
      expect(restored.productsOfInterest, original.productsOfInterest);
      expect(restored.painPoints, original.painPoints);
      expect(restored.objections, original.objections);
      expect(restored.nextRecommendedAction, original.nextRecommendedAction);
      expect(restored.confidenceScore, original.confidenceScore);
      expect(restored.extractedAt, original.extractedAt);
    });
  });
}

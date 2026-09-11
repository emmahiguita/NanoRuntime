import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/fact_selector.dart';
import 'package:nanoai/features/automation/personal_agent/domain/conversation_agent_role.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_draft_prompt.dart';

void main() {
  group('FASE 17 — Pruebas de Inyeccion de Hechos y Tono', () {
    const fullFacts = BusinessFacts(
      products: [
        BusinessProduct(
          id: 's24',
          name: 'Galaxy S24',
          details: 'negro 256GB',
          price: 899000,
          stock: 3,
        ),
        BusinessProduct(
          id: 'cam_l',
          name: 'Camiseta Oversize',
          details: 'Negra talla L',
          price: 85000,
          stock: 4,
        ),
      ],
      hours: 'Lunes a Sabado de 8:00 AM a 7:00 PM',
      delivery: 'Medellin y Envigado, costo segun zona',
      payments: 'Nequi 300XXXXXXX o Bancolombia ahorros',
      location: 'Medellin, Laureles',
    );

    test('Caso 1: Cuanto vale el negro? -> FactSelector incluye Galaxy S24 negro', () {
      final selection = selectFactsForMessage('¿Cuanto vale el negro?', fullFacts);
      expect(selection.products.length, equals(1));
      final prod = selection.products.first;
      expect(prod.name, equals('Galaxy S24'));
      expect(prod.details, contains('negro'));
      expect(prod.price, equals(899000));
      expect(prod.stock, equals(3));
    });

    test('Caso 2: Como pago? -> incluye payments, NO catalogo irrelevante', () {
      final selection = selectFactsForMessage('¿Como pago?', fullFacts);
      expect(selection.payments, equals('Nequi 300XXXXXXX o Bancolombia ahorros'));
      expect(selection.products, isEmpty);
      expect(selection.hours, isEmpty);
      expect(selection.location, isEmpty);
    });

    test('Caso 3: Donde estan? -> incluye location, NO catalogo irrelevante', () {
      final selection = selectFactsForMessage('¿Donde estan?', fullFacts);
      expect(selection.location, equals('Medellin, Laureles'));
      expect(selection.products, isEmpty);
      expect(selection.payments, isEmpty);
    });

    test('Caso 4: Mensaje personal ("Parce, como estas?") -> NO business facts, NO tono comercial', () {
      final routing = routeConversationAgent(
        messageText: 'Parce, ¿cómo estás?',
        facts: fullFacts,
        hasRelationship: true,
        hasActiveProduct: false,
      );

      expect(routing.role, anyOf(ConversationAgentRole.personal, ConversationAgentRole.general));
      expect(routing.commercialIntent, isFalse);

      final isCommercial = (routing.role == ConversationAgentRole.sales || routing.commercialIntent);
      final business = isCommercial ? fullFacts.formatPromptBlock() : '';
      final tone = isCommercial ? '<TONO DE RESPUESTA>Persuasivo</TONO DE RESPUESTA>' : null;

      expect(business, isEmpty);
      expect(tone, isNull);

      final prompt = conversationSocialPromptFor(
        text: 'Parce, ¿cómo estás?',
        tone: tone,
        history: '(sin historial previo)',
      );

      expect(prompt.contains('<DATOS DEL NEGOCIO>'), isFalse);
      expect(prompt.contains('Persuasivo'), isFalse);
    });

    test('Caso 5: Tienen camiseta negra talla L y cuanto vale? -> conserva producto, variante, precio y stock', () {
      final selection = selectFactsForMessage('¿Tienen camiseta negra talla L y cuanto vale?', fullFacts);
      expect(selection.products.length, equals(1));
      final p = selection.products.first;
      expect(p.name, equals('Camiseta Oversize'));
      expect(p.details, equals('Negra talla L'));
      expect(p.price, equals(85000));
      expect(p.stock, equals(4));

      final renderedBlock = selection.render();
      expect(renderedBlock, contains('Camiseta Oversize (Negra talla L): \$85.000 (stock 4 disponible)'));
    });

    test('Caso 6: Sin datos de pago -> Como te pago? -> FactSelector NO inventa Nequi ni cuenta', () {
      const factsWithoutPayment = BusinessFacts(
        products: [
          BusinessProduct(
            id: 's24',
            name: 'Galaxy S24',
            details: 'negro 256GB',
            price: 899000,
            stock: 3,
          ),
        ],
        hours: '8am - 6pm',
        delivery: 'Envio gratis',
        payments: '',
        location: 'Local 12',
      );

      final selection = selectFactsForMessage('¿Como te pago?', factsWithoutPayment);
      expect(selection.payments, isEmpty);

      final block = selection.render();
      expect(block.contains('Metodos de pago'), isFalse);
      expect(block.contains('Nequi'), isFalse);
      expect(block.contains('Bancolombia'), isFalse);
    });
  });
}

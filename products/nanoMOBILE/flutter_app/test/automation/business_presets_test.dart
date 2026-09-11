import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/business/business_facts.dart';
import 'package:nanoai/features/automation/engine/business/business_presets.dart';
import 'package:nanoai/features/automation/engine/business/fact_selector.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';

void main() {
  group('BusinessPresetsCatalog', () {
    test('contains 5 standard presets covering primary industry archetypes', () {
      final presets = BusinessPresetsCatalog.presets;
      expect(presets.length, equals(5));

      final ids = presets.map((p) => p.id).toSet();
      expect(ids, containsAll(['retail', 'restaurant', 'services', 'clinic', 'courses']));
    });

    test('each preset defines valid metadata and a complete commercial ToneProfile', () {
      for (final preset in BusinessPresetsCatalog.presets) {
        expect(preset.id, isNotEmpty);
        expect(preset.title, isNotEmpty);
        expect(preset.description, isNotEmpty);

        final tone = preset.tone;
        expect(tone.enabled, isTrue);
        expect(tone.sales, anyOf(ToneSales.persuasivo, ToneSales.natural));
        expect(tone.warmth, anyOf(ToneWarmth.cercano, ToneWarmth.formal));
        expect(tone.verbosity, anyOf(ToneVerbosity.breve, ToneVerbosity.media, ToneVerbosity.extensa));
      }
    });

    test('presets do NOT inject fake phone numbers, fake accounts, or fake addresses', () {
      for (final preset in BusinessPresetsCatalog.presets) {
        final payments = preset.facts.payments.toLowerCase();
        final location = preset.facts.location.toLowerCase();

        // Sin teléfonos o cuentas inventadas tipo 300XXXXXXX
        expect(payments.contains('300'), isFalse, reason: 'Fake phone in ${preset.id}');
        expect(payments.contains('310'), isFalse, reason: 'Fake phone in ${preset.id}');
        expect(payments.contains('320'), isFalse, reason: 'Fake phone in ${preset.id}');

        // Sin direcciones de ejemplo inventadas
        expect(location.contains('calle 10'), isFalse, reason: 'Fake street in ${preset.id}');
        expect(location.contains('carrera 15'), isFalse, reason: 'Fake avenue in ${preset.id}');
      }
    });

    test('FactSelector deterministically selects products, variants, price and stock', () {
      const facts = BusinessFacts(
        products: [
          BusinessProduct(
            id: 'cam_negra',
            name: 'Camiseta Básica',
            details: 'Negra talla L',
            price: 85000,
            stock: 4,
          ),
          BusinessProduct(
            id: 'gorra_azul',
            name: 'Gorra Clásica',
            details: 'Azul marino',
            price: 45000,
            stock: 2,
          ),
        ],
        hours: 'Lunes a Sábado de 8:00 AM a 7:00 PM',
        delivery: 'Medellín y Envigado, costo según zona',
        payments: 'Nequi al 300XXXXXXX o Bancolombia',
        location: 'Medellín, Laureles',
      );

      // Consulta por producto específico y color
      final sel = selectFactsForMessage('¿Tienen camiseta negra L?', facts);
      expect(sel.products.length, equals(1));
      expect(sel.products.first.name, equals('Camiseta Básica'));
      expect(sel.products.first.details, equals('Negra talla L'));
      expect(sel.products.first.price, equals(85000));
      expect(sel.products.first.stock, equals(4));

      // Consulta por precio
      final selPrice = selectFactsForMessage('¿Cuánto vale la gorra?', facts);
      expect(selPrice.products.length, equals(1));
      expect(selPrice.products.first.price, equals(45000));

      // Consulta por pago
      final selPay = selectFactsForMessage('¿Cómo te pago?', facts);
      expect(selPay.payments, equals('Nequi al 300XXXXXXX o Bancolombia'));
      expect(selPay.products, isEmpty);

      // Consulta por ubicación
      final selLoc = selectFactsForMessage('¿Dónde están ubicados?', facts);
      expect(selLoc.location, equals('Medellín, Laureles'));
      expect(selLoc.products, isEmpty);

      // Consulta por envío
      final selDeliv = selectFactsForMessage('¿Hacen domicilio a Envigado?', facts);
      expect(selDeliv.delivery, equals('Medellín y Envigado, costo según zona'));
    });

    test('FactSelector does NOT hallucinate payments or location when empty', () {
      const emptyFacts = BusinessFacts(
        products: [],
        hours: '',
        delivery: '',
        payments: '',
        location: '',
      );

      final paySel = selectFactsForMessage('Pásame el Nequi', emptyFacts);
      expect(paySel.payments, isEmpty);
      expect(paySel.isEmpty, isTrue);

      final locSel = selectFactsForMessage('¿Dónde queda el local?', emptyFacts);
      expect(locSel.location, isEmpty);
      expect(locSel.isEmpty, isTrue);
    });
  });
}

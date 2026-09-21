import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/domain/persona_example.dart';
import 'package:nanoai/core/providers/settings_provider.dart';

/// TESTS: PERSONA-VARIANTS & CONTACT-POLICY
///
/// QUÉ HACE:
/// Verifica que PersonaExample decodifique títulos y listas de 5+ variantes
/// de respuesta correctamente, y que SettingsState soporte los modos de contacto.
void main() {
  group('PersonaExample & Multi-Variant Dialogues', () {
    test('PersonaExample expone categoryTitle y variants correctamente', () {
      final variants = [
        '¡Hola! ¿Cómo estás hoy?',
        '¡Buenas! ¿Todo bien por allá?',
        'Hola, ¿qué tal?',
        '¡Hola! Cuéntame en qué te puedo colaborar.',
        'Buenas tardes, ¿cómo te va?',
      ];
      final example = PersonaExample(
        id: 1,
        personaKey: 'owner',
        body: variants.first,
        incomingText: 'Hola',
        tone: {
          'title': 'Saludos cordiales',
          'variants': jsonEncode(variants),
        },
      );

      expect(example.categoryTitle, 'Saludos cordiales');
      expect(example.variants.length, 5);
      expect(example.variants, equals(variants));
    });

    test('Fallback a [body] cuando variants no está configurado', () {
      const example = PersonaExample(
        id: 2,
        personaKey: 'owner',
        body: 'Hola, ¿cómo estás?',
        incomingText: 'Hola',
      );

      expect(example.categoryTitle, isEmpty);
      expect(example.variants, equals(['Hola, ¿cómo estás?']));
    });
  });

  group('SettingsState Contact Policy', () {
    test('waTargetContactsMode tiene default all y copyWith respeta cambios', () {
      const state = SettingsState();
      expect(state.waTargetContactsMode, 'all');

      final selectedState = state.copyWith(waTargetContactsMode: 'selected');
      expect(selectedState.waTargetContactsMode, 'selected');
    });
  });
}

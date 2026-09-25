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

    test('Modo selectivo vs universal distingue bot vs humano determinista', () {
      // Simula evaluación de contacto en modo 'selected'
      bool isBotActive({
        required String targetMode,
        required String contactName,
        String? owner,
      }) {
        final isEmm = contactName.toLowerCase().contains('emm') ||
            contactName.toLowerCase().contains('emma');
        if (targetMode == 'selected') {
          return (owner == 'bot') || (owner != 'human' && isEmm);
        } else {
          return owner != 'human';
        }
      }

      // En modo selectivo:
      // 1. Emm está activo por defecto (owner == null)
      expect(isBotActive(targetMode: 'selected', contactName: 'Emm'), isTrue);
      expect(isBotActive(targetMode: 'selected', contactName: 'Emma'), isTrue);

      // 2. Emm pausado explícitamente (owner == 'human') no debe responder
      expect(isBotActive(targetMode: 'selected', contactName: 'Emm', owner: 'human'), isFalse);

      // 3. Otro contacto no seleccionado (owner == null) no debe responder
      expect(isBotActive(targetMode: 'selected', contactName: 'Carlos'), isFalse);

      // 4. Otro contacto seleccionado (owner == 'bot') responde
      expect(isBotActive(targetMode: 'selected', contactName: 'Carlos', owner: 'bot'), isTrue);

      // En modo universal ('all'):
      // 1. Todos responden por defecto
      expect(isBotActive(targetMode: 'all', contactName: 'Carlos'), isTrue);
      expect(isBotActive(targetMode: 'all', contactName: 'Emm'), isTrue);

      // 2. Solo los pausados manualmente (owner == 'human') se silencian
      expect(isBotActive(targetMode: 'all', contactName: 'Carlos', owner: 'human'), isFalse);
    });
  });
}

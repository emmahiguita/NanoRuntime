import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/language/turn_complexity_classifier.dart';

void main() {
  group('TurnComplexityClassifier WA-CONV-UNDERSTANDING-01', () {
    const classifier = TurnComplexityClassifier();

    test('Saludo o reacción social pura es elegible para prompt social mínimo', () {
      final c1 = classifier.classify('Hola');
      expect(c1.isSocialMinimal, isTrue);
      expect(c1.eligibleForSocialPrompt, isTrue);

      final c2 = classifier.classify('Buenos días Emma');
      expect(c2.isSocialMinimal, isTrue);
      expect(c2.eligibleForSocialPrompt, isTrue);

      final c3 = classifier.classify('Muchas gracias!');
      expect(c3.isSocialMinimal, isTrue);
      expect(c3.eligibleForSocialPrompt, isTrue);
    });

    test('Turno narrativo bloquea el prompt social mínimo', () {
      final result = classifier.classify('Hola como estas, salí al gym y luego fui a trabajar');
      expect(result.isNarrative, isTrue);
      expect(result.eligibleForSocialPrompt, isFalse);
    });

    test('Pregunta sobre actividad bloquea el prompt social mínimo', () {
      final result = classifier.classify('¿Vas a rapear hoy?');
      expect(result.isNarrative, isTrue);
      expect(result.eligibleForSocialPrompt, isFalse);
    });

    test('Pregunta contextual anafórica bloquea el prompt social mínimo', () {
      final result = classifier.classify('¿Y sobre eso qué dijiste?');
      expect(result.isContextual, isTrue);
      expect(result.eligibleForSocialPrompt, isFalse);
    });

    test('Turno complejo multicláusula bloquea el prompt social mínimo', () {
      final result = classifier.classify('Hola, ¿a qué hora abren hoy y cuánto cuesta el servicio?');
      expect(result.eligibleForSocialPrompt, isFalse);
    });
  });
}

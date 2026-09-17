import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_style_constraints.dart';
import 'package:nanoai/features/automation/personal_agent/application/personal_style_seed.dart';
import 'package:nanoai/features/automation/personal_agent/domain/personal_memory.dart';

void main() {
  group('Personal Style Constraints & Seed Dataset (Aprendizaje vs Hardcoding)', () {
    test('PersonalStyleConstraints define reglas duras del dueño para el LLM', () {
      const constraints = PersonalStyleConstraints.defaultEmmanuel;
      expect(constraints.maxTypicalSentences, 2);
      expect(constraints.preferredAnswerLength, 'short');
      expect(constraints.preferredReciprocity, isTrue);

      expect(constraints.preferredExpressions, contains('gracias a Dios'));
      expect(constraints.preferredExpressions, contains('¿y tú?'));
      expect(constraints.preferredExpressions, contains('dale'));
      expect(constraints.preferredExpressions, contains('listo'));
      expect(constraints.preferredExpressions, contains('hagámosle'));

      // Reglas negativas anti-asistente corporativo
      expect(constraints.avoidExpressions, contains('por supuesto'));
      expect(constraints.avoidExpressions, contains('será un placer'));
      expect(constraints.avoidExpressions, contains('¿en qué más puedo ayudarte?'));
      expect(constraints.avoidExpressions, contains('entiendo perfectamente'));

      final instruction = constraints.toPromptInstruction();
      expect(instruction, contains('Máximo 2 frases'));
      expect(instruction, contains('Prohibido terminantemente'));
      expect(instruction, contains('¿y tú?'));
    });

    test('personalStyleSeedPairs contiene pares contextuales (entrada -> respuesta) de Emmanuel', () {
      expect(personalStyleSeedPairs.length, greaterThanOrEqualTo(25));

      for (final pair in personalStyleSeedPairs) {
        expect(pair.incoming.trim().isNotEmpty, isTrue);
        expect(pair.body.trim().isNotEmpty, isTrue);
      }

      // Verifica cobertura de intenciones clave en pares
      final hasWellbeing = personalStyleSeedPairs.any((p) => p.incoming.contains('Cómo estás') && p.body.contains('gracias a Dios'));
      expect(hasWellbeing, isTrue);

      final hasActivity = personalStyleSeedPairs.any((p) => p.incoming.contains('Qué haces') && p.body.contains('haciendo unas cosas'));
      expect(hasActivity, isTrue);

      final hasRap = personalStyleSeedPairs.any((p) => p.incoming.toLowerCase().contains('rapear') && p.body.toLowerCase().contains('rapear'));
      expect(hasRap, isTrue);

      final hasDecline = personalStyleSeedPairs.any((p) => p.body.contains('Hoy no creo') || p.body.contains('No creo que pueda'));
      expect(hasDecline, isTrue);
    });

    test('PersonalMemory modela estilo y preferencias de corrección correctamente', () {
      final memory = PersonalMemory(
        id: 101,
        scopeKey: 'owner',
        key: 'correccion_estilo',
        value: 'Preferir "si, quiero ir" sobre "Sí, claro. Me gustaría ir."',
        kind: 'stylePreference',
        observedAt: DateTime.now().millisecondsSinceEpoch,
        metadata: const {
          'suggested': 'Sí, claro. Me gustaría ir.',
          'corrected': 'si, quiero ir',
          'input': '¿Quieres rapear hoy?',
        },
      );

      expect(memory.kind, 'stylePreference');
      expect(memory.enabled, isTrue);
      expect(memory.expired, isFalse);
      expect(memory.metadata['suggested'], contains('Me gustaría'));
      expect(memory.metadata['corrected'], contains('quiero ir'));
    });
  });
}

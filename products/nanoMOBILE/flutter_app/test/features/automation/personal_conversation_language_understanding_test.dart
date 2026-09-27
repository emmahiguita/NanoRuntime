import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/language/dialogue_state.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_draft_prompt.dart';

void main() {
  group('comprensión lingüística del Agente Personal', () {
    test('atribuye primera persona y pasado al remitente', () {
      final signals = linguisticAnalyzer.analyze('Yo ya fui a Cali ayer.');

      expect(signals.grammaticalPerson, 'primera_persona_singular');
      expect(signals.tense, 'pasado');
      expect(signals.temporalAspect, 'pretérito');
      expect(signals.promptHint, contains('persona=primera_persona_singular'));
    });

    test('conserva aspectos verbales y turnos con pasado y futuro', () {
      final mixed = linguisticAnalyzer.analyze(
        'Ya te dije que mañana compraré el pasaje.',
      );
      final ongoing = linguisticAnalyzer.analyze(
        'Yo estaba trabajando cuando tú llamaste.',
      );
      final completedBeforeAnotherPast = linguisticAnalyzer.analyze(
        'Yo ya había hablado contigo.',
      );

      expect(mixed.tense, 'mixto');
      expect(mixed.temporalAspect, 'pasado_y_futuro');
      expect(mixed.grammaticalPerson, 'primera_persona_singular');
      expect(ongoing.tense, 'pasado');
      expect(ongoing.temporalAspect, 'imperfecto_y_pretérito');
      expect(ongoing.grammaticalPerson, 'mixta');
      expect(completedBeforeAnotherPast.temporalAspect, 'pluscuamperfecto');
    });

    test('reconoce segunda persona y perífrasis de futuro', () {
      final past = linguisticAnalyzer.analyze('¿Ya compraste el boleto?');
      final future = linguisticAnalyzer.analyze('Mañana voy a confirmarte.');
      final pluralPast = linguisticAnalyzer.analyze('Nosotros fuimos ayer.');
      final scheduledPresent = linguisticAnalyzer.analyze(
        'Mañana te confirmo.',
      );

      expect(past.grammaticalPerson, 'segunda_persona_singular');
      expect(past.tense, 'pasado');
      expect(future.grammaticalPerson, 'primera_persona_singular');
      expect(future.tense, 'futuro');
      expect(future.temporalAspect, 'perífrasis_ir_a_infinitivo');
      expect(pluralPast.grammaticalPerson, 'primera_persona_plural');
      expect(scheduledPresent.grammaticalPerson, 'primera_persona_singular');
      expect(scheduledPresent.tense, 'futuro');
      expect(scheduledPresent.temporalAspect, 'anclaje_temporal_futuro');
    });

    test('deja indeterminados los saludos sin verbo', () {
      final signals = linguisticAnalyzer.analyze('Hola');

      expect(signals.tense, 'indeterminado');
      expect(signals.grammaticalPerson, 'indeterminada');
      expect(signals.promptHint, isNull);
    });

    test('el prompt conserva autor, perspectiva y tiempo de cada turno', () {
      final prompt = conversationAgentPromptFor(
        history: 'Cliente: Ya fui a Cali ayer.\nDueño: Te cuento mañana.',
        text: 'Yo ya fui a Cali ayer.',
      );

      expect(prompt, contains('"yo/me/nosotros" pertenece al remitente'));
      expect(prompt, contains('pertenece al autor de la línea'));
      expect(prompt, contains('no contestes a "ya fui ayer"'));
    });
  });
}

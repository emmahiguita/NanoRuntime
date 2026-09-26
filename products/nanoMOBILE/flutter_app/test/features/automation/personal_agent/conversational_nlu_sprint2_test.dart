// conversational_nlu_sprint2_test.dart
//
// QUÉ HACE:
// Suite de pruebas exhaustiva para el NLU Híbrido, Clasificación de Cláusulas,
// Catálogo de Intenciones, Matriz de Confusión y Casos Adversariales de Nano Personal (Sprint 2).
//
// CÓMO FUNCIONA:
// - Evalúa un corpus cerrado de >120 enunciados (con tildes, sin tildes, jerga colombiana, abreviaciones).
// - Evalúa un dataset adversarial de >40 casos trampa (falsos amigos semánticos, polaridades, estados vivos).
// - Evalúa generalización sobre paráfrasis no vistas (unseen paraphrases).
// - Calcula y reporta la matriz de confusión, precisión, recall y latencias con Stopwatch.
//
// POR QUÉ:
// Verifica determinísticamente y offline la comprensión semántica sin requerir hardware ni LLM externo.

// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/language/conversational_intent_classifier.dart';
import 'package:nanoai/features/automation/engine/language/intent_prediction.dart';
import 'package:nanoai/features/automation/personal_agent/application/hybrid_retrieval_scorer.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_retriever.dart';
import 'package:nanoai/features/automation/personal_agent/application/personalization_scope_resolver.dart';
import 'package:nanoai/features/automation/personal_agent/domain/persona_example.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const classifier = ConversationalIntentClassifier();
  const scorer = HybridRetrievalScorer();

  group('Sprint 2 — Requisitos Mínimos Unitarios (Sección 25)', () {
    test('IntentClassifier exact: clasifica disparadores literales', () {
      final res = classifier.classify('cómo estás');
      expect(res.primaryIntent.intentId, equals('wellbeing_question'));
      expect(res.primaryIntent.confidence, greaterThanOrEqualTo(0.90));
    });

    test('IntentClassifier paraphrase: reconoce variantes sin tokens idénticos', () {
      final res1 = classifier.classify('cómo andas');
      final res2 = classifier.classify('cómo te trata el día');
      expect(res1.primaryIntent.intentId, equals('wellbeing_question'));
      expect(res2.primaryIntent.intentId, equals('wellbeing_question'));
    });

    test('IntentClassifier negation: extrae polaridad negativa e incertidumbre', () {
      final pos = classifier.classify('sí voy');
      final neg = classifier.classify('no voy');
      final unc = classifier.classify('todavía no sé si voy');

      expect(pos.primaryIntent.polarity, equals(IntentPolarity.positive));
      expect(neg.primaryIntent.polarity, equals(IntentPolarity.negative));
      expect(unc.primaryIntent.polarity, equals(IntentPolarity.uncertain));
    });

    test('IntentClassifier correction: activa needsContext y bloquea match ciego', () {
      final res = classifier.classify('no, yo decía lo otro');
      expect(res.primaryIntent.intentId, equals('correction'));
      expect(res.primaryIntent.needsContext, isTrue);
    });

    test('IntentClassifier contextual: detecta anáforas y elipsis', () {
      final res1 = classifier.classify('y vos?');
      final res2 = classifier.classify('lo de ayer');
      expect(res1.primaryIntent.intentId, equals('context_reference'));
      expect(res1.primaryIntent.needsContext, isTrue);
      expect(res2.primaryIntent.intentId, equals('context_reference'));
      expect(res2.primaryIntent.needsContext, isTrue);
    });

    test('IntentClassifier ambiguity: detecta margen estrecho entre intenciones', () {
      // Un enunciado limítrofe entre saludo y pregunta de actividad
      final res = classifier.classify('hola qué haces hoy');
      expect(res.clausePredictions.length, greaterThanOrEqualTo(2));
      expect(res.primaryIntent.intentId, equals('activity_question'));
      expect(res.secondaryIntents.any((s) => s.intentId == 'greeting'), isTrue);
    });

    test('PersonaRetriever stored variant: puntúa alto variantes aprendidas', () {
      const example = PersonaExample(
        id: 10,
        personaKey: 'owner',
        body: 'Bien gracias a Dios',
        incomingText: 'cómo estás',
        tone: {
          'intent': 'wellbeing_question',
          'incomingVariants': '["cómo vas","qué tal","todo bien"]',
        },
      );
      final score = PersonaRetriever.scoreExample('cómo vas', example);
      expect(score, greaterThan(0.60));
    });

    test('PersonaRetriever unseen paraphrase: puntúa alto paráfrasis no vista', () {
      const example = PersonaExample(
        id: 11,
        personaKey: 'owner',
        body: 'Todo bien por acá',
        incomingText: 'cómo estás',
        tone: {'intent': 'wellbeing_question'},
      );
      final score = PersonaRetriever.scoreExample('cómo te ha ido', example);
      expect(score, greaterThan(0.50));
    });

    test('Live-state rejection: penaliza y bloquea reutilización en estado vivo', () {
      const example = PersonaExample(
        id: 12,
        personaKey: 'owner',
        body: 'Aquí en casa descansando',
        incomingText: 'dónde estás',
        source: 'manual', // No es 'live_verified'
        tone: {'intent': 'location_question'},
      );
      final pred = classifier.classify('dónde estás').primaryIntent;
      expect(pred.requiresLiveState, isTrue);

      final score = scorer.score(
        rawInput: 'dónde estás',
        example: example,
        inputPrediction: pred,
      );
      // Penalizado por guardia de estado vivo (x 0.20)
      expect(score, lessThan(0.35));
    });

    test('scope priority regression: preserva precedencia contacto > role > owner > global', () async {
      const resolver = CanonicalPersonalizationScopeResolver();
      final scopes = await resolver.resolveScopes(
        conversationId: '123456789@s.whatsapp.net',
        senderId: '+573001234567',
      );
      expect(scopes.first, startsWith('contact:'));
      expect(scopes, contains('role:personal'));
      expect(scopes, contains('owner'));
      expect(scopes, contains('global'));
      expect(scopes.indexOf('role:personal'), lessThan(scopes.indexOf('owner')));
      expect(scopes.indexOf('owner'), lessThan(scopes.indexOf('global')));
    });
  });

  group('Sprint 2 — Corpus de 120 Utterances y Matriz de Confusión', () {
    test('Evaluación masiva del corpus cerrado (>= 95% precisión esperada)', () {
      final corpus = _build120Corpus();
      expect(corpus.length, greaterThanOrEqualTo(120));

      var correct = 0;
      final total = corpus.length;
      final classStats = <String, _IntentStat>{};
      final confusions = <String, int>{};

      final sw = Stopwatch()..start();
      for (final item in corpus) {
        final text = item.text;
        final expected = item.expectedIntent;

        final stat = classStats.putIfAbsent(expected, () => _IntentStat(expected));
        stat.total++;

        final pred = classifier.classify(text).primaryIntent;
        if (pred.intentId == expected) {
          correct++;
          stat.correct++;
        } else {
          stat.incorrect++;
          final confKey = '$expected -> ${pred.intentId} ("$text")';
          confusions[confKey] = (confusions[confKey] ?? 0) + 1;
        }
      }
      sw.stop();

      final accuracy = (correct / total) * 100.0;
      final avgLatencyMs = (sw.elapsedMicroseconds / 1000.0) / total;

      print('\n======================================================');
      print('RESULTADOS DE CLASIFICACIÓN — SPRINT 2 (CORPUS 120+)');
      print('Total evaluado: $total enunciados');
      print('Correctos: $correct | Incorrectos: ${total - correct}');
      print('Exactitud (Accuracy): ${accuracy.toStringAsFixed(2)}%');
      print('Latencia promedio por inferencia: ${avgLatencyMs.toStringAsFixed(3)} ms');
      print('------------------------------------------------------');
      print('DESGLOSE POR INTENCIÓN:');
      for (final s in classStats.values) {
        final prec = s.total > 0 ? (s.correct / s.total) * 100.0 : 0.0;
        print('  - ${s.intent.padRight(28)} | Total: ${s.total.toString().padLeft(2)} | Correctos: ${s.correct.toString().padLeft(2)} | Precisión: ${prec.toStringAsFixed(1)}%');
      }
      if (confusions.isNotEmpty) {
        print('------------------------------------------------------');
        print('CONFUSIONES REGISTRADAS (${confusions.length}):');
        for (final entry in confusions.entries) {
          print('  * ${entry.key} [${entry.value}]');
        }
      }
      print('======================================================\n');

      expect(accuracy, greaterThanOrEqualTo(95.0),
          reason: 'El NLU Híbrido debe alcanzar al menos 95% en el corpus cerrado');
    });
  });

  group('Sprint 2 — Dataset Adversarial (40 Casos Trampa)', () {
    test('Protección contra falsos amigos sintácticos y colisiones léxicas', () {
      final adversarials = _build40AdversarialCases();
      expect(adversarials.length, greaterThanOrEqualTo(40));

      var passed = 0;
      for (final item in adversarials) {
        final pred = classifier.classify(item.text).primaryIntent;
        if (pred.intentId == item.expectedIntent) {
          passed++;
        } else {
          print('Fallo adversarial: "${item.text}" esperó ${item.expectedIntent} pero obtuvo ${pred.intentId}');
        }
      }

      final rate = (passed / adversarials.length) * 100.0;
      print('\n======================================================');
      print('RESULTADOS ADVERSARIALES (40 CASOS TRAMPA):');
      print('Superados: $passed / ${adversarials.length} (${rate.toStringAsFixed(1)}%)');
      print('======================================================\n');

      expect(rate, greaterThanOrEqualTo(90.0));
    });
  });
}

final class _CorpusItem {
  final String text;
  final String expectedIntent;
  const _CorpusItem(this.text, this.expectedIntent);
}

final class _IntentStat {
  final String intent;
  int total = 0;
  int correct = 0;
  int incorrect = 0;
  _IntentStat(this.intent);
}

List<_CorpusItem> _build120Corpus() => const [
  // 1. greeting (12)
  _CorpusItem('hola', 'greeting'),
  _CorpusItem('hola bro', 'greeting'),
  _CorpusItem('buenas', 'greeting'),
  _CorpusItem('buenas tardes', 'greeting'),
  _CorpusItem('buenos dias', 'greeting'),
  _CorpusItem('buen dia', 'greeting'),
  _CorpusItem('hey parcero', 'greeting'),
  _CorpusItem('quiubo mano', 'greeting'),
  _CorpusItem('oe', 'greeting'),
  _CorpusItem('holaaa buenas', 'greeting'),
  _CorpusItem('q mas', 'greeting'),
  _CorpusItem('hola que tal', 'greeting'),

  // 2. farewell (10)
  _CorpusItem('chao', 'farewell'),
  _CorpusItem('chao parce', 'farewell'),
  _CorpusItem('hasta luego', 'farewell'),
  _CorpusItem('nos vemos', 'farewell'),
  _CorpusItem('hablamos luego', 'farewell'),
  _CorpusItem('hablamos mano', 'farewell'),
  _CorpusItem('que descanses', 'farewell'),
  _CorpusItem('hasta manana', 'farewell'),
  _CorpusItem('adios', 'farewell'),
  _CorpusItem('chaito pues', 'farewell'),

  // 3. gratitude (10)
  _CorpusItem('gracias', 'gratitude'),
  _CorpusItem('muchas gracias', 'gratitude'),
  _CorpusItem('mil gracias', 'gratitude'),
  _CorpusItem('te agradezco', 'gratitude'),
  _CorpusItem('se agradece mano', 'gratitude'),
  _CorpusItem('grx', 'gratitude'),
  _CorpusItem('gracias parce', 'gratitude'),
  _CorpusItem('muchisimas gracias', 'gratitude'),
  _CorpusItem('muy amable gracias', 'gratitude'),
  _CorpusItem('gracias bro', 'gratitude'),

  // 4. wellbeing_question (15)
  _CorpusItem('cómo estás', 'wellbeing_question'),
  _CorpusItem('como estas', 'wellbeing_question'),
  _CorpusItem('cómo vas', 'wellbeing_question'),
  _CorpusItem('como vas', 'wellbeing_question'),
  _CorpusItem('todo bien?', 'wellbeing_question'),
  _CorpusItem('todo bien', 'wellbeing_question'),
  _CorpusItem('todo bn?', 'wellbeing_question'),
  _CorpusItem('qué tal', 'wellbeing_question'),
  _CorpusItem('que tal', 'wellbeing_question'),
  _CorpusItem('cómo te ha ido', 'wellbeing_question'),
  _CorpusItem('como te ha ido', 'wellbeing_question'),
  _CorpusItem('cómo andas', 'wellbeing_question'),
  _CorpusItem('como andas', 'wellbeing_question'),
  _CorpusItem('q mas como vas', 'wellbeing_question'),
  _CorpusItem('cómo sigue todo', 'wellbeing_question'),

  // 5. activity_question (10)
  _CorpusItem('qué haces', 'activity_question'),
  _CorpusItem('que haces', 'activity_question'),
  _CorpusItem('qué estás haciendo', 'activity_question'),
  _CorpusItem('que estas haciendo', 'activity_question'),
  _CorpusItem('en qué andas', 'activity_question'),
  _CorpusItem('en que andas', 'activity_question'),
  _CorpusItem('que andas haciendo hoy', 'activity_question'),
  _CorpusItem('que se dice que haces', 'activity_question'),
  _CorpusItem('que estas haciendo bro', 'activity_question'),
  _CorpusItem('en que andas ocupado', 'activity_question'),

  // 6. availability_question (10)
  _CorpusItem('vas a salir hoy?', 'availability_question'),
  _CorpusItem('estás libre?', 'availability_question'),
  _CorpusItem('estas libre', 'availability_question'),
  _CorpusItem('tienes tiempo?', 'availability_question'),
  _CorpusItem('tienes tiempo ahorita', 'availability_question'),
  _CorpusItem('puedes hablar?', 'availability_question'),
  _CorpusItem('puedes hablar un momento', 'availability_question'),
  _CorpusItem('vas a entrenar?', 'availability_question'),
  _CorpusItem('vas a ir manana?', 'availability_question'),
  _CorpusItem('vas a venir?', 'availability_question'),

  // 7. location_question (10)
  _CorpusItem('dónde estás?', 'location_question'),
  _CorpusItem('donde estas', 'location_question'),
  _CorpusItem('en dónde andas?', 'location_question'),
  _CorpusItem('en donde andas', 'location_question'),
  _CorpusItem('por dónde andas?', 'location_question'),
  _CorpusItem('por donde andas', 'location_question'),
  _CorpusItem('estás en casa?', 'location_question'),
  _CorpusItem('estas en casa', 'location_question'),
  _CorpusItem('donde estas metido', 'location_question'),
  _CorpusItem('donde estas bro', 'location_question'),

  // 8. meeting_time_question (10)
  _CorpusItem('a qué hora?', 'meeting_time_question'),
  _CorpusItem('a que hora', 'meeting_time_question'),
  _CorpusItem('qué hora entonces?', 'meeting_time_question'),
  _CorpusItem('que hora entonces', 'meeting_time_question'),
  _CorpusItem('a qué horas nos vemos?', 'meeting_time_question'),
  _CorpusItem('a que horas quedamos', 'meeting_time_question'),
  _CorpusItem('tipo qué hora?', 'meeting_time_question'),
  _CorpusItem('tipo que hora', 'meeting_time_question'),
  _CorpusItem('a que hora pasas?', 'meeting_time_question'),
  _CorpusItem('a que hora seria?', 'meeting_time_question'),

  // 9. meeting_time_answer (8)
  _CorpusItem('a las 5', 'meeting_time_answer'),
  _CorpusItem('a las cinco', 'meeting_time_answer'),
  _CorpusItem('tipo 5', 'meeting_time_answer'),
  _CorpusItem('a las 3 pm', 'meeting_time_answer'),
  _CorpusItem('tipo 4 de la tarde', 'meeting_time_answer'),
  _CorpusItem('a las 6', 'meeting_time_answer'),
  _CorpusItem('como a las 7', 'meeting_time_answer'),
  _CorpusItem('a las 8 nos vemos', 'meeting_time_answer'),

  // 10. confirmation (10)
  _CorpusItem('sí', 'confirmation'),
  _CorpusItem('si', 'confirmation'),
  _CorpusItem('sip', 'confirmation'),
  _CorpusItem('dale', 'confirmation'),
  _CorpusItem('de una', 'confirmation'),
  _CorpusItem('listo', 'confirmation'),
  _CorpusItem('claro que si', 'confirmation'),
  _CorpusItem('de una parce', 'confirmation'),
  _CorpusItem('listo bro', 'confirmation'),
  _CorpusItem('dale de una', 'confirmation'),

  // 11. negation (10)
  _CorpusItem('no', 'negation'),
  _CorpusItem('nop', 'negation'),
  _CorpusItem('no voy', 'negation'),
  _CorpusItem('creo que no', 'negation'),
  _CorpusItem('no creo', 'negation'),
  _CorpusItem('no voy a poder', 'negation'),
  _CorpusItem('para nada', 'negation'),
  _CorpusItem('tampoco', 'negation'),
  _CorpusItem('no parce', 'negation'),
  _CorpusItem('no puedo', 'negation'),

  // 12. correction (8)
  _CorpusItem('no, yo decía lo otro', 'correction'),
  _CorpusItem('no era eso', 'correction'),
  _CorpusItem('me refería a mañana', 'correction'),
  _CorpusItem('no te pregunté eso', 'correction'),
  _CorpusItem('no yo decia lo de ayer', 'correction'),
  _CorpusItem('me referia al otro tema', 'correction'),
  _CorpusItem('no era eso lo que decia', 'correction'),
  _CorpusItem('no yo decia lo de la cita', 'correction'),

  // 13. context_reference (8)
  _CorpusItem('y vos?', 'context_reference'),
  _CorpusItem('y tu?', 'context_reference'),
  _CorpusItem('lo de ayer', 'context_reference'),
  _CorpusItem('vas?', 'context_reference'),
  _CorpusItem('y a que hora?', 'context_reference'),
  _CorpusItem('y vos que?', 'context_reference'),
  _CorpusItem('lo de la otra vez', 'context_reference'),
  _CorpusItem('y entonces?', 'context_reference'),

  // 14. project_status_question (8)
  _CorpusItem('cómo va el proyecto?', 'project_status_question'),
  _CorpusItem('como va la app?', 'project_status_question'),
  _CorpusItem('avanzaste en el codigo?', 'project_status_question'),
  _CorpusItem('como va el sistema?', 'project_status_question'),
  _CorpusItem('terminaste el proyecto?', 'project_status_question'),
  _CorpusItem('que tal va el codigo?', 'project_status_question'),
  _CorpusItem('avanzaste en la app?', 'project_status_question'),
  _CorpusItem('como va todo con el proyecto?', 'project_status_question'),
];

List<_CorpusItem> _build40AdversarialCases() => const [
  // 1-2. estás en casa (ubicación) vs cómo está tu casa (propiedad/familia)
  _CorpusItem('estás en casa', 'location_question'),
  _CorpusItem('cómo está tu casa', 'wellbeing_question'),

  // 3-4. todo bien? (bienestar) vs todo bien con el proyecto? (proyecto)
  _CorpusItem('todo bien?', 'wellbeing_question'),
  _CorpusItem('todo bien con el proyecto?', 'project_status_question'),

  // 5-6. qué tal (bienestar) vs qué tal Nano (proyecto/producto)
  _CorpusItem('qué tal', 'wellbeing_question'),
  _CorpusItem('qué tal el proyecto?', 'project_status_question'),

  // 7-10. Negaciones y matices de polaridad
  _CorpusItem('sí voy', 'confirmation'),
  _CorpusItem('no voy', 'negation'),
  _CorpusItem('creo que no', 'negation'),
  _CorpusItem('no creo que pueda ir', 'negation'),

  // 11-14. Correcciones vs afirmaciones
  _CorpusItem('no, yo decía lo otro', 'correction'),
  _CorpusItem('no era eso', 'correction'),
  _CorpusItem('me refería a mañana', 'correction'),
  _CorpusItem('no te pregunté eso', 'correction'),

  // 15-18. Elipsis y preguntas relativas
  _CorpusItem('y vos?', 'context_reference'),
  _CorpusItem('y tu?', 'context_reference'),
  _CorpusItem('vas?', 'context_reference'),
  _CorpusItem('lo de ayer', 'context_reference'),

  // 19-22. Hora vs respuestas de hora
  _CorpusItem('a qué hora?', 'meeting_time_question'),
  _CorpusItem('a las 5', 'meeting_time_answer'),
  _CorpusItem('tipo 5', 'meeting_time_answer'),
  _CorpusItem('a qué horas nos vemos?', 'meeting_time_question'),

  // 23-26. Disponibilidad vs actividad
  _CorpusItem('estás libre?', 'availability_question'),
  _CorpusItem('qué estás haciendo?', 'activity_question'),
  _CorpusItem('tienes tiempo?', 'availability_question'),
  _CorpusItem('en qué andas?', 'activity_question'),

  // 27-30. Saludos compuestos con preguntas
  _CorpusItem('hola cómo vas', 'wellbeing_question'),
  _CorpusItem('buenas qué haces', 'activity_question'),
  _CorpusItem('hola dónde estás', 'location_question'),
  _CorpusItem('quiubo a qué hora nos vemos', 'meeting_time_question'),

  // 31-34. Agradecimientos con despedidas
  _CorpusItem('muchas gracias chao', 'gratitude'),
  _CorpusItem('gracias hasta luego', 'gratitude'),
  _CorpusItem('mil gracias hablamos', 'gratitude'),
  _CorpusItem('grx', 'gratitude'),

  // 35-38. Proyectos y código
  _CorpusItem('avanzaste en la app?', 'project_status_question'),
  _CorpusItem('cómo va el código?', 'project_status_question'),
  _CorpusItem('terminaste el sistema?', 'project_status_question'),
  _CorpusItem('el proyecto cómo sigue?', 'project_status_question'),

  // 39-40. Despedidas cotidianas
  _CorpusItem('nos vemos al rato', 'farewell'),
  _CorpusItem('hablamos más tarde', 'farewell'),
];

/// PERSONAL-STYLE-SEED — Semilla Canónica de Intenciones y Múltiples Respuestas.
///
/// **QUÉ HACE:**
/// Define e inyecta la biblioteca de intenciones conversacionales de EMMA, vinculando
/// frases de entrada y variantes equivalentes con conjuntos de respuestas contextuales.
///
/// **CÓMO FUNCIONA:**
/// Almacena en SQLite las intenciones semánticas, variantes de entrada y opciones
/// de respuesta estructuradas con metadatos de tono y seguimiento (follow-up).
///
/// **POR QUÉ:**
/// Dota a Nano de flexibilidad conversacional natural, impidiendo que responda
/// de forma monótona o robótica (< 200 líneas).
library;

export 'personal_style_seed_pairs.dart';

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'emma_intent_seed_catalog.dart';
import 'persona_repository.dart';
import 'personal_reply_learning_service.dart';
import '../domain/persona_response_option.dart';

Future<int> ensurePersonalStyleSeed(
  PersonaRepository repo, {
  bool forceEnrich = false,
}) async {
  try {
    // Repara una vez los pares repetidos creados por versiones anteriores.
    await PersonalReplyLearningService(repository: repo).consolidateExisting();
    final existing = await repo.listExamples(limit: 60);
    final needsEnrich =
        forceEnrich ||
        existing.isEmpty ||
        existing.any((e) => e.variants.length <= 1);
    if (!needsEnrich) return 0;

    var count = 0;
    for (final seed in emmaCanonicalSeeds) {
      final matches = existing
          .where(
            (e) =>
                e.incomingText.trim() == seed.trigger ||
                e.incomingVariants.contains(seed.trigger),
          )
          .toList();
      final toneData = {
        'ownerVerified': 'true',
        'kind': 'paired',
        'title': seed.category,
        'category': seed.category,
        'intent': seed.intent,
        'incomingVariants': jsonEncode(seed.incomingVariants),
        'variants': jsonEncode(seed.responses.map((r) => r.text).toList()),
        'responses': jsonEncode(seed.responses.map((r) => r.toMap()).toList()),
      };
      if (matches.isNotEmpty) {
        await repo.updateExample(
          matches.first,
          body: seed.responses.first.text,
          incomingText: seed.trigger,
          tone: toneData,
        );
        count++;
      } else {
        final ok = await repo.addExample(
          personaKey: 'owner',
          incomingText: seed.trigger,
          body: seed.responses.first.text,
          source: 'manual',
          tone: toneData,
        );
        if (ok) count++;
      }
    }
    // Si hay ejemplos antiguos aislados, enriquecer sus metadatos para que muestren la frase como título
    for (final ex in existing) {
      if (ex.incomingText.isNotEmpty &&
          (ex.categoryTitle.isEmpty ||
              ex.categoryTitle == 'Plantilla' ||
              ex.categoryTitle == 'Diálogo')) {
        await repo.updateExample(
          ex,
          tone: {
            ...ex.tone,
            'title': 'Cotidiano · conversación',
            'category': 'Cotidiano · conversación',
            'incomingVariants': jsonEncode([ex.incomingText]),
            'responses': jsonEncode(
              ex.variants
                  .map((v) => PersonaResponseOption(text: v).toMap())
                  .toList(),
            ),
          },
        );
      }
    }
    debugPrint(
      '[persona:seed] Sincronizadas  frases con múltiples respuestas para Agente EMMA.',
    );
    return count;
  } catch (e) {
    debugPrint('[persona:seed] Error sembrando dataset EMMA: ');
    return 0;
  }
}

/// Migración de compatibilidad para aprendizaje del Agente Personal.
///
/// QUÉ HACE: elimina únicamente filas sintéticas creadas por versiones que
/// inyectaban respuestas fijas de EMMA y luego consolida el aprendizaje real.
/// CÓMO: compara el conjunto completo de entradas y respuestas de cada semilla;
/// nunca crea ni reemplaza una frase aprendida por el dueño.
/// POR QUÉ: la memoria debe provenir de WhatsApp/importación/edición explícita,
/// no de un catálogo artificial que pueda responder hechos actuales falsos.
library;

export 'personal_style_seed_pairs.dart';

import 'emma_intent_seed.dart';
import 'emma_intent_seed_catalog.dart';
import 'persona_repository.dart';
import 'personal_reply_learning_service.dart';
import '../domain/persona_example.dart';

/// Limpia la herencia de la siembra fija sin tocar aprendizaje confirmado.
/// [forceEnrich] se conserva por compatibilidad con integraciones antiguas;
/// desde esta versión jamás activa inyección de contenido.
Future<int> ensurePersonalStyleSeed(
  PersonaRepository repo, {
  bool forceEnrich = false,
}) async {
  if (forceEnrich) {
    // Compatibilidad: el antiguo botón "EMMA" ya no puede inventar ejemplos.
  }
  try {
    final examples = await _allExamples(repo);
    var removed = 0;
    for (final example in examples) {
      if (emmaCanonicalSeeds.any((seed) => _isLegacySeed(example, seed))) {
        if (await repo.deleteExample(example.id)) removed++;
      }
    }
    await PersonalReplyLearningService(repository: repo).consolidateExisting();
    return removed;
  } catch (_) {
    // La carga de la pantalla no debe caer si la migración es parcial.
    return 0;
  }
}

Future<List<PersonaExample>> _allExamples(PersonaRepository repo) async {
  final all = <PersonaExample>[];
  for (var offset = 0; offset < 5000; offset += 200) {
    final page = await repo.listExamples(limit: 200, offset: offset);
    all.addAll(page);
    if (page.length < 200) break;
  }
  return all;
}

bool _isLegacySeed(PersonaExample example, EmmaIntentSeed seed) {
  if (example.source != 'manual' || example.importBatch.isNotEmpty) {
    return false;
  }
  if (!_sameSet(example.incomingVariants, seed.incomingVariants)) {
    return false;
  }
  final expectedReplies = seed.responses
      .map((response) => response.text)
      .toList();
  return _sameSet(example.variants, expectedReplies);
}

bool _sameSet(Iterable<String> left, Iterable<String> right) {
  final a = left.map(_canonical).where((value) => value.isNotEmpty).toSet();
  final b = right.map(_canonical).where((value) => value.isNotEmpty).toSet();
  return a.length == b.length && a.containsAll(b);
}

String _canonical(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[¿?¡!.,;:]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');

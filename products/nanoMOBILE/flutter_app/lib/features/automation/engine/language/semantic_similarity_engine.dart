// semantic_similarity_engine.dart
//
// QUÉ HACE:
// Motor de similitud semántica desligado de embeddings pesados o LLMs remotos.
//
// CÓMO FUNCIONA:
// Evalúa equivalencia de intenciones, clústeres de paráfrasis pragmática en español
// (incluyendo modismos colombianos) y penaliza asimetrías de rol sintáctico/entidad.
//
// POR QUÉ:
// Ofrece una interfaz extensible para futuros modelos ONNX/TFLite respetando OCP (SOLID)
// y garantiza latencias < 2ms en dispositivos móviles (< 190 líneas).

library;

import 'package:nanoai/features/automation/personal_agent/application/personal_learning_text.dart'
    show normalizePersonalLearningText;

abstract interface class SemanticSimilarityEngine {
  Future<double> similarity(String a, String b);
}

final class LightweightSemanticSimilarityEngine implements SemanticSimilarityEngine {
  const LightweightSemanticSimilarityEngine();

  static const Map<String, List<String>> _paraphraseClusters = {
    'wellbeing_inquiry': [
      'como estas', 'como vas', 'todo bien', 'que tal', 'como te ha ido',
      'como andas', 'que tal vas', 'como sigue todo', 'como te trata el dia',
      'que mas como vas', 'que hubo como vas', 'todo bien por alla', 'que se cuenta',
    ],
    'wellbeing_response': [
      'bien gracias a dios', 'todo bien', 'excelente', 'bien por aca',
      'ahi vamos', 'todo tranquilo', 'bien y tu', 'todo en orden',
    ],
    'greeting': [
      'hola', 'buenas', 'buen dia', 'buenos dias', 'buenas tardes',
      'buenas noches', 'hey', 'que mas', 'quiubo', 'oe',
    ],
    'farewell': [
      'chao', 'adios', 'hasta luego', 'nos vemos', 'hablamos luego',
      'que descanses', 'descansa', 'hasta manana',
    ],
    'gratitude': [
      'gracias', 'muchas gracias', 'te agradezco', 'mil gracias', 'se agradece',
    ],
    'meeting_time_q': [
      'a que hora', 'que hora', 'a que horas', 'tipo que hora', 'a que horas nos vemos',
      'a que hora quedamos', 'que hora entonces',
    ],
    'activity_q': [
      'que haces', 'que estas haciendo', 'en que andas', 'que andas haciendo',
    ],
    'location_q': [
      'donde estas', 'en donde andas', 'por donde andas', 'estas en casa',
    ],
    'confirmation': [
      'si', 'de una', 'dale', 'listo', 'claro', 'seguro', 'haganle', 'total',
    ],
    'negation': [
      'no', 'no voy', 'creo que no', 'para nada', 'tampoco', 'imposible', 'todavia no',
    ],
  };

  @override
  Future<double> similarity(String a, String b) async => compute(a, b);

  static double compute(String rawA, String rawB) {
    final normA = normalizePersonalLearningText(rawA);
    final normB = normalizePersonalLearningText(rawB);
    if (normA.isEmpty || normB.isEmpty) return 0.0;
    if (normA == normB) return 1.0;

    // 1. Discriminación adversarial estricta (no fusionar preguntas semánticamente distintas)
    if (_isAdversarialMismatch(normA, normB)) return 0.15;

    // 2. Coincidencia en clústeres de paráfrasis semántica
    for (final cluster in _paraphraseClusters.values) {
      final matchA = _matchesCluster(normA, cluster);
      final matchB = _matchesCluster(normB, cluster);
      if (matchA && matchB) {
        // Bonificación por equivalencia pragmática pura
        return 0.88;
      }
    }

    // 3. Similitud de n-gramas normalizada
    final tokensA = normA.split(' ').where((t) => t.isNotEmpty).toSet();
    final tokensB = normB.split(' ').where((t) => t.isNotEmpty).toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    final jaccard = union > 0 ? intersection / union : 0.0;

    if (normA.contains(normB) || normB.contains(normA)) {
      return (0.65 + (0.30 * jaccard)).clamp(0.0, 0.95);
    }

    return (jaccard * 0.75).clamp(0.0, 0.80);
  }

  static bool _matchesCluster(String text, List<String> cluster) {
    for (final phrase in cluster) {
      if (text == phrase) return true;
      if (text.contains(phrase) && (text.length - phrase.length) <= 12) return true;
    }
    return false;
  }

  static bool _isAdversarialMismatch(String a, String b) {
    // "estas en casa" (estado del interlocutor) vs "como esta tu casa" (inmueble/familia)
    final aInCasa = a.contains('en casa') || a.contains('estas en');
    final bTuCasa = b.contains('tu casa') || b.contains('su casa');
    final aTuCasa = a.contains('tu casa') || a.contains('su casa');
    final bInCasa = b.contains('en casa') || b.contains('estas en');
    if ((aInCasa && bTuCasa) || (aTuCasa && bInCasa)) return true;

    // "todo bien?" vs "todo bien con el proyecto?"
    final aProject = a.contains('proyecto') || a.contains('app') || a.contains('trabajo');
    final bProject = b.contains('proyecto') || b.contains('app') || b.contains('trabajo');
    if (aProject != bProject && (a.contains('todo bien') || b.contains('todo bien'))) return true;

    // "ya estas?" (preparado) vs "ya esta?" (objeto terminado)
    final aPersona = a == 'ya estas' || a.contains('ya estas');
    final bCosa = b == 'ya esta' || b.endsWith('ya esta');
    if (aPersona != bCosa && (a.contains('ya esta') && b.contains('ya esta'))) return true;

    // "que tal nano" (pregunta sobre producto) vs "que tal" (saludo humano)
    final aNano = a.contains('nano');
    final bNano = b.contains('nano');
    if (aNano != bNano && (a.contains('que tal') || b.contains('que tal'))) return true;

    return false;
  }
}

/// QUÉ HACE:
/// Recuperador determinista de contexto social y conversacional basado en relevancia
/// multi-señal (participantes, relación, tema, entidades, continuidad, intención,
/// importancia y decaimiento suave por recencia).
///
/// CÓMO FUNCIONA:
/// Puntúa los turnos históricos de una conversación combinando coincidencia léxica/raíz,
/// clústeres temáticos (ej. fútbol ↔ partido, código ↔ app), afinidad de participante,
/// continuidad dialógica e importancia (intervenciones reales del dueño), preservando
/// los pares pregunta→respuesta y el orden cronológico final.
///
/// POR QUÉ:
/// Sustituye el truncado ciego `entries.takeLast(4)` por recuperación temática real
/// sin requerir embeddings remotos (< 185 líneas, SOLID - SRP).
library;

import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import 'conversation_memory_models.dart';

abstract final class SocialContextRetriever {
  static const Map<String, Set<String>> _topicClusters = {
    'sport_football': {
      'futbol', 'partido', 'partidos', 'gol', 'goles', 'cancha', 'equipo',
      'jugar', 'jugador', 'torneo', 'liga', 'copa', 'campeon', 'seleccion',
      'nacional', 'medellin', 'millonarios', 'america', 'junior', 'real',
      'barca', 'barcelona', 'champions', 'mundial', 'arquero', 'penal',
    },
    'software_code': {
      'codigo', 'programar', 'programando', 'programa', 'app', 'aplicacion',
      'android', 'studio', 'flutter', 'dart', 'rust', 'python', 'bug',
      'error', 'compilar', 'deploy', 'servidor', 'repo', 'git', 'sistema',
      'agente', 'modelo', 'ia', 'base', 'datos', 'sqlite',
    },
    'food_meal': {
      'comida', 'comer', 'comiste', 'almorzar', 'almuerzo', 'almorzaste',
      'cena', 'cenar', 'cenaste', 'desayuno', 'desayunar', 'hambre',
      'restaurante', 'pizza', 'hamburguesa', 'cafe', 'cocinar', 'receta',
    },
    'work_career': {
      'trabajo', 'trabajar', 'trabajando', 'camello', 'camellando', 'oficina',
      'reunion', 'jefe', 'cliente', 'proyecto', 'entrega', 'informe',
      'turno', 'horario', 'empresa', 'negocio', 'pago', 'factura',
    },
    'health_gym': {
      'gym', 'gimnasio', 'entrenar', 'entrenando', 'entreno', 'ejercicio',
      'rutina', 'pesas', 'pecho', 'espalda', 'pierna', 'cardio', 'correr',
      'salud', 'medico', 'cansado', 'cansada', 'dormir', 'sueno',
    },
    'family_home': {
      'familia', 'mama', 'papa', 'hermano', 'hermana', 'hijo', 'hija',
      'abuela', 'abuelo', 'casa', 'hogar', 'perro', 'mascota', 'gato',
    },
    'social_outing': {
      'salir', 'salida', 'parche', 'plan', 'planes', 'viaje', 'paseo',
      'cine', 'fiesta', 'finde', 'semana', 'centro', 'calle', 'vernos',
    },
  };

  static const Set<String> _stopTokens = {
    'hola', 'buenas', 'buenos', 'dias', 'tardes', 'noches', 'que', 'como',
    'para', 'por', 'con', 'una', 'uno', 'los', 'las', 'del', 'mas', 'muy',
    'pero', 'todo', 'bien', 'gracias', 'dale', 'listo', 'bro', 'parce',
  };

  static const Set<String> _anaphoricMarkers = {
    'ella', 'el', 'eso', 'esa', 'ese', 'ahi', 'alli', 'le', 'les', 'lo', 'la',
    'aquello', 'acuerdas', 'dijo', 'llamo', 'cambie', 'puso', 'quedo',
  };

  static const Map<String, Set<String>> _paraphraseActs = {
    'outcome_inquiry': {
      'como te fue', 'que paso al final', 'en que quedo', 'como salio',
      'que tal salio', 'como resulto', 'pudiste resolver', 'que hubo de',
    },
    'memory_recall': {
      'te acuerdas', 'recuerdas a', 'sabes algo de', 'que fue de',
    },
    'status_followup': {
      'como sigues', 'ya mejor', 'todo en orden con', 'como va lo de',
    },
  };

  /// Similitud pragmática para paráfrasis sin tokens compartidos (Ciclo 18).
  static double scoreParaphraseSimilarity(String a, String b) {
    final normA = normalizeText(a);
    final normB = normalizeText(b);
    if (normA.isEmpty || normB.isEmpty) return 0.0;
    for (final phrases in _paraphraseActs.values) {
      final matchA = phrases.any(normA.contains);
      final matchB = phrases.any(normB.contains);
      if (matchA && matchB) return 0.82;
    }
    return 0.0;
  }

  /// Calcula la relevancia temática abierta y de entidades [0.0..10.0] (Ciclos 15, 16, 18).
  static double scoreThematicRelevance(String queryText, String candidateText) {
    final normQuery = normalizeText(queryText);
    final normCand = normalizeText(candidateText);
    if (normQuery.isEmpty || normCand.isEmpty) return 0.0;

    final queryTokens = _substantiveTokens(normQuery);
    final candTokens = _substantiveTokens(normCand);
    var score = scoreParaphraseSimilarity(queryText, candidateText) * 3.5;
    if (queryTokens.isEmpty || candTokens.isEmpty) return score;

    // 1. Coincidencia abierta de sustantivos, nombres propios o entidades (cualquier dominio)
    final exactOverlap = queryTokens.intersection(candTokens).length;
    score += exactOverlap * 3.0;

    // 2. Raíz morfológica (>= 4 chars) y trigramas abiertos (ej. mascotas, universidad, carros, viajes)
    for (final q in queryTokens) {
      if (q.length < 4 || candTokens.contains(q)) continue;
      final root = q.substring(0, 4);
      if (candTokens.any((c) => c.length >= 4 && c.startsWith(root))) {
        score += 1.8;
      }
    }

    // 3. Continuidad anafórica: si la consulta usa pronombres ("ella", "eso", "le") y el candidato
    // contiene nombres propios o sustantivos concretos (>= 5 chars), preserva el antecedente.
    final queryAllTokens = tokenizeText(normQuery).toSet();
    if (queryAllTokens.any(_anaphoricMarkers.contains) &&
        (_hasCapitalizedEntity(candidateText) ||
            candTokens.any((t) => t.length >= 5))) {
      score += 2.2;
    }

    // 4. Clústeres temáticos conocidos actúan ÚNICAMENTE como boost adicional (Ciclo 15)
    final sharedClusters =
        _clustersFor(queryTokens).intersection(_clustersFor(candTokens)).length;
    score += sharedClusters * 2.0;

    return score;
  }

  /// Selecciona hasta [maxEntries] entradas relevantes conservando entidades, pares y cronología.
  static List<ConversationMemoryEntry> selectWindow(
    List<ConversationMemoryEntry> entries, {
    required String currentText,
    String currentSender = '',
    String? activeTopic,
    int maxEntries = 4,
  }) {
    if (entries.isEmpty || maxEntries <= 0) return const [];
    if (entries.length <= maxEntries) return entries;

    final inheritedEntities = _resolveRecentEntities(entries, currentText);
    final effectiveQuery = [
      currentText,
      if (activeTopic != null && activeTopic.trim().isNotEmpty)
        activeTopic.trim(),
      ...inheritedEntities,
    ].join(' ');
    final normSender = normalizeText(currentSender);
    final normQuery = normalizeText(currentText);

    final scoredIndices = <({int index, double score})>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final pairText = (entry.kind == ConversationMemoryEntryKind.inbound &&
              i + 1 < entries.length &&
              entries[i + 1].kind != ConversationMemoryEntryKind.inbound)
          ? '${entry.text} ${entries[i + 1].text}'
          : entry.text;
      var s = scoreThematicRelevance(effectiveQuery, pairText);

      final entrySender = normalizeText(entry.sender);
      if (normSender.isNotEmpty && entrySender == normSender) s += 1.4;
      if (entrySender.length >= 3 && normQuery.contains(entrySender)) s += 2.5;
      if (entry.kind == ConversationMemoryEntryKind.outboundObservedManual) {
        s += 0.9;
      }
      if (entry.text.contains('?')) s += 0.5;
      if (i >= entries.length - 2) s += 1.8;
      s += 1.2 * ((i + 1) / entries.length);

      scoredIndices.add((index: i, score: s));
    }

    scoredIndices.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : b.index.compareTo(a.index);
    });

    final selected = <int>{};
    for (final item in scoredIndices) {
      if (selected.length >= maxEntries) break;
      selected.add(item.index);
      if (selected.length < maxEntries &&
          entries[item.index].kind == ConversationMemoryEntryKind.inbound &&
          item.index + 1 < entries.length &&
          entries[item.index + 1].kind != ConversationMemoryEntryKind.inbound) {
        selected.add(item.index + 1);
      }
    }

    final sorted = selected.toList()..sort();
    return [for (final idx in sorted) entries[idx]];
  }

  static Set<String> _resolveRecentEntities(
    List<ConversationMemoryEntry> entries,
    String currentText,
  ) {
    final normCurrent = normalizeText(currentText);
    final currentWords = tokenizeText(normCurrent).toSet();
    if (!currentWords.any(_anaphoricMarkers.contains)) return const {};
    final entities = <String>{};
    for (final entry in entries.reversed.take(6)) {
      entities.addAll(
        _substantiveTokens(normalizeText(entry.text))
            .where((t) => t.length >= 4)
            .take(3),
      );
      if (entities.length >= 4) break;
    }
    return entities;
  }

  static bool _hasCapitalizedEntity(String raw) =>
      RegExp(r'(?:^|\s)[A-ZÁÉÍÓÚÑ][a-záéíóúñ]{2,}').hasMatch(raw);

  static Set<String> _substantiveTokens(String normalized) =>
      tokenizeText(normalized)
          .where((t) => t.length >= 3 && !_stopTokens.contains(t))
          .toSet();

  static Set<String> _clustersFor(Set<String> tokens) => {
    for (final entry in _topicClusters.entries)
      if (tokens.any(entry.value.contains)) entry.key,
  };
}

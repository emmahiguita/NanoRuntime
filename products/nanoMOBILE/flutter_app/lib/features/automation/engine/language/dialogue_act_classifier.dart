// dialogue_act_classifier.dart
//
// QUÉ HACE:
// Clasificador determinista y semántico de actos de diálogo (DialogueActClassifier).
//
// CÓMO FUNCIONA:
// - Normaliza el texto de entrada y evalúa marcadores morfosintácticos y léxicos.
// - Discierne si el mensaje es una reacción empática ("me alegra"), una pregunta ("¿cómo estás?"),
//   un acuse de recibo ("dale"), una corrección ("eso no lo pregunté yo") o una reparación.
//
// POR QUÉ:
// Asegura que "me alegra" jamás sea clasificada como consulta ni empujada a búsqueda externa.
// Cumple SOLID (SRP) con un archivo mantenible estrictamente menor a 200 líneas.

library;

import '../business/fact_selector.dart' show normalizeText, tokenizeText;
import 'dialogue_act.dart';
import 'dialogue_act_phrases.dart';

export 'dialogue_act.dart';

final class DialogueActClassifier {
  const DialogueActClassifier();

  /// Clasifica el acto conversacional del [text].
  DialogueActClassification classify(String text) {
    final norm = normalizeText(text).trim();
    if (norm.isEmpty) return DialogueActClassification.neutral;

    final tokens = tokenizeText(norm);
    final secondary = <DialogueAct>{};

    // 1. Solicitud de reparación o duda estricta ("?", "¿cómo?")
    if (norm == '?' || norm == '¿?' || norm == '??' || _matchesExactOrPrefix(norm, kRepairPhrases)) {
      return DialogueActClassification(
        primaryAct: DialogueAct.repairRequest,
        confidence: 0.95,
        normalizedText: norm,
      );
    }

    // 2. Corrección explícita de contexto ("eso no lo pregunté yo", "no pregunté eso")
    if (_matchesAny(norm, kCorrectionPhrases) ||
        (tokens.firstOrNull == 'no' && tokens.length > 1 && norm.contains('decia'))) {
      return DialogueActClassification(
        primaryAct: DialogueAct.correction,
        confidence: 0.95,
        normalizedText: norm,
      );
    }

    // 3. Reacción afectiva positiva ("me alegra", "qué bueno")
    if (_isPositiveReaction(norm, tokens)) {
      if (tokens.contains('gracias')) secondary.add(DialogueAct.gratitude);
      return DialogueActClassification(
        primaryAct: DialogueAct.positiveReaction,
        secondaryActs: secondary,
        confidence: 0.94,
        normalizedText: norm,
      );
    }

    // 4. Reacción afectiva negativa
    if (_matchesAny(norm, kNegativeReactionPhrases)) {
      return DialogueActClassification(
        primaryAct: DialogueAct.negativeReaction,
        confidence: 0.92,
        normalizedText: norm,
      );
    }

    // 5. Agradecimiento
    if (_matchesAny(norm, kGratitudePhrases)) {
      return DialogueActClassification(
        primaryAct: DialogueAct.gratitude,
        confidence: 0.93,
        normalizedText: norm,
      );
    }

    // 6. Aclaración
    if (_matchesAny(norm, kClarificationPhrases)) {
      return DialogueActClassification(
        primaryAct: DialogueAct.clarification,
        confidence: 0.90,
        normalizedText: norm,
      );
    }

    // 7. Continuación o reciprocidad ("y tú?", "y vos?")
    if ((norm.contains('y tu') || norm.contains('y vos') || norm.contains('que tal tu') || norm.contains('y usted')) &&
        norm.length <= 25) {
      return DialogueActClassification(
        primaryAct: DialogueAct.continuation,
        confidence: 0.92,
        normalizedText: norm,
      );
    }

    // 8. Despedida
    if (_matchesAny(norm, kFarewellPhrases)) {
      return DialogueActClassification(
        primaryAct: DialogueAct.farewell,
        confidence: 0.93,
        normalizedText: norm,
      );
    }

    // 9. Saludo
    if (_isGreeting(norm, tokens)) {
      if (text.contains('?')) secondary.add(DialogueAct.question);
      return DialogueActClassification(
        primaryAct: DialogueAct.greeting,
        secondaryActs: secondary,
        confidence: 0.92,
        normalizedText: norm,
      );
    }

    // 10. Pregunta explícita
    if (text.contains('?') || _isInterrogativeSentence(norm, tokens)) {
      return DialogueActClassification(
        primaryAct: DialogueAct.question,
        confidence: 0.90,
        normalizedText: norm,
      );
    }

    // 11. Acuse de recibo / afirmación / asentimiento ("listo", "dale", "ok", "de una")
    if (_isAcknowledgement(norm, tokens)) {
      return DialogueActClassification(
        primaryAct: DialogueAct.acknowledgement,
        confidence: 0.91,
        normalizedText: norm,
      );
    }

    // 12. Declaración o afirmación genérica
    return DialogueActClassification(
      primaryAct: DialogueAct.statement,
      confidence: 0.70,
      normalizedText: norm,
    );
  }

  static bool _matchesAny(String norm, List<String> phrases) =>
      phrases.any(norm.contains);

  static bool _matchesExactOrPrefix(String norm, List<String> phrases) =>
      phrases.any((p) => norm == p || norm.startsWith('$p '));

  static bool _isPositiveReaction(String norm, Set<String> tokens) {
    if (norm == 'me alegra' || norm == 'me alegro' || norm.startsWith('me alegra') || norm.startsWith('me alegro')) {
      return true;
    }
    return kPositiveReactionPhrases.any(norm.contains);
  }

  static bool _isGreeting(String norm, Set<String> tokens) {
    if (tokens.isEmpty) return false;
    const explicitGreetingWords = {
      'hola', 'holas', 'buenas', 'buenos', 'hey', 'oe', 'saludos', 'ola', 'quiubo',
    };
    return tokens.take(2).any(explicitGreetingWords.contains) || kGreetingPhrases.any(norm.startsWith);
  }

  static bool _isInterrogativeSentence(String norm, Set<String> tokens) {
    const questionStarters = {
      'cuanto', 'cuanta', 'cuantos', 'cuantas', 'como', 'donde', 'cuando', 'quien',
      'quienes', 'que', 'cual', 'cuales', 'por que', 'porque',
    };
    final first = tokens.firstOrNull;
    return first != null && questionStarters.contains(first);
  }

  static bool _isAcknowledgement(String norm, Set<String> tokens) {
    const ackWords = {
      'listo', 'dale', 'ok', 'okay', 'bien', 'bueno', 'de una', 'perfecto', 'claro',
      'entendido', 'vale', 'seguro', 'obvio', 'si', 'sisas', 'hagamosle',
    };
    return tokens.any(ackWords.contains) || norm == 'de una' || norm == 'dale pues' || norm == 'listo pues';
  }
}

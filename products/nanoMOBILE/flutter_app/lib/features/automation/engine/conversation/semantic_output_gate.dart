// semantic_output_gate.dart
//
// QUÉ HACE:
// Compuerta de relevancia semántica de salida (SemanticOutputGate).
//
// CÓMO FUNCIONA:
// - Valida que la respuesta candidata sea estrictamente relevante para el turno del usuario y su acto conversacional.
// - Detecta discrepancias graves (ej: usuario dice "me alegra" y el candidato habla de "Porto Alegre" o de un producto).
// - Si la relevancia es nula o contradictoria, rechaza el candidato y ofrece un reemplazo contextual seguro.
//
// POR QUÉ:
// Barrera de contención final: incluso si falla el enrutamiento o el modelo generativo alucina,
// impide categóricamente que se despache información no pertinente al usuario.
// Cumple SOLID (SRP) con un archivo limpio y mantenible menor a 200 líneas.

library;

import '../business/fact_selector.dart' show normalizeText;
import '../language/dialogue_act.dart';

final class SemanticValidationResult {
  final bool isApproved;
  final double relevanceScore;
  final String? rejectionReason;
  final String? safeFallbackReply;

  const SemanticValidationResult({
    required this.isApproved,
    required this.relevanceScore,
    this.rejectionReason,
    this.safeFallbackReply,
  });

  static const approved = SemanticValidationResult(
    isApproved: true,
    relevanceScore: 1.0,
  );
}

final class SemanticOutputGate {
  const SemanticOutputGate();

  static const _externalFactKeywords = {
    'segun vi', 'censo', 'habitantes', 'capital de', 'ciudad brasilena', 'brasilena',
    'poblacion', 'wikipedia', 'noticia oficial', 'dolar cotiza', 'bitcoin cotiza',
  };

  /// Valida la relevancia semántica del [candidateReply] frente al [userText] y [act].
  SemanticValidationResult validate({
    required String userText,
    required DialogueAct act,
    required String candidateReply,
  }) {
    final normUser = normalizeText(userText);
    final normReply = normalizeText(candidateReply);

    // 1. Barrera para reacciones positivas/afectivas ("me alegra", "qué bueno")
    if (act == DialogueAct.positiveReaction) {
      final hasExternalLeak = _externalFactKeywords.any(normReply.contains) ||
          normReply.contains('segun vi') ||
          normReply.contains('porto alegre');
      if (hasExternalLeak) {
        return const SemanticValidationResult(
          isApproved: false,
          relevanceScore: 0.0,
          rejectionReason: 'Fuga de conocimiento externo en turno de reacción positiva',
          safeFallbackReply: '¡Total parce! Todo bien por acá.',
        );
      }
      if (normReply.contains('en que puedo') || normReply.contains('puedo colaborar')) {
        return const SemanticValidationResult(
          isApproved: false,
          relevanceScore: 0.1,
          rejectionReason: 'Respuesta tipo call-center para reacción positiva',
          safeFallbackReply: '¡De una! Un abrazo.',
        );
      }
    }

    // 2. Barrera para agradecimientos o despedidas
    if (act == DialogueAct.gratitude && _externalFactKeywords.any(normReply.contains)) {
      return const SemanticValidationResult(
        isApproved: false,
        relevanceScore: 0.0,
        rejectionReason: 'Foco enciclopédico no solicitado en agradecimiento',
        safeFallbackReply: '¡Con todo gusto!',
      );
    }

    if (act == DialogueAct.farewell && candidateReply.contains('?')) {
      return const SemanticValidationResult(
        isApproved: false,
        relevanceScore: 0.3,
        rejectionReason: 'Pregunta de retorno en despedida',
        safeFallbackReply: '¡Listo, hablamos después! Que estés muy bien.',
      );
    }

    // 3. Barrera para correcciones del usuario ("eso no lo pregunté yo")
    if (act == DialogueAct.correction) {
      if (candidateReply.contains('?') && (normReply.contains('y tu') || normReply.contains('como vas'))) {
        return const SemanticValidationResult(
          isApproved: false,
          relevanceScore: 0.1,
          rejectionReason: 'Rebote genérico en turno de corrección',
          safeFallbackReply: '¡Uy, qué pena! Me enredé ahí. Cuéntame, ¿qué era lo que me decías?',
        );
      }
    }

    // 4. Barrera de repetición eco literal del usuario
    if (normUser.length > 5 && normUser == normReply) {
      return const SemanticValidationResult(
        isApproved: false,
        relevanceScore: 0.0,
        rejectionReason: 'Eco literal del mensaje del usuario',
        safeFallbackReply: 'Por acá ando atento.',
      );
    }

    return SemanticValidationResult.approved;
  }
}

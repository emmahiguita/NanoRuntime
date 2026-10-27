/// QUÉ: presenta evidencia recuperada cuando no hubo redacción del modelo.
/// CÓMO: limpia formato, conserva contenido/atribución y devuelve un candidato.
/// POR QUÉ: una plantilla no puede afirmar «estuve mirando» en nombre del dueño.
library;

import '../language/language_assist.dart';
import '../notifications/conversation_understanding.dart';

/// Resultado compatible con el compositor; tener texto no autoriza enviarlo.
final class StyledResponseResult {
  final String text;
  final List<String> suggestions;
  final ConversationUnderstanding understanding;

  const StyledResponseResult({
    required this.text,
    required this.suggestions,
    required this.understanding,
  });
}

abstract interface class PersonalStyleFormatter {
  StyledResponseResult formatKnowledge({
    required String rawFacts,
    required String query,
    String? ownerName,
  });
}

/// Conserva el contrato público; la personalización corresponde al modelo con
/// perfil autorizado, no a introducciones elegidas por el reloj o un hash.
final class RuntimePersonalStyleFormatter implements PersonalStyleFormatter {
  const RuntimePersonalStyleFormatter();

  @override
  StyledResponseResult formatKnowledge({
    required String rawFacts,
    required String query,
    String? ownerName,
  }) {
    final cleaned = LanguageAssistService.safeCleanOutput(
      _cleanFormat(rawFacts),
    );
    // No inventa incertidumbre, promesas futuras ni un resumen recortado:
    // sin evidencia utilizable deja el turno retenido por el circuito existente.
    final failure = cleaned.isEmpty
        ? 'informacion_no_encontrada'
        : cleaned.length > 2000
        ? 'contenido_externo_demasiado_extenso'
        : null;
    if (failure != null) {
      return StyledResponseResult(
        text: '',
        suggestions: const [],
        understanding: ConversationUnderstanding(
          reply: '',
          intent: 'knowledge_unavailable',
          missingFacts: [failure],
          requiresAction: true,
        ),
      );
    }

    final suggestions = [cleaned];
    return StyledResponseResult(
      text: cleaned,
      suggestions: suggestions,
      understanding: ConversationUnderstanding(
        reply: cleaned,
        options: suggestions,
        // Identificador legacy conservado para no cambiar la política de decisión.
        intent: 'external_knowledge_styled',
        relation: 'responde',
        requiresAction: false,
      ),
    );
  }

  /// Solo retira marcadores de presentación. Conserva URLs, fuentes, negaciones
  /// y todas las oraciones: la limpieza no demuestra que la fuente sea correcta.
  static String _cleanFormat(String raw) => raw
      .trim()
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)'),
        (match) => '${match.group(1)} (${match.group(2)})',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

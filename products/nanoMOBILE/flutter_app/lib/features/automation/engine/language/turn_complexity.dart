/// Resultado inmutable de clasificación de complejidad del turno conversacional.
///
/// **QUÉ HACE:**
/// Discrimina si un turno de usuario es social mínimo, narrativo, contextual o complejo.
///
/// **CÓMO FUNCIONA:**
/// Es un Value Object puro expuesto por `TurnComplexityClassifier`.
///
/// **POR QUÉ:**
/// Garantiza el invariante WA-CONV-UNDERSTANDING-01: un turno narrativo o complejo
/// JAMÁS usa el `conversationSocialPromptFor` mínimo ni responde frases genéricas.
final class TurnComplexity {
  /// Turno social mínimo: saludo puro / reacción social pura sin referentes.
  /// Elegible para conversationSocialPromptFor.
  final bool isSocialMinimal;

  /// El hablante relata actividades, planes, estados propios.
  final bool isNarrative;

  /// El turno contiene referencias anafóricas a algo dicho antes.
  final bool isContextual;

  /// El turno tiene múltiples cláusulas o intenciones distintas.
  final bool isComplex;

  const TurnComplexity({
    required this.isSocialMinimal,
    required this.isNarrative,
    required this.isContextual,
    required this.isComplex,
  });

  /// true si el turno puede usar el prompt social mínimo de forma segura.
  bool get eligibleForSocialPrompt =>
      isSocialMinimal && !isNarrative && !isContextual && !isComplex;
}

/// Modelo inmutable de una intención personal y sus respuestas posibles.
library;

import '../domain/persona_response_option.dart';

final class EmmaIntentSeed {
  final String trigger;
  final String category;
  final String intent;
  final List<String> incomingVariants;
  final List<PersonaResponseOption> responses;

  const EmmaIntentSeed({
    required this.trigger,
    required this.category,
    required this.intent,
    required this.incomingVariants,
    required this.responses,
  });
}

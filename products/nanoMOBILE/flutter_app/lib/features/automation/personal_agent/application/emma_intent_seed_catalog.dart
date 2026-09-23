/// Catálogo canónico compuesto; los datos se separan por responsabilidad para
/// mantener archivos pequeños y facilitar mantenimiento manual.
library;

import 'emma_intent_seed.dart';
import 'emma_intent_seed_routine.dart';
import 'emma_intent_seed_social.dart';

const emmaCanonicalSeeds = <EmmaIntentSeed>[
  ...emmaSocialSeeds,
  ...emmaRoutineSeeds,
];

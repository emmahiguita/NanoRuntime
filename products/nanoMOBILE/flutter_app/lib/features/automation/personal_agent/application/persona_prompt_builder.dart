// persona_prompt_builder.dart
//
// QUÉ HACE:
// Construye el bloque `<DATOS DE LA PERSONA>` para alimentar el prompt del modelo de lenguaje.
//
// CÓMO FUNCIONA:
// - Valida restricciones de estilo del dueño y tono del contacto.
// - Concatena instrucciones de brevedad y naturalidad ("bien, gracias a Dios", "¿y tú?").
// - Filtra memorias personales relevantes sin exceder el límite de 3000 caracteres de prompt.
// - Formatea pares condicionados y ejemplos históricos sin alucinaciones de hechos vivos.
//
// POR QUÉ:
// Desacopla la lógica de formateo y serialización de prompt del estado en memoria (SOLID - SRP),
// garantizando archivos estructurados y de menos de 200 líneas.

library;

import '../../engine/language/dialogue_state.dart' show linguisticAnalyzer;
import '../../engine/messaging/social_context_retriever.dart';
import '../domain/conversation_agent_role.dart' show isLiveStateQuestion;
import '../domain/owner_live_fact_guard.dart' show FactualEvidenceLevel;
import '../domain/personal_memory.dart';
import '../domain/personal_style_constraints.dart';
import '../domain/persona_example.dart';
import '../domain/persona_profile.dart';
import '../domain/relationship_register.dart';
import 'persona_repository.dart';
import 'persona_retriever.dart';
import 'persona_validator.dart';

part 'persona_prompt_builder_body.part.dart';
part 'persona_prompt_builder_helpers.part.dart';

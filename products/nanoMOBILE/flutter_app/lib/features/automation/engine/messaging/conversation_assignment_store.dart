// QUÉ: mantiene el punto de importación estable para la asignación de agentes.
// CÓMO: reexporta contrato, memoria y persistencia desde responsabilidades separadas.
// POR QUÉ: evita un archivo monolítico y conserva compatibilidad con los consumidores.
library;

export 'conversation_assignment_models.dart';
export 'memory_conversation_assignment_store.dart';
export 'sqlite_conversation_assignment_store.dart';

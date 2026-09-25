/// Contrato factual para preguntas sobre el estado real del dueño.
///
/// QUÉ HACE: identifica turnos que no pueden responderse solo con estilo.
/// CÓMO: combina el intent tipado del fast path con señales conservadoras del texto.
/// POR QUÉ: una frase natural no convierte comida, ubicación o planes en hechos.
library;

import '../../engine/business/fact_selector.dart' show normalizeText;
import 'conversation_agent_message_classifier.dart' show isLiveStateQuestion;

/// Jerarquía explícita de evidencia factual (Ciclo 7: Current State vs Memory).
///
/// Orden de prelación estricto:
/// 1. [observedLiveState] — Estado actual observado (sensores/telemetría en vivo).
/// 2. [explicitCurrentState] — Estado actual proporcionado explícitamente por el dueño hoy.
/// 3. [knownStableFact] — Hechos estables conocidos (preferencias fijas, relación declarada).
/// 4. [contextualHistoricalMemory] — Memoria histórica contextual (episodios/diálogos pasados).
/// 5. [inference] — Inferencia o candidato conversacional genérico.
/// 6. [unknown] — Desconocido (prohibido inventar; admitir o responder sin afirmar estado).
enum FactualEvidenceLevel {
  observedLiveState(1, 'estado_actual_observado'),
  explicitCurrentState(2, 'estado_actual_explicito'),
  knownStableFact(3, 'hecho_estable_conocido'),
  contextualHistoricalMemory(4, 'memoria_historica_contextual'),
  inference(5, 'inferencia_conversacional'),
  unknown(6, 'desconocido');

  final int rank;
  final String label;
  const FactualEvidenceLevel(this.rank, this.label);

  /// Solo los niveles 1 y 2 autorizan afirmar qué hace, come o dónde está el dueño AHORA.
  bool get canAssertCurrentOwnerState =>
      this == FactualEvidenceLevel.observedLiveState ||
      this == FactualEvidenceLevel.explicitCurrentState;

  /// Los niveles 1, 2 y 3 autorizan afirmar gustos/preferencias o hechos permanentes.
  bool get canAssertStableFact => rank <= FactualEvidenceLevel.knownStableFact.rank;

  /// Clasifica un tipo de memoria persistida según su nivel de evidencia,
  /// degradando conservadoramente cuando el timestamp no es confiable o el TTL expiró.
  static FactualEvidenceLevel fromMemoryKind(
    String kind, {
    bool hasReliableTimestamp = true,
    bool isExpiredOrSuperseded = false,
  }) {
    if (!hasReliableTimestamp) {
      return FactualEvidenceLevel.contextualHistoricalMemory;
    }
    if (isExpiredOrSuperseded) {
      return FactualEvidenceLevel.contextualHistoricalMemory;
    }
    switch (kind) {
      case 'liveObservedState':
        return FactualEvidenceLevel.observedLiveState;
      case 'explicitCurrentState':
      case 'temporaryFact':
        return FactualEvidenceLevel.explicitCurrentState;
      case 'stablePreference':
      case 'stableRelationshipFact':
      case 'stylePreference':
        return FactualEvidenceLevel.knownStableFact;
      case 'episodicMemory':
        return FactualEvidenceLevel.contextualHistoricalMemory;
      default:
        return FactualEvidenceLevel.unknown;
    }
  }
}

/// Intenciones cuyo contenido requiere evidencia viva (niveles 1-2) para afirmar hechos presentes.
const Set<String> ownerLiveFactIntentNames = {
  'askPhysicalLocation',
  'askCredentials',
  'askFinancials',
  'askActivity',
  'askFood',
  'askLunch',
  'askDinner',
  'askSleep',
};

/// Valida intents sin acoplar la política al enum del motor lingüístico.
bool intentNeedsOwnerLiveFact(Iterable<String> intentNames) =>
    intentNames.any(ownerLiveFactIntentNames.contains);

/// Devuelve true cuando responder supondría afirmar un hecho personal presente no observado.
bool requiresOwnerLiveFact({
  required String messageText,
  String detectedIntent = '',
  FactualEvidenceLevel availableEvidence = FactualEvidenceLevel.contextualHistoricalMemory,
}) {
  if (availableEvidence.canAssertCurrentOwnerState) return false;
  if (isLiveStateQuestion(messageText)) return true;
  final intents = detectedIntent
      .split('+')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty);
  if (intentNeedsOwnerLiveFact(intents)) {
    return true;
  }

  final text = normalizeText(messageText);
  if (text.isEmpty) return false;
  return _ownerFactSignals.any(text.contains);
}

/// Señales estrictas para preguntas directas sobre ubicación física, estado actual o datos confidenciales.
const List<String> _ownerFactSignals = [
  'donde estas exactamente',
  'tu direccion exacta',
  'tu ubicacion en tiempo real',
  'ya almorzaste',
  'ya cenaste',
  'ya comiste',
  'estas en tu casa',
  'estas despierto',
  'clave de',
  'contrasena de',
];

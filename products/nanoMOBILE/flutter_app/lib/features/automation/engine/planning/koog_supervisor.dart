/// KoogSupervisor (WA-KOOG-10) — supervisión de ciclo con decisión tipada.
///
/// Complementa a [KoogCandidateSelector] (que solo desambigua sets ambiguos):
/// el supervisor decide el SIGUIENTE paso del ciclo sobre el conjunto de
/// candidatos disponible — actuar sobre UNO existente, pedir observación,
/// pedir confirmación, declarar completado, declarar fracaso o abstenerse.
///
/// INVARIANTES (mismas que el selector, A6.5):
/// - El modelo SOLO puede referenciar un CandidateId existente en el contexto.
///   Jamás inventa tool, package, selector, intent, coordenadas ni comandos.
/// - Salida malformada / LLM no disponible / id desconocido → [KoogAbstain].
///   La abstención NO es fallo y jamás lanza: la autoridad sigue siendo del
///   pipeline determinista (planner → governance → dispatcher).
/// - El supervisor NO ejecuta, NO autoriza, NO verifica. Solo PROPONE.
library;

import 'dart:convert';

import 'package:nanoai/core/services/llm_engine_client.dart'
    show LLMEngineClient;
import 'package:nanoai/features/automation/engine/planning/candidates/candidate_action.dart'
    show CandidateAction, CandidateId;

/// Decisión tipada de supervisión (sealed, exhaustiva).
sealed class KoogSupervisionDecision {
  const KoogSupervisionDecision();
}

/// Ejecutar un candidato EXISTENTE (id verificado contra el set del contexto).
final class KoogAct extends KoogSupervisionDecision {
  const KoogAct(this.candidateId);

  final CandidateId candidateId;
}

/// Falta evidencia del estado actual: observar antes de decidir.
final class KoogNeedObservation extends KoogSupervisionDecision {
  const KoogNeedObservation(this.reason);

  final String reason;
}

/// La acción requiere confirmación humana (el modelo NO se auto-confirma).
final class KoogNeedConfirmation extends KoogSupervisionDecision {
  const KoogNeedConfirmation(this.reason);

  final String reason;
}

/// El objetivo ya está logrado; no hay nada que ejecutar.
final class KoogCompleted extends KoogSupervisionDecision {
  const KoogCompleted({this.summary});

  final String? summary;
}

/// El objetivo no se puede lograr con lo disponible.
final class KoogFailed extends KoogSupervisionDecision {
  const KoogFailed(this.reason);

  final String reason;
}

/// Abstención (LLM off, salida ilegible, id desconocido, o sin opinión).
/// No es fallo: el camino determinista conserva la autoridad.
final class KoogAbstain extends KoogSupervisionDecision {
  const KoogAbstain(this.reason);

  final String reason;
}

/// Vista factual de un candidato para el prompt del modelo. NUNCA incluye
/// args crudos ni canales de ejecución: el modelo ve id + semántica + evidencia,
/// lo mínimo para referenciar una acción EXISTENTE.
final class KoogCandidateView {
  const KoogCandidateView({
    required this.id,
    required this.semanticAction,
    required this.evidence,
  });

  final CandidateId id;
  final String semanticAction;
  final List<String> evidence;

  factory KoogCandidateView.fromCandidate(CandidateAction c) =>
      KoogCandidateView(
        id: c.id,
        semanticAction: c.semanticAction,
        evidence: c.evidence.map((e) => e.source.name).toList(growable: false),
      );
}

/// Contexto del ciclo de supervisión: goal + situación factual + candidatos +
/// acciones previas verificadas + resumen de memoria. Todo lo que el modelo
/// recibe aquí es DATA; nada es instrucción de sistema.
final class KoogSupervisionContext {
  const KoogSupervisionContext({
    required this.goal,
    required this.situationSummary,
    required this.candidates,
    this.previousVerifiedActions = const [],
    this.memorySummary,
  });

  final String goal;
  final String situationSummary;
  final List<KoogCandidateView> candidates;
  final List<String> previousVerifiedActions;
  final String? memorySummary;
}

/// Puerto del supervisor (DIP): la fuente de decisión es inyectable — LLM
/// local, heurística determinista o fake en tests.
abstract interface class KoogSupervisor {
  Future<KoogSupervisionDecision> decide(KoogSupervisionContext context);
}

/// Supervisor sobre el runtime local (mismo [LLMEngineClient] del planner).
/// Parseo estricto del JSON de salida; cualquier salida fuera del vocabulario
/// es abstención, nunca una acción inventada.
final class LlmKoogSupervisor implements KoogSupervisor {
  LlmKoogSupervisor(this._client);

  final LLMEngineClient _client;

  @override
  Future<KoogSupervisionDecision> decide(KoogSupervisionContext context) async {
    final String text;
    try {
      final result = await _client.generate(
        prompt: _buildPrompt(context),
        temperature: 0.0,
        maxTokens: 64,
      );
      text = result.text;
    } on Object {
      // El motor local no está disponible: el LLM es OPCIONAL por diseño.
      // Abstención silenciosa; NUNCA se lanza al llamador.
      return const KoogAbstain('LLM no disponible para supervisar.');
    }
    return _interpret(context, text);
  }

  KoogSupervisionDecision _interpret(
    KoogSupervisionContext context,
    String text,
  ) {
    final parsed = _parseOutput(text);
    if (parsed.malformed) {
      return const KoogAbstain('Salida del modelo no interpretable.');
    }
    final ids = {for (final c in context.candidates) c.id.value};
    switch (parsed.decision) {
      case 'act':
        final id = parsed.candidateId;
        if (id == null) {
          return const KoogAbstain('decision=act sin candidateId.');
        }
        if (!ids.contains(id)) {
          return KoogAbstain('CandidateId desconocido: $id');
        }
        return KoogAct(CandidateId(id));
      case 'need_observation':
        return KoogNeedObservation(parsed.reason ?? '');
      case 'need_confirmation':
        return KoogNeedConfirmation(parsed.reason ?? '');
      case 'completed':
        return KoogCompleted(summary: parsed.reason);
      case 'failed':
        return KoogFailed(parsed.reason ?? '');
      case 'abstain':
        return KoogAbstain(parsed.reason ?? 'abstención del modelo.');
      default:
        return const KoogAbstain('Decisión fuera del vocabulario.');
    }
  }

  /// Parseo estricto del contrato:
  /// {"decision":"<act|need_observation|need_confirmation|completed|failed|abstain>",
  ///  "candidateId":"<id existente>" (solo para act),
  ///  "reason":"..." (opcional)}
  /// Un JSON con otro shape (p. ej. un ToolCall) es malformed.
  ({String? decision, String? candidateId, String? reason, bool malformed})
  _parseOutput(String text) {
    try {
      final decoded = jsonDecode(text.trim());
      if (decoded is! Map) {
        return (
          decision: null,
          candidateId: null,
          reason: null,
          malformed: true,
        );
      }
      if (!decoded.containsKey('decision')) {
        return (
          decision: null,
          candidateId: null,
          reason: null,
          malformed: true,
        );
      }
      final decision = decoded['decision'];
      if (decision is! String) {
        return (
          decision: null,
          candidateId: null,
          reason: null,
          malformed: true,
        );
      }
      final candidateId = decoded['candidateId'];
      if (candidateId != null && candidateId is! String) {
        return (
          decision: null,
          candidateId: null,
          reason: null,
          malformed: true,
        );
      }
      final reason = decoded['reason'];
      if (reason != null && reason is! String) {
        return (
          decision: null,
          candidateId: null,
          reason: null,
          malformed: true,
        );
      }
      return (
        decision: decision,
        candidateId: candidateId as String?,
        reason: reason as String?,
        malformed: false,
      );
    } catch (_) {
      return (decision: null, candidateId: null, reason: null, malformed: true);
    }
  }

  String _buildPrompt(KoogSupervisionContext context) {
    final lines = context.candidates
        .map((c) {
          final evidence = c.evidence.join(', ');
          return '- id: ${c.id.value} | acción: ${c.semanticAction} '
              '| evidencia: $evidence';
        })
        .join('\n');
    final previous = context.previousVerifiedActions.isEmpty
        ? 'ninguna'
        : context.previousVerifiedActions.join('; ');
    final memory = context.memorySummary ?? 'sin resumen';
    return 'Eres el supervisor de un agente de automatización móvil.\n'
        'Objetivo del usuario: "${context.goal}"\n'
        'Situación factual del dispositivo: ${context.situationSummary}\n'
        'Acciones previas verificadas: $previous\n'
        'Resumen de memoria de conversación: $memory\n'
        'Candidatos de acción EXISTENTES (solo puedes referenciar uno de '
        'estos ids, copiándolo exacto):\n'
        '$lines\n'
        'Decide el siguiente paso y responde SOLO con JSON:\n'
        '{"decision":"act","candidateId":"<id>"} para ejecutar un candidato,\n'
        '{"decision":"need_observation","reason":"..."} si falta evidencia,\n'
        '{"decision":"need_confirmation","reason":"..."} si necesitas '
        'confirmación humana,\n'
        '{"decision":"completed","reason":"..."} si el objetivo ya está '
        'logrado,\n'
        '{"decision":"failed","reason":"..."} si es imposible,\n'
        '{"decision":"abstain","reason":"..."} para abstenerte.\n'
        'NO inventes tools, actions, packages, selectors, intents, '
        'coordenadas ni comandos.';
  }
}

/// GoalVerifier — responde "¿el objetivo del usuario quedó REALMENTE
/// cumplido?" (TASK SUCCESS), distinto de [ActionVerifier] que responde
/// "¿la acción funcionó?" (ACTION SUCCESS).
///
/// Regla de honestidad (§16 self-healing del plan maestro): el verificación
/// de objetivo NUNCA es tolerante. Si no hay expectativa declarada ni plan
/// completo, NO declara éxito — reporta [GoalStatus.unverified] o
/// [GoalStatus.notSatisfied].
library;

import 'agent_executor.dart';

/// Veredicto del objetivo. [unverified] es un estado honesto: el plan
/// multi-paso completó y cada paso fue ejecutado+verificado, pero no hay
/// expectativa de objetivo declarada para una comprobación final.
enum GoalStatus { satisfied, notSatisfied, unverified }

class GoalVerification {
  final GoalStatus status;
  final String reason;

  const GoalVerification(this.status, this.reason);
}

/// Expectativa del OBJETIVO (no de la acción): qué debe ser cierto al final.
/// La declara el llamador (heurística del chat o el LLM vía `goal_expect`).
class GoalExpectation {
  /// Texto que debe estar visible en el snapshot final.
  final String? visibleText;

  /// Texto que debe NO estar visible (p.ej. la pantalla original quedó atrás).
  final String? absentText;

  const GoalExpectation({this.visibleText, this.absentText});

  bool get hasCriteria => visibleText != null || absentText != null;
}

/// Verifica el objetivo final contra el estado real del dispositivo.
/// DIP: depende de [AgentExecutor] (interfaz) — el snapshot final es la única
/// evidencia aceptada, nunca el optimismo del llamador.
class GoalVerifier {
  GoalVerifier({required AgentExecutor executor}) : _executor = executor;

  final AgentExecutor _executor;

  Future<GoalVerification> verify(
    String goal, {
    required bool planCompleted,
    GoalExpectation? expectation,
  }) async {
    if (!planCompleted) {
      return const GoalVerification(
        GoalStatus.notSatisfied,
        'El plan no completó: se detuvo en un paso sin verificar. '
        'El objetivo no puede declararse cumplido.',
      );
    }

    if (expectation == null || !expectation.hasCriteria) {
      // Sin expectativa: el plan completo y verificado paso a paso es la
      // evidencia de ejecución, pero NO de cumplimiento del objetivo.
      return GoalVerification(
        GoalStatus.unverified,
        'Plan completo y verificado paso a paso; sin expectativa de objetivo '
        'declarada no hay comprobación final (honesto, no inventado).',
      );
    }

    final snap = await _executor.snapshot();
    if (snap == null) {
      return const GoalVerification(
        GoalStatus.notSatisfied,
        'Sin snapshot final (canal off): el objetivo no es verificable.',
      );
    }

    final visibleTexts = snap.nodes.map((n) => n.text).toSet();

    if (expectation.visibleText != null) {
      final needle = expectation.visibleText!.toLowerCase();
      final found = visibleTexts.any(
        (t) => t.toLowerCase().contains(needle),
      );
      if (!found) {
        return GoalVerification(
          GoalStatus.notSatisfied,
          'El objetivo exige "$needle" visible al final, pero no está en el '
          'estado real: NO se declara éxito.',
        );
      }
    }

    if (expectation.absentText != null) {
      final needle = expectation.absentText!.toLowerCase();
      final stillThere = visibleTexts.any(
        (t) => t.toLowerCase().contains(needle),
      );
      if (stillThere) {
        return GoalVerification(
          GoalStatus.notSatisfied,
          'El objetivo exige que "$needle" NO esté, pero sigue visible: '
          'el objetivo no se cumplió.',
        );
      }
    }

    return const GoalVerification(
      GoalStatus.satisfied,
      'Objetivo cumplido: expectativa verificada contra el estado final real.',
    );
  }
}

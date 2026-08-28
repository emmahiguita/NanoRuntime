/// AgentLoop ÔÇö orquestador del ciclo del agente m├│vil.
///
/// Cierra el bucle OBSERVE ÔåÆ RESOLVE ÔåÆ ACT ÔåÆ VERIFY ÔåÆ RECORD que las piezas
/// (`NanoAgentExecutor`, `ActionVerifier`, `NanoSelectorEngine`) ya cubren por
/// separado. Aqu├¡ solo se ORQUESTA: el loop no ejecuta ni verifica nada
/// directamente (SRP), depende de abstracciones inyectables (DIP), y acepta
/// nuevos tipos de paso/acci├│n sin modificarse (OCP).
library;

import 'action_verifier.dart';
import 'agent_executor.dart';
import 'agent_result.dart';
import '../perception/nano_selector.dart';

/// Acciones que el loop puede orquestar (ISP: la m├¡nima necesaria).
enum AgentAction { tap, setText }

/// Un paso at├│mico del plan: qu├® actuar + qu├® verificar despu├®s.
/// Value object puro ÔÇö no ejecuta nada (SRP).
class AgentStep {
  /// Identificador legible para traces y el resumen de fallo.
  final String id;

  /// Selector del nodo objetivo (RESOLVE).
  final NanoSelector selector;

  /// Acci├│n a ejecutar.
  final AgentAction action;

  /// Texto a escribir ÔÇö solo para [AgentAction.setText].
  final String? text;

  /// Postcondiciones a verificar tras la acci├│n.
  final ActionExpectation expectation;

  /// Se conserva para compatibilidad de planes serializados previos. El loop
  /// de producción no repite ACT: verifica una sola ejecución y devuelve la
  /// incertidumbre al llamador.
  @Deprecated('AgentLoop no reintenta acciones mutantes')
  final int maxAttempts;

  const AgentStep({
    required this.id,
    required this.selector,
    required this.action,
    this.text,
    required this.expectation,
    this.maxAttempts = 1,
  });
}

/// Resultado de un paso: ejecuci├│n + verificaci├│n + reintentos (evidencia
/// completa para RECORD). [verification] es null si la ACT fall├│ y no se
/// lleg├│ a verificar.
class AgentStepResult {
  final AgentStep step;
  final AgentExecutionResult execution;
  final VerificationOutcome? verification;
  final int attempts;

  const AgentStepResult({
    required this.step,
    required this.execution,
    required this.verification,
    required this.attempts,
  });

  bool get succeeded => execution.ok && (verification?.isVerified ?? false);
}

/// Resultado del bucle completo.
class AgentLoopResult {
  final bool completed;

  /// Resultados de los pasos ejecutados (hasta el fallo, inclusive).
  final List<AgentStepResult> steps;

  /// Paso que abort├│ el plan (null si [completed]).
  final AgentStepResult? failedStep;

  /// Resumen legible en espa├▒ol para UI/traces.
  final String summary;

  const AgentLoopResult({
    required this.completed,
    required this.steps,
    required this.failedStep,
    required this.summary,
  });
}

/// Orquestador del ciclo. Construir con las piezas concretas:
///
/// ```dart
/// final executor = NanoAgentExecutor();
/// final loop = AgentLoop(
///   executor: executor,
///   verifier: ActionVerifier(snapshotFn: executor.snapshot),
/// );
/// ```
///
/// El loop no instancia el verifier por s├¡ mismo: el caller decide c├│mo se
/// cablea el snapshot (DIP).
class AgentLoop {
  AgentLoop({required AgentExecutor executor, required AgentVerifier verifier})
    : _executor = executor,
      _verifier = verifier;

  final AgentExecutor _executor;
  final AgentVerifier _verifier;

  /// Ejecuta el plan paso a paso. Un paso no-verificado aborta el plan con
  /// [AgentLoopResult.failedStep]. No lanza: todo fallo es un resultado
  /// tipado, nunca una excepci├│n.
  Future<AgentLoopResult> run(List<AgentStep> steps) async {
    final results = <AgentStepResult>[];

    for (final step in steps) {
      final result = await _runStep(step);
      results.add(result);
      if (!result.succeeded) {
        return AgentLoopResult(
          completed: false,
          steps: results,
          failedStep: result,
          summary: _failureSummary(result),
        );
      }
    }

    return AgentLoopResult(
      completed: true,
      steps: results,
      failedStep: null,
      summary: '${results.length} paso(s) completados y verificados.',
    );
  }

  Future<AgentStepResult> _runStep(AgentStep step) async {
    // Una acción mutante sin postcondición verificable no llega al dispositivo.
    // El éxito del canal solo confirma el despacho, nunca el efecto real.
    if (!step.expectation.hasCriteria) {
      return AgentStepResult(
        step: step,
        execution: const AgentExecutionResult.failure(
          errorCode: AgentErrorCode.missingVerification,
          reason: 'Acción mutante sin postcondición verificable.',
        ),
        verification: null,
        attempts: 0,
      );
    }

    // OBSERVE antes de ACT para mustChangeSnapshot y para guardar evidencia.
    final preSnapshot = await _executor.snapshot();
    final execution = switch (step.action) {
      AgentAction.tap => await _executor.tap(step.selector),
      AgentAction.setText => await _executor.setText(
        step.selector,
        step.text ?? '',
      ),
    };
    if (!execution.ok) {
      return AgentStepResult(
        step: step,
        execution: execution,
        verification: null,
        attempts: 1,
      );
    }

    // VERIFY ya observa hasta su timeout. Ante incertidumbre no se repite ACT:
    // un tap o un input podían haber producido un efecto externo.
    final expectation =
        step.action == AgentAction.setText &&
            step.expectation.expectedText?.isNotEmpty == true &&
            step.expectation.expectedTextTarget == null
        ? step.expectation.copyWith(expectedTextTarget: step.selector)
        : step.expectation;
    final verification = await _verifier.verify(
      expectation,
      preSnapshot: preSnapshot,
    );
    return AgentStepResult(
      step: step,
      execution: execution,
      verification: verification,
      attempts: 1,
    );
  }

  String _failureSummary(AgentStepResult r) {
    if (!r.execution.ok) {
      return 'Paso "${r.step.id}" fall├│ (${r.execution.errorCode}) tras '
          '${r.attempts} intento(s): ${r.execution.reason}';
    }
    return 'Paso "${r.step.id}" no verificado tras ${r.attempts} intento(s): '
        '${r.verification?.reason}';
  }
}

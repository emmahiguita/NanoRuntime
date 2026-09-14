/// AgentLoop — orquestador del ciclo del agente móvil.
///
/// Cierra el bucle OBSERVE → RESOLVE → ACT → VERIFY → RECORD que las piezas
/// (`NanoAgentExecutor`, `ActionVerifier`, `NanoSelectorEngine`) ya cubren por
/// separado. Aquí solo se ORQUESTA: el loop no ejecuta ni verifica nada
/// directamente (SRP), depende de abstracciones inyectables (DIP), y acepta
/// nuevos tipos de paso/acción sin modificarse (OCP).
library;

import 'action_verifier.dart';
import 'agent_executor.dart';
import 'agent_result.dart';
import '../perception/nano_selector.dart';

/// Acciones que el loop puede orquestar (ISP: la mínima necesaria).
enum AgentAction { tap, setText }

/// Un paso atómico del plan: qué actuar + qué verificar después.
/// Value object puro — no ejecuta nada (SRP).
class AgentStep {
  /// Identificador legible para traces y el resumen de fallo.
  final String id;

  /// Selector del nodo objetivo (RESOLVE).
  final NanoSelector selector;

  /// Acción a ejecutar.
  final AgentAction action;

  /// Texto a escribir — solo para [AgentAction.setText].
  final String? text;

  /// Postcondiciones a verificar tras la acción.
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

/// Resultado de un paso: ejecución + verificación + reintentos (evidencia
/// completa para RECORD). [verification] es null si la ACT falló y no se
/// llegó a verificar.
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

  /// Paso que abortó el plan (null si [completed]).
  final AgentStepResult? failedStep;

  /// Resumen legible en español para UI/traces.
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
/// El loop no instancia el verifier por sí mismo: el caller decide cómo se
/// cablea el snapshot (DIP).
class AgentLoop {
  AgentLoop({required AgentExecutor executor, required AgentVerifier verifier})
    : _executor = executor,
      _verifier = verifier;

  final AgentExecutor _executor;
  final AgentVerifier _verifier;

  /// Ejecuta el plan paso a paso. Un paso no-verificado aborta el plan con
  /// [AgentLoopResult.failedStep]. No lanza: todo fallo es un resultado
  /// tipado, nunca una excepción.
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
            step.expectation.expectedText?.isNotEmpty == true
        ? step.expectation.copyWith(
            expectedTextTarget:
                step.expectation.expectedTextTarget ?? step.selector,
            expectedTextMatch: ExpectedTextMatch.exact,
          )
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
      return 'Paso "${r.step.id}" falló (${r.execution.errorCode}) tras '
          '${r.attempts} intento(s): ${r.execution.reason}';
    }
    return 'Paso "${r.step.id}" no verificado tras ${r.attempts} intento(s): '
        '${r.verification?.reason}';
  }
}

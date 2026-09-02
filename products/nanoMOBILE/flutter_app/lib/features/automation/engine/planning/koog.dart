/// Koog ÔÇö orquestador de workflows de automatizaci├│n (┬º15 del plan).
///
/// Decide el QU├ë (plan) v├¡a un [PlanGenerator]; ejecuta el C├ôMO v├¡a [AgentLoop]
/// bajo la gobernanza de [PolicyEngine]. NO decide el modelo (eso es el
/// runtime) ni el gesto f├¡sico (eso es el executor). Spike: valida el flujo
/// goal ÔåÆ plan ÔåÆ policy ÔåÆ ejecutar ÔåÆ verificar; el vocabulario de tools se
/// limita a tap/write (lo que [AgentLoop] orquesta hoy).
library;

import '../execution/action_verifier.dart';
import '../execution/agent_loop.dart';
import '../perception/nano_selector.dart';
import '../execution/tool_registry.dart';

/// Paso del plan de Koog en vocabulario de TOOLS (`tap`/`write`/...).
/// Value object ÔÇö no ejecuta nada.
class KoogStep {
  /// Nombre can├│nico del tool (ver [ToolRegistry.builtin]).
  final String tool;

  /// Selector DSL (p.ej. `text=Bluetooth`, `id=com.android:id/button1`).
  final String selector;

  /// Texto a escribir ÔÇö solo para `write`.
  final String? text;

  const KoogStep({required this.tool, required this.selector, this.text});
}

/// Genera un plan (secuencia de [KoogStep]) desde un goal. DIP: la fuente es
/// inyectable ÔÇö LLM real, heur├¡stica determinista, o fake en tests.
abstract interface class PlanGenerator {
  Future<List<KoogStep>> plan(String goal);
}

/// Resultado de una ejecuci├│n de Koog.
class KoogRunResult {
  /// True si el plan completo se ejecut├│ y verific├│.
  final bool completed;

  /// Resultado del AgentLoop (null si la pol├¡tica abort├│ antes de ejecutar).
  final AgentLoopResult? loopResult;

  /// Tool denegado por la pol├¡tica (null si no hubo denegaci├│n).
  final String? deniedTool;

  /// Resumen legible en espa├▒ol.
  final String summary;

  const KoogRunResult._({
    required this.completed,
    required this.loopResult,
    required this.deniedTool,
    required this.summary,
  });

  factory KoogRunResult._ok(AgentLoopResult loop) => KoogRunResult._(
    completed: loop.completed,
    loopResult: loop,
    deniedTool: null,
    summary: loop.summary,
  );

  factory KoogRunResult._denied(String tool, String reason) => KoogRunResult._(
    completed: false,
    loopResult: null,
    deniedTool: tool,
    summary: 'Plan abortado por pol├¡tica: $reason',
  );
}

/// Orquestador del workflow. SRP: orquesta, no genera el plan ni ejecuta.
class Koog {
  Koog({
    required PlanGenerator generator,
    required AgentLoop loop,
    PolicyEngine? policy,
  }) : _generator = generator,
       _loop = loop,
       _policy = policy ?? PolicyEngine();

  final PlanGenerator _generator;
  final AgentLoop _loop;
  final PolicyEngine _policy;

  /// Genera el plan y lo ejecuta bajo gobernanza. No lanza: todo fallo es un
  /// [KoogRunResult].
  Future<KoogRunResult> run(String goal) async {
    final plan = await _generator.plan(goal);

    final steps = <AgentStep>[];
    for (final step in plan) {
      final decision = _policy.decide(step.tool, stepsUsed: steps.length);
      if (!decision.allowed) {
        return KoogRunResult._denied(step.tool, decision.reason);
      }
      steps.add(_toAgentStep(step));
    }

    final loop = await _loop.run(steps);
    return KoogRunResult._ok(loop);
  }

  /// Mapea un [KoogStep] (tool) a un [AgentStep] (acci├│n). Solo tap/write en
  /// el spike ÔÇö otros tools (back/notifications/...) requieren ampliar el
  /// executor, no el loop.
  AgentStep _toAgentStep(KoogStep step) {
    final selector = NanoSelector.parse(step.selector);
    return switch (step.tool) {
      'tap' => AgentStep(
        id: 'tap(${step.selector})',
        selector: selector,
        action: AgentAction.tap,
        expectation: const ActionExpectation(mustChangeSnapshot: true),
      ),
      'write' => AgentStep(
        id: 'write(${step.selector})',
        selector: selector,
        action: AgentAction.setText,
        text: step.text ?? '',
        expectation: ActionExpectation(
          expectedText: step.text ?? '',
          expectedTextTarget: selector,
        ),
      ),
      _ => throw UnsupportedError(
        'Tool "${step.tool}" no soportado por el spike Koog '
        '(solo tap/write).',
      ),
    };
  }
}

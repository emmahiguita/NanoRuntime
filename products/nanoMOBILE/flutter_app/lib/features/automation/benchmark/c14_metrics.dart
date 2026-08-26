/// Modelo de métricas del benchmark físico C14-A.
///
/// Mide el planner LLM REAL con el GGUF en el dispositivo. El dato que falta
/// no es de diseño (ya cerraste la arquitectura en `execute(goal)`), sino de
/// CALIDAD del plan que el modelo produce sobre hardware real.
///
/// Cada [C14Execution] es una tarea de la suite; el reporte agrega y aplica
/// los gates. Los gates son la frontera objetiva: si un gate queda rojo,
/// dice QUÉ construir después (prompt/planner, NanoObjectMemory para
/// selectores, StabilityGate para animaciones, PerceptionMux para semántica).
library;

import 'package:nanoai/features/automation/domain/automation_result.dart'
    show AutomationResultStatus;

/// Métricas de una ejecución de la suite C14-A.
class C14Execution {
  final String goal;
  final bool planValid;
  final int toolsGenerated;
  final int toolsRejected;
  final int steps;
  final String path;
  final Duration llmLatency;
  final Duration toolLatency;
  final AutomationResultStatus verification;
  final int retries;
  final int replans;
  final bool cacheHit;
  final bool goalSuccess;
  final Duration totalLatency;

  // A13.6: métricas Candidate-First / legacy.
  final int candidateCount;
  final String selectionMode; // deterministic | koog | legacyFallback | none
  final bool koogInvoked;
  final bool legacyFallback;
  final Duration candidateLatency;

  // A15.3: métricas de tareas cross-app multi-paso.
  final int taskSteps; // pasos del TaskPlan ejecutados
  final int
  crossDomainTransitions; // transiciones notification→linux/browser/app
  final int routeSwitches; // cambios de ruta en recovery
  final bool loopDetected; // se detectó un loop y se detuvo
  final bool zeroLlmTask; // la tarea se descompuso sin LLM (template)

  const C14Execution({
    required this.goal,
    required this.planValid,
    required this.toolsGenerated,
    required this.toolsRejected,
    required this.steps,
    required this.path,
    required this.llmLatency,
    required this.toolLatency,
    required this.verification,
    required this.retries,
    required this.replans,
    required this.cacheHit,
    required this.goalSuccess,
    required this.totalLatency,
    this.candidateCount = 0,
    this.selectionMode = 'none',
    this.koogInvoked = false,
    this.legacyFallback = false,
    this.candidateLatency = Duration.zero,
    this.taskSteps = 0,
    this.crossDomainTransitions = 0,
    this.routeSwitches = 0,
    this.loopDetected = false,
    this.zeroLlmTask = false,
  });
}

/// Resultado agregado del benchmark + veredicto de cada gate.
class C14BenchmarkReport {
  final List<C14Execution> executions;
  final List<C14GateResult> gates;
  final int total;
  final int passed;
  final double successRate;

  // A13.6: tasas de selección/legacy/LLM.
  final double legacyFallbackRate;
  final double zeroLlmRate;
  final double koogInvocationRate;

  // A15.3: métricas de tareas cross-app.
  final int taskStepTotal;
  final int crossDomainTransitions;
  final int loopDetectedCount;
  final double zeroLlmTaskRate;

  const C14BenchmarkReport({
    required this.executions,
    required this.gates,
    required this.total,
    required this.passed,
    required this.successRate,
    required this.legacyFallbackRate,
    required this.zeroLlmRate,
    required this.koogInvocationRate,
    this.taskStepTotal = 0,
    this.crossDomainTransitions = 0,
    this.loopDetectedCount = 0,
    this.zeroLlmTaskRate = 0.0,
  });

  bool get gatedPass => gates.every((g) => g.pass);
}

/// Un gate del benchmark con su umbral y veredicto.
class C14GateResult {
  final String name;
  final double value;
  final double threshold;
  final bool pass;

  const C14GateResult({
    required this.name,
    required this.value,
    required this.threshold,
    required this.pass,
  });
}

/// Gates iniciales de C14-A. Umbrales del plan maestro:
///   >=90% planes parseables/válidos; >=80% éxito en tareas simples;
///   0 tools desconocidas; 0 bypass de política; 0 false success;
///   0 crash. (Los "0" se evalúan como tasa del total.)
class C14Gates {
  const C14Gates();

  C14BenchmarkReport evaluate(List<C14Execution> ex) {
    final total = ex.length;
    final passed = ex.where((e) => e.goalSuccess).length;
    final validPlans = ex.where((e) => e.planValid).length;
    final toolsGenerated = ex.fold<int>(0, (s, e) => s + e.toolsGenerated);
    final toolsRejected = ex.fold<int>(0, (s, e) => s + e.toolsRejected);
    final unknownToolsRate = toolsGenerated == 0
        ? 0.0
        : toolsRejected / toolsGenerated.toDouble();
    final falseSuccess = ex.where((e) => e.goalSuccess && !e.planValid).length;

    final gates = <C14GateResult>[
      C14GateResult(
        name: 'planes válidos (>=90%)',
        value: _ratio(validPlans, total),
        threshold: 0.90,
        pass: _ratio(validPlans, total) >= 0.90,
      ),
      C14GateResult(
        name: 'éxito tareas simples (>=80%)',
        value: _ratio(passed, total),
        threshold: 0.80,
        pass: _ratio(passed, total) >= 0.80,
      ),
      C14GateResult(
        name: '0 tools desconocidas ejecutadas',
        value: unknownToolsRate,
        threshold: 0.0,
        pass: unknownToolsRate <= 0.0,
      ),
      C14GateResult(
        name: '0 false success (éxito sin plan válido)',
        value: falseSuccess.toDouble(),
        threshold: 0.0,
        pass: falseSuccess == 0,
      ),
    ];

    return C14BenchmarkReport(
      executions: ex,
      gates: gates,
      total: total,
      passed: passed,
      successRate: _ratio(passed, total),
      legacyFallbackRate: _ratio(
        ex.where((e) => e.legacyFallback).length,
        total,
      ),
      zeroLlmRate: _ratio(
        ex.where((e) => e.llmLatency == Duration.zero).length,
        total,
      ),
      koogInvocationRate: _ratio(ex.where((e) => e.koogInvoked).length, total),
      taskStepTotal: ex.fold<int>(0, (s, e) => s + e.taskSteps),
      crossDomainTransitions: ex.fold<int>(
        0,
        (s, e) => s + e.crossDomainTransitions,
      ),
      loopDetectedCount: ex.where((e) => e.loopDetected).length,
      zeroLlmTaskRate: _ratio(ex.where((e) => e.zeroLlmTask).length, total),
    );
  }

  static double _ratio(int n, int total) =>
      total == 0 ? 0.0 : n / total.toDouble();
}

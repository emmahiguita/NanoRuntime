/// Harness del benchmark físico C14-A — mide el planner LLM REAL en el
/// dispositivo (CPH2557) con el GGUF cargado.
///
/// Para cada tarea de la suite, invoca [AutomationCoordinator.execute] (que
/// planea→ejecuta→verifica→aprende) y recoge la [C14Execution] via el sink.
/// Luego agrega con [C14Gates]:
///   >=90% planes válidos (parseables sobre tools conocidas)
///   >=80% éxito en tareas simples
///   0 tools desconocidas ejecutadas
///   0 false success (éxito sin plan válido)
///
/// Veredicto por gate → dice QUÉ construir después:
///   - plan inválido/tool equivocada → prompt/planner.
///   - tool correcta pero selector falla → C10 NanoObjectMemory.
///   - target cambia en animación → StabilityGate.
///   - sin semántica (botón sin text/id) → C12 PerceptionMux.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/automation_coordinator.dart';
import '../application/automation_coordinator_provider.dart'
    show automationCoordinatorProvider;
import '../domain/automation_goal.dart' show AutomationGoal, AutomationOptions;
import 'c14_metrics.dart';

/// Suite de tareas diagnósticas de C14-A (10-20 reales).
class C14Suite {
  final String name;
  final List<String> tasks;

  const C14Suite({required this.name, required this.tasks});
}

/// Suite por defecto del plan maestro.
const C14Suite defaultSuite = C14Suite(
  name: 'diagnóstico corto',
  tasks: [
    'abrir Ajustes',
    'abrir Bluetooth',
    'abrir Wi-Fi',
    'volver atrás',
    'escribir en el campo',
    'abre Ajustes, luego Bluetooth, y vuelve',
    'dime si Bluetooth está activado',
    'abrir una app con cache miss',
    'repetir la anterior (cache hit)',
    'comando deliberadamente inválido',
  ],
);

/// Harness: construye un coordinator con sink de métricas, corre la suite y
/// produce el reporte con veredicto de gates.
class C14Benchmark {
  final List<C14Execution> _executions = <C14Execution>[];

  /// Construye el coordinator REAL (con planner LLM inyectado) enlazando el
  /// sink de métricas. DIP: en tests se sustituye por un fake.
  final AutomationCoordinator Function(void Function(C14Execution) sink)
      _buildCoordinator;

  late final AutomationCoordinator _coordinator;

  C14Benchmark({required AutomationCoordinator Function(void Function(C14Execution)) buildCoordinator})
      : _buildCoordinator = buildCoordinator {
    _coordinator = _buildCoordinator(_executions.add);
  }

  List<C14Execution> get executions => List.unmodifiable(_executions);

  Future<C14BenchmarkReport> run(
    C14Suite suite, {
    void Function(int index, String goal)? onStart,
    void Function(C14Execution)? onExecution,
  }) async {
    for (var i = 0; i < suite.tasks.length; i++) {
      final task = suite.tasks[i];
      onStart?.call(i, task);
      final before = _executions.length;
      await _coordinator.execute(
        AutomationGoal(text: task),
        options: const AutomationOptions(confirmed: true),
      );
      if (onExecution != null && _executions.length > before) {
        onExecution(_executions.last);
      }
    }
    return C14Gates().evaluate(_executions);
  }
}

/// Construye el coordinator REAL del módulo para el benchmark on-device
/// (planter LLM + engine + ledger compartido), con el sink de métricas.
AutomationCoordinator buildBenchmarkCoordinator(
  Ref ref,
  void Function(C14Execution) sink,
) {
  // El sink se compone con el provider del coordinator para no duplicar el
  // cableado del motor. Ver automation_coordinator_provider.dart (fuente de
  // verdad de la DI del módulo).
  final base = ref.read(automationCoordinatorProvider);
  return base.withSink(sink);
}

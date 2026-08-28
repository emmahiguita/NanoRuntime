/// A15.0 — Modelo tipado de orquestación multi-paso cross-domain.
///
/// Un TaskPlan descompone UNA intención en TaskSteps con bindings tipados entre
/// dominios. NO es un workflow engine libre: pasos = semántica, valores =
/// tipos, y la ejecución sigue siendo Candidate-First aguas abajo.
library;

/// Referencia estable a un valor intermedio producido por un paso.
final class TaskValueId {
  final String value;
  const TaskValueId(this.value);
  @override
  String toString() => value;
  @override
  bool operator ==(Object other) =>
      other is TaskValueId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Valores intermedios TIPADOS. Nunca se pasan Map<String,dynamic> arbitrarios.
sealed class TaskValue {
  const TaskValue();
}

class TextValue extends TaskValue {
  const TextValue(this.text);
  final String text;
}

/// URL http/https (ya validada en A14.9). No intent://, file://, content://.
class UrlValue extends TaskValue {
  const UrlValue(this.url);
  final String url;
}

class FilePathValue extends TaskValue {
  const FilePathValue(this.path);
  final String path;
}

class PackageValue extends TaskValue {
  const PackageValue(this.packageName);
  final String packageName;
}

class NotificationValue extends TaskValue {
  const NotificationValue({required this.key, required this.sender});
  final String key;
  final String sender;
}

/// Enlace de un paso a un valor intermedio producido por un paso previo.
/// `paramName` = nombre del argumento que consume el valor en el CandidateAction.
final class TaskInputBinding {
  final String paramName;
  final TaskValueId source;
  const TaskInputBinding(this.paramName, this.source);
}

/// Paso semántico de un plan. NO ejecuta directamente; pide CandidateActions al
/// pipeline Candidate-First. La semántica es acotada (taxonomía finita).
final class TaskStep {
  final String id;
  final String semanticAction;
  final Map<String, TaskInputBinding> inputBindings;

  /// Valor tipado que produce este paso (si es observación/extracción).
  final TaskValueId? produces;

  /// Ids de pasos de los que depende (para validación topológica).
  final List<String> dependencies;

  const TaskStep({
    required this.id,
    required this.semanticAction,
    this.inputBindings = const {},
    this.produces,
    this.dependencies = const [],
  });
}

/// Plan tipado. Se compila UNA vez desde el goal confiable; los pasos comparten
/// la misma intención original.
final class TaskPlan {
  final String goal;
  final List<TaskStep> steps;
  final int maxSteps;

  const TaskPlan({required this.goal, required this.steps, this.maxSteps = 8});

  /// Valida: sin ciclos, dependencias conocidas, sin exceder maxSteps.
  /// Devuelve el primer motivo de rechazo o null si es válido.
  String? validate() {
    if (steps.isEmpty) return 'plan vacío';
    if (steps.length > maxSteps) return 'excede maxSteps=$maxSteps';
    final ids = steps.map((s) => s.id).toSet();
    if (ids.length != steps.length) return 'ids duplicados';

    // Detección de ciclos por DFS (topológica simple).
    final visiting = <String>{};
    final visited = <String>{};
    String? visit(String id) {
      if (visiting.contains(id)) return 'ciclo en $id';
      if (visited.contains(id)) return null;
      final step = steps.firstWhere((s) => s.id == id);
      visiting.add(id);
      for (final d in step.dependencies) {
        if (!ids.contains(d)) return 'dependencia desconocida $d en $id';
        final r = visit(d);
        if (r != null) return r;
      }
      visiting.remove(id);
      visited.add(id);
      return null;
    }

    for (final s in steps) {
      final r = visit(s.id);
      if (r != null) return r;
    }
    return null;
  }

  /// Pasos en orden topológico (dependencias antes que dependientes).
  List<TaskStep> get ordered {
    final result = <TaskStep>[];
    final done = <String>{};
    final remaining = [...steps];
    while (remaining.isNotEmpty) {
      var progressed = false;
      for (var i = 0; i < remaining.length; i++) {
        final s = remaining[i];
        if (s.dependencies.every(done.contains)) {
          result.add(s);
          done.add(s.id);
          remaining.removeAt(i);
          progressed = true;
          break;
        }
      }
      if (!progressed) {
        // No debería ocurrir tras validate(); por robustez, devolver el resto.
        result.addAll(remaining);
        break;
      }
    }
    return result;
  }
}

/// Resultado tipado de un paso (sección 20). Sin bool genérico.
enum TaskStepStatus {
  completed,
  completedUnverified,
  denied,
  needsConfirmation,
  needsMoreEvidence,
  failed,
}

/// A15.1 — clasificación tipada del fallo de un paso. Determina si es
/// RECUPERABLE (se puede reintentar/cambiar de ruta) o TERMINAL (stop).
enum TaskFailureKind {
  /// Fallo transitorio o de ruta: reintentar/cambiar de ruta es seguro.
  recoverable,

  /// Fallo terminal: denegado, sin datos, cancelado, o sin progreso. No replan.
  terminal,

  /// Sin clasificación (no falló).
  none,
}

final class TaskStepResult {
  final TaskStepStatus status;
  final String reason;

  /// Valor producido (solo si completed).
  final TaskValue? output;

  /// Clasificación del fallo (A15.1). null/`none` = no es un fallo.
  final TaskFailureKind failureKind;

  const TaskStepResult({
    required this.status,
    required this.reason,
    this.output,
    this.failureKind = TaskFailureKind.none,
  });

  bool get isCompleted => status == TaskStepStatus.completed;

  /// Fallo REAL (detiene la tarea): todo lo que no es completed ni
  /// completedUnverified. T2.7: completedUnverified NO es fallo (se ejecutó,
  /// solo falta verificación), no debe mapearse a `failed` aguas arriba.
  bool get isFailure =>
      status != TaskStepStatus.completed &&
      status != TaskStepStatus.completedUnverified;

  /// Si el fallo admite recuperación acotada (reintento/cambio de ruta).
  bool get isRecoverable => failureKind == TaskFailureKind.recoverable;
}

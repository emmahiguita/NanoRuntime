/// NanoTranscriptLedger & VisualStepSummarizer — Memoria Operativa de Nano
///
/// Implementa la gestión de memoria eficiente y poda de contexto nativa de Nano:
/// - Mantiene un registro cronológico de pasos ejecutados por el agente móvil.
/// - Aplica poda estricta (pruning) de árboles a11y pesados y bitmaps de pasos
///   antiguos para evitar desbordar la memoria RAM y el presupuesto de tokens.
/// - Conserva únicamente una ventana operativa corta (1-2 pasos recientes) con
///   datos completos de nodos.
/// - Genera un sumario semántico estructurado de hitos accesible para el
///   modelo de lenguaje y los engines de decisión.
library;

import '../perception/nano_snapshot.dart';

/// Registro estructurado de un paso individual en el ciclo del agente.
final class TranscriptStepRecord {
  TranscriptStepRecord({
    required this.stepIndex,
    required this.actionName,
    required this.actionDescription,
    required this.executionOk,
    required this.verificationOk,
    required this.summary,
    this.packageName = '',
    this.targetLabel,
    this.metadata = const {},
    this.snapshot,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now(),
       isPruned = snapshot == null;

  final int stepIndex;
  final DateTime timestamp;
  final String actionName;
  final String actionDescription;
  final bool executionOk;
  final bool verificationOk;
  final String summary;
  final String packageName;
  final String? targetLabel;
  final Map<String, Object?> metadata;

  /// Snapshot enriquecido del estado observado. NULO si fue podado.
  NanoSnapshot? snapshot;
  bool isPruned;

  bool get succeeded => executionOk && verificationOk;

  /// Poda la estructura pesada del snapshot para liberar memoria de contexto.
  void pruneHeavyState() {
    snapshot = null;
    isPruned = true;
  }

  Map<String, Object?> toSummaryMap() => {
    'step': stepIndex,
    'action': actionName,
    'package': packageName,
    'target': targetLabel ?? '',
    'ok': succeeded,
    'summary': summary,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Resumidor semántico de transiciones visuales y de estado (VisualStepSummarizer).
abstract interface class NanoStepSummarizer {
  String summarizeStep({
    required String actionName,
    required String actionDescription,
    required bool executionOk,
    required bool verificationOk,
    String? previousPackage,
    String? currentPackage,
    String? targetLabel,
    String? observedOutcome,
  });
}

/// Implementación determinista por defecto del resumidor semántico.
class DefaultStepSummarizer implements NanoStepSummarizer {
  const DefaultStepSummarizer();

  @override
  String summarizeStep({
    required String actionName,
    required String actionDescription,
    required bool executionOk,
    required bool verificationOk,
    String? previousPackage,
    String? currentPackage,
    String? targetLabel,
    String? observedOutcome,
  }) {
    if (!executionOk) {
      return 'Fallo de ejecución en $actionName: $actionDescription';
    }
    if (!verificationOk) {
      return 'Acción ejecutada pero no verificada: $actionDescription';
    }

    final targetInfo = targetLabel != null && targetLabel.isNotEmpty
        ? " sobre '$targetLabel'"
        : '';

    final transition =
        (previousPackage != null &&
            currentPackage != null &&
            previousPackage != currentPackage &&
            currentPackage.isNotEmpty)
        ? ' -> Transición a $currentPackage'
        : '';

    final outcome = observedOutcome != null && observedOutcome.isNotEmpty
        ? ' -> $observedOutcome'
        : '';

    return '$actionName$targetInfo: completado con éxito$transition$outcome.';
  }
}

/// Ledger cronológico de pasos con ventana operativa y compresión de contexto.
final class NanoTranscriptLedger {
  NanoTranscriptLedger({
    this.maxOperativeWindow = 2,
    this.summarizer = const DefaultStepSummarizer(),
  }) : assert(maxOperativeWindow >= 1, 'maxOperativeWindow debe ser >= 1');

  /// Número de pasos recientes que conservan su snapshot completo sin podar.
  final int maxOperativeWindow;
  final NanoStepSummarizer summarizer;

  final List<TranscriptStepRecord> _records = [];

  List<TranscriptStepRecord> get allSteps => List.unmodifiable(_records);

  int get totalSteps => _records.length;

  bool get isEmpty => _records.isEmpty;

  /// Devuelve los registros de la ventana operativa reciente (con snapshot disponible si no fue podado).
  List<TranscriptStepRecord> get operativeWindow {
    if (_records.length <= maxOperativeWindow) {
      return List.unmodifiable(_records);
    }
    return List.unmodifiable(
      _records.sublist(_records.length - maxOperativeWindow),
    );
  }

  /// Registra un nuevo paso y aplica poda automática a los pasos fuera de la ventana.
  TranscriptStepRecord recordStep({
    required String actionName,
    required String actionDescription,
    required bool executionOk,
    required bool verificationOk,
    NanoSnapshot? postSnapshot,
    String? targetLabel,
    String? observedOutcome,
    Map<String, Object?> metadata = const {},
  }) {
    final previousPackage = _records.isNotEmpty
        ? _records.last.packageName
        : null;
    final currentPackage = postSnapshot?.package ?? '';

    final summary = summarizer.summarizeStep(
      actionName: actionName,
      actionDescription: actionDescription,
      executionOk: executionOk,
      verificationOk: verificationOk,
      previousPackage: previousPackage,
      currentPackage: currentPackage,
      targetLabel: targetLabel,
      observedOutcome: observedOutcome,
    );

    final record = TranscriptStepRecord(
      stepIndex: _records.length + 1,
      actionName: actionName,
      actionDescription: actionDescription,
      executionOk: executionOk,
      verificationOk: verificationOk,
      summary: summary,
      packageName: currentPackage,
      targetLabel: targetLabel,
      metadata: metadata,
      snapshot: postSnapshot,
    );

    _records.add(record);
    _enforcePruning();
    return record;
  }

  /// Genera un resumen textual compacto de todos los pasos para alimentar el prompt del agente.
  String buildContextSummary() {
    if (_records.isEmpty) return 'Sin acciones previas registradas.';

    final buffer = StringBuffer();
    buffer.writeln('### Historial Estructurado de Acciones:');
    for (final step in _records) {
      final status = step.succeeded ? '✓' : '✗';
      buffer.writeln(
        '[$status] Paso ${step.stepIndex} (${step.actionName}): ${step.summary}',
      );
    }
    return buffer.toString().trim();
  }

  /// Limpia todo el historial.
  void clear() {
    for (final record in _records) {
      record.pruneHeavyState();
    }
    _records.clear();
  }

  void _enforcePruning() {
    if (_records.length <= maxOperativeWindow) return;
    final cutoffIndex = _records.length - maxOperativeWindow;
    for (var i = 0; i < cutoffIndex; i++) {
      if (!_records[i].isPruned) {
        _records[i].pruneHeavyState();
      }
    }
  }
}

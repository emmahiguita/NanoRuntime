import 'tool_outcome.dart';

/// Mantiene estado y contenido separados: texto como "[INFO]" no significa fallo.
class ToolExecutionReport {
  const ToolExecutionReport(this.feedback, this.status, {this.data});
  final String feedback;
  final ToolExecutionStatus status;
  final Map<String, Object?>? data;

  /// Compatibilidad de manejadores antiguos; MCP proporciona su estado tipado.
  factory ToolExecutionReport.legacy(String feedback) {
    final status = feedback.startsWith('[completed]')
        ? ToolExecutionStatus.completed
        : feedback.startsWith('[completedUnverified]')
        ? ToolExecutionStatus.completedUnverified
        : feedback.startsWith('[timeoutOutcomeUnknown]')
        ? ToolExecutionStatus.outcomeUnknown
        : RegExp(r'^\[[a-zA-Z]+(:|\])').hasMatch(feedback)
        ? ToolExecutionStatus.failed
        : ToolExecutionStatus.completed;
    return ToolExecutionReport(feedback, status);
  }
}

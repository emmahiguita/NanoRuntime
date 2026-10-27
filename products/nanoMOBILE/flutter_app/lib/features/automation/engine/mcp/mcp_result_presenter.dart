import 'dart:convert';
import '../execution/tool_execution_report.dart';
import '../execution/tool_outcome.dart';
import 'mcp_client_port.dart';

/// Traduce datos MCP sin deducir éxito por el primer carácter del texto remoto.
abstract final class McpResultPresenter {
  static ToolExecutionReport present(
    McpToolCallResult result, {
    required bool mutating,
  }) {
    if (!result.success) {
      final uncertain =
          mutating &&
          !const {
            McpOperationStatus.denied,
            McpOperationStatus.unavailable,
            McpOperationStatus.unsupported,
          }.contains(result.status);
      return ToolExecutionReport(
        result.message ?? result.errorCode ?? result.status.name,
        uncertain
            ? ToolExecutionStatus.outcomeUnknown
            : ToolExecutionStatus.failed,
      );
    }
    final sections = <String>[];
    for (final item in result.content) {
      if (item.text?.isNotEmpty == true) sections.add(item.text!);
      if (item.type != 'text') {
        sections.add(
          'Adjunto MCP: ${item.type} (${item.mimeType ?? "tipo no declarado"}). '
          'No se ha interpretado mediante un modelo visual o de audio.',
        );
        if (item.uri != null) sections.add('Referencia publicada: ${item.uri}');
      }
    }
    if (sections.isEmpty && result.structuredContent != null) {
      sections.add(jsonEncode(result.structuredContent));
    }
    var feedback = sections.isEmpty
        ? 'La herramienta devolvió éxito sin contenido.'
        : sections.join('\n');
    if (feedback.length > 24000) {
      feedback =
          '${feedback.substring(0, 24000)}\n[Contenido parcial: límite de presentación.]';
    }
    final verified = result.metadata['verified'] == true;
    return ToolExecutionReport(
      feedback,
      mutating && !verified
          ? ToolExecutionStatus.completedUnverified
          : ToolExecutionStatus.completed,
      data: result.structuredContent,
    );
  }
}

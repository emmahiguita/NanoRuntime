part of 'local_device_mcp_client.dart';

/// Convierte selectores, evidencias y errores sin acoplarlos al transporte.
extension _LocalDeviceResults on LocalDeviceMcpClient {
  bool _isTool(String received, String expected) =>
      received == expected ||
      received == 'device.$expected' ||
      received == 'device/$expected';

  _ParsedSelector _selectorFrom(McpToolCall call) {
    final expression = (call.arguments['selector'] as String?)?.trim() ?? '';
    if (expression.isEmpty) {
      return _ParsedSelector.error(
        _failure(
          McpOperationStatus.failed,
          'BAD_SELECTOR',
          'selector es requerido.',
        ),
      );
    }
    try {
      return _ParsedSelector.value(NanoSelector.parse(expression));
    } on SelectorFormatException catch (error) {
      return _ParsedSelector.error(
        _failure(McpOperationStatus.failed, 'BAD_SELECTOR', error.message),
      );
    }
  }

  McpToolCallResult _executorUnavailable() => _failure(
    McpOperationStatus.unavailable,
    'MOBILE_EXECUTOR_OFF',
    'El ejecutor movil no esta conectado a este servidor MCP.',
  );

  McpToolCallResult _executionResult(
    String operation,
    AgentExecutionResult result,
  ) {
    final structured = <String, Object?>{
      'operation': operation,
      'ok': result.ok,
      'errorCode': result.errorCode?.name,
      'reason': result.reason,
      if (result.targetNode != null)
        'target': _nodeToStructured(result.targetNode!),
    };
    return result.ok
        ? _success('$operation completado y ligado al objetivo.', structured)
        : McpToolCallResult(
            status: McpOperationStatus.failed,
            errorCode: result.errorCode?.name ?? 'MOBILE_ACTION_FAILED',
            message: result.reason,
            structuredContent: structured,
          );
  }

  Map<String, Object?> _resolveToStructured(ResolveOutcome outcome) => {
    'status': outcome.status.name,
    'reason': outcome.reason,
    'candidates': [
      for (final candidate in outcome.candidates)
        {
          'score': candidate.score,
          'matchedCriteria': candidate.matchedCriteria,
          'node': _nodeToStructured(candidate.node),
        },
    ],
  };

  Map<String, Object?> _nodeToStructured(NanoNode node) => {
    'index': node.index,
    'package': node.packageName,
    'resourceId': node.id,
    'className': node.type,
    'text': node.password ? '<redacted>' : node.text,
    'description': node.description,
    'hint': node.hint,
    'stateDescription': node.stateDescription,
    'error': node.errorText,
    'bounds': [
      node.bounds.left,
      node.bounds.top,
      node.bounds.right,
      node.bounds.bottom,
    ],
    'clickable': node.clickable,
    'editable': node.editable,
    'scrollable': node.scrollable,
    'checked': node.checked,
    'selected': node.selected,
    'focused': node.focused,
    'visible': node.visible,
    'enabled': node.enabled,
    'windowId': node.windowId,
  };

  McpToolCallResult _success(String message, Map<String, Object?> structured) =>
      McpToolCallResult(
        status: McpOperationStatus.success,
        content: [McpContentItem(type: 'text', text: message)],
        structuredContent: structured,
      );

  McpToolCallResult _failure(
    McpOperationStatus status,
    String code,
    String message,
  ) => McpToolCallResult(status: status, errorCode: code, message: message);
}

final class _ParsedSelector {
  const _ParsedSelector.value(this.value) : error = null;
  const _ParsedSelector.error(this.error) : value = null;

  final NanoSelector? value;
  final McpToolCallResult? error;
}

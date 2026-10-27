part of 'linux_automation_mcp_client.dart';

/// Conserva códigos y verificación del ejecutor. La presentación tiene un límite explícito.
McpToolCallResult _linuxResult<T>(
  LinuxActionResult<T> r, {
  Map<String, Object?>? data,
  String? note,
}) {
  final payload = <String, Object?>{
    'exitCode': r.exitCode,
    'verification': r.verification.toJson(),
  };
  var text = r.executedOk
      ? (data == null ? r.stdout : jsonEncode(data))
      : r.stderr;
  if (text.isEmpty) text = r.verification.details;
  if (note != null) text = '$text\n$note';
  if (text.length > 24000) {
    text =
        '${text.substring(0, 24000)}\n[Resultado parcial: límite de presentación.]';
  }
  // No copiar aquí una lista sin límite a la memoria del modelo.
  payload['output'] = text;
  return McpToolCallResult(
    status: r.executedOk
        ? McpOperationStatus.success
        : McpOperationStatus.failed,
    message: r.executedOk ? null : text,
    content: [McpContentItem(type: 'text', text: text)],
    structuredContent: payload,
    metadata: {'verified': r.executedOk && r.isVerified},
  );
}

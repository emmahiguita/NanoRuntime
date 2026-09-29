import 'mcp_client_port.dart';

/// QUÉ HACE:
/// Parsea respuestas JSON-RPC del protocolo Model Context Protocol (MCP).
///
/// CÓMO FUNCIONA:
/// Convierte las estructuras crudas de `tools/list` y `tools/call` a objetos
/// tipados [McpRemoteTool] y [McpToolCallResult].
///
/// POR QUÉ:
/// Desacopla la lógica de serialización de la capa de transporte HTTP (SRP).
class HttpMcpParser {
  const HttpMcpParser();

  /// Convierte la lista de herramientas crudas a objetos tipados [McpRemoteTool].
  static List<McpRemoteTool> parseTools(
    Map<String, dynamic>? jsonResult,
    String serverId,
  ) {
    final rawTools = jsonResult?['tools'];
    if (rawTools is! List<dynamic>) {
      throw const FormatException('mcp_tools_list_missing_tools_array');
    }
    final result = <McpRemoteTool>[];

    for (final t in rawTools) {
      if (t is! Map<String, dynamic>) continue;
      final name = t['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final desc = t['description'] as String? ?? '';
      final schema = t['inputSchema'] as Map<String, dynamic>? ?? const {};
      final rawAnnotations = t['annotations'];
      final annotations = rawAnnotations is Map<String, dynamic>
          ? rawAnnotations
          : const <String, dynamic>{};

      result.add(
        McpRemoteTool(
          serverId: serverId,
          name: name,
          description: desc,
          inputSchema: schema,
          annotations: McpToolAnnotations(
            readOnlyHint: annotations['readOnlyHint'] == true,
            destructiveHint: annotations['destructiveHint'] == true,
            idempotentHint: annotations['idempotentHint'] == true,
            openWorldHint: annotations['openWorldHint'] != false,
          ),
        ),
      );
    }
    return result;
  }

  /// Convierte el resultado de ejecución de herramienta a [McpToolCallResult].
  static McpToolCallResult parseCallResult(Map<String, dynamic>? jsonResult) {
    final rawContent = jsonResult?['content'] as List<dynamic>? ?? const [];
    final contentList = <McpContentItem>[];

    for (final c in rawContent) {
      if (c is Map<String, dynamic>) {
        contentList.add(
          McpContentItem(
            type: c['type'] as String? ?? 'text',
            text: c['text'] as String?,
            uri: c['uri'] as String?,
            mimeType: c['mimeType'] as String?,
          ),
        );
      }
    }

    return McpToolCallResult(
      status: McpOperationStatus.success,
      content: contentList,
      structuredContent: jsonResult,
    );
  }
}

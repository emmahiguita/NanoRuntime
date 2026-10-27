part of 'http_mcp_client.dart';

/// Recorre cursores sin confundir una primera página con el catálogo completo.
extension _HttpMcpCatalog on HttpMcpClient {
  Future<List<McpRemoteTool>> _listCatalog() async {
    if (state != McpConnectionState.connected) {
      final connection = await connect();
      if (!connection.success) {
        throw McpDiscoveryException(
          'No se pudo conectar: ${connection.message ?? connection.status.name}',
        );
      }
    }
    final watch = Stopwatch()..start();
    final tools = <String, McpRemoteTool>{};
    final cursors = <String>{};
    String? cursor;
    try {
      for (var page = 0; page < 20; page++) {
        final remaining = const Duration(seconds: 30) - watch.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('catalog_deadline');
        }
        final timeout = remaining < requestTimeout ? remaining : requestTimeout;
        final response = await _httpClient.mcpPost(
          resolveMcpHttpEndpoint(descriptor),
          timeout: timeout,
          headers: mcpHttpHeaders(
            descriptor,
            credentialToken: credentialToken,
            sessionId: _sessionId,
            protocolVersion: _protocolVersion,
          ),
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': _nextRequestId++,
            'method': 'tools/list',
            'params': {if (cursor != null) 'cursor': cursor},
          }),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw McpDiscoveryException(
            'Catálogo MCP: HTTP ${response.statusCode}.',
          );
        }
        final data = decodeMcpJsonRpcResponse(response);
        final result = data?['result'];
        if (data?.containsKey('error') == true ||
            result is! Map<String, dynamic>) {
          throw const FormatException('mcp_catalog_invalid_result');
        }
        for (final tool in HttpMcpParser.parseTools(result, descriptor.id)) {
          tools[tool.qualifiedName] = tool;
        }
        if (tools.length > 1000) {
          throw const McpDiscoveryException(
            'El catálogo supera 1000 herramientas.',
          );
        }
        final next = result['nextCursor'];
        if (next == null) return tools.values.toList(growable: false);
        if (next is! String || next.isEmpty || !cursors.add(next)) {
          throw const FormatException('mcp_catalog_invalid_cursor');
        }
        cursor = next;
      }
      throw const McpDiscoveryException('El catálogo supera 20 páginas.');
    } catch (error) {
      _state = McpConnectionState.failed;
      // No se publica una lista parcial como si estuviera completa.
      if (error is McpDiscoveryException) rethrow;
      if (error is TimeoutException) {
        throw const McpDiscoveryException(
          'Se agotó el tiempo del catálogo MCP.',
        );
      }
      throw const McpDiscoveryException('El catálogo MCP no pudo completarse.');
    } finally {
      watch.stop();
    }
  }
}

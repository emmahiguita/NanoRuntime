part of 'http_mcp_client.dart';

/// Negocia protocolo y sesión HTTP sin ejecutar herramientas.
extension _HttpMcpSession on HttpMcpClient {
  // Inicializa MCP; valida transporte/endpoint y conserva el id para diagnosticar errores HTTP.
  Future<McpConnectionResult> _connectSession() async {
    if (_state == McpConnectionState.connected) {
      return McpConnectionResult(
        status: McpOperationStatus.success,
        protocolVersion: _protocolVersion,
        message: 'Conectado a ${descriptor.displayName} exitosamente.',
      );
    }
    _state = McpConnectionState.connecting;
    _sessionId = null;
    _protocolVersion = null;
    Uri? endpoint;
    int? rpcId;
    try {
      endpoint = resolveMcpHttpEndpoint(descriptor);
      rpcId = _nextRequestId++;
      final reqBody = {
        'jsonrpc': '2.0',
        'id': rpcId,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2025-11-25',
          'capabilities': {
            'tools': {'listChanged': true},
          },
          'clientInfo': {'name': 'NanoAI-Mobile', 'version': '1.0.0'},
        },
      };

      final response = await _httpClient.mcpPost(
        endpoint,
        timeout: requestTimeout,
        headers: mcpHttpHeaders(descriptor, credentialToken: credentialToken),
        body: jsonEncode(reqBody),
      );

      if (_closed) throw StateError("mcp_client_closed");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = decodeMcpJsonRpcResponse(response);
        final res = data?['result'] as Map<String, dynamic>?;
        final protoVer = res?['protocolVersion'] as String?;
        const supportedVersions = {
          '2024-11-05',
          '2025-03-26',
          '2025-06-18',
          '2025-11-25',
        };
        if (protoVer == null || !supportedVersions.contains(protoVer)) {
          _state = McpConnectionState.failed;
          return const McpConnectionResult(
            status: McpOperationStatus.unsupported,
            message: 'El servidor MCP negoció una versión no compatible.',
          );
        }
        _protocolVersion = protoVer;
        _sessionId = response.headers['mcp-session-id'];
        final initialized = await _httpClient.mcpPost(
          endpoint,
          timeout: requestTimeout,
          headers: mcpHttpHeaders(
            descriptor,
            credentialToken: credentialToken,
            sessionId: _sessionId,
            protocolVersion: _protocolVersion,
          ),
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'notifications/initialized',
          }),
        );
        if (_closed) throw StateError("mcp_client_closed");
        if (initialized.statusCode < 200 || initialized.statusCode >= 300) {
          _state = McpConnectionState.failed;
          return McpConnectionResult(
            status: McpOperationStatus.failed,
            message: reportMcpHttpFailure(
              serverId: descriptor.id,
              operation: 'notifications/initialized',
              rpcId: rpcId,
              statusCode: initialized.statusCode,
              endpoint: endpoint,
            ),
          );
        }
        _state = McpConnectionState.connected;
        return McpConnectionResult(
          status: McpOperationStatus.success,
          protocolVersion: protoVer,
          message: 'Conectado a ${descriptor.displayName} exitosamente.',
          metadata: res ?? const {},
        );
      } else {
        _state = McpConnectionState.failed;
        return McpConnectionResult(
          status: McpOperationStatus.failed,
          message: reportMcpHttpFailure(
            serverId: descriptor.id,
            operation: 'initialize',
            rpcId: rpcId,
            statusCode: response.statusCode,
            endpoint: endpoint,
          ),
        );
      }
    } on TimeoutException catch (error) {
      _state = McpConnectionState.failed;
      reportMcpTransportFailure(
        serverId: descriptor.id,
        operation: 'initialize',
        error: error,
        endpoint: endpoint,
        rpcId: rpcId,
      );
      return const McpConnectionResult(
        status: McpOperationStatus.timeout,
        message: 'Timeout al conectar con el servidor MCP.',
      );
    } catch (error) {
      _state = McpConnectionState.failed;
      reportMcpTransportFailure(
        serverId: descriptor.id,
        operation: 'initialize',
        error: error,
        endpoint: endpoint,
        rpcId: rpcId,
      );
      return McpConnectionResult(
        status: McpOperationStatus.failed,
        message: 'Error de conexión MCP (${error.runtimeType}).',
      );
    }
  }
}

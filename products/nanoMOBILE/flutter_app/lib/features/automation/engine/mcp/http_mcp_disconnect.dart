part of 'http_mcp_client.dart';

/// Finaliza la sesión remota y libera HTTP aun si DELETE falla.
extension _HttpMcpDisconnect on HttpMcpClient {
  // Cierra la sesión remota cuando el servidor la admite y libera el socket.
  Future<void> _disconnectSession() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      try {
        final endpoint = resolveMcpHttpEndpoint(descriptor);
        await _httpClient
            .delete(
              endpoint,
              headers: mcpHttpHeaders(
                descriptor,
                credentialToken: credentialToken,
                sessionId: sessionId,
                protocolVersion: _protocolVersion,
              ),
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Some servers do not implement explicit session termination.
      }
    }
    _sessionId = null;
    _protocolVersion = null;
    _state = McpConnectionState.disconnected;
    _httpClient.close();
  }
}

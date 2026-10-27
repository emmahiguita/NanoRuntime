/// Cliente JSON-RPC MCP por HTTP Streamable; los fallos se diagnostican sin secretos.
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'mcp_client_port.dart';
import 'http_mcp_parser.dart';
import 'mcp_http_diagnostics.dart';
import 'http_mcp_tool_caller.dart';
import 'mcp_bounded_http.dart';

part 'http_mcp_session.dart';
part 'http_mcp_disconnect.dart';
part 'http_mcp_catalog.dart';

class HttpMcpClient implements McpClientPort {
  HttpMcpClient({
    required this.descriptor,
    this.credentialToken,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _httpClient = httpClient ?? http.Client() {
    _toolCaller = HttpMcpToolCaller(
      descriptor: descriptor,
      credentialToken: credentialToken,
      sessionId: () => _sessionId,
      protocolVersion: () => _protocolVersion,
      httpClient: _httpClient,
      requestTimeout: requestTimeout,
      nextRequestId: () => _nextRequestId++,
      onConnectionFailure: () => _state = McpConnectionState.failed,
    );
  }

  @override
  final McpServerDescriptor descriptor;
  final String? credentialToken;
  final http.Client _httpClient;
  final Duration requestTimeout;

  McpConnectionState _state = McpConnectionState.disconnected;
  int _nextRequestId = 1;
  String? _sessionId;
  String? _protocolVersion;
  late final HttpMcpToolCaller _toolCaller;

  @override
  McpConnectionState get state => _state;

  // Comparte el handshake; no inicia dos sesiones ante llamadas simultáneas.
  Future<McpConnectionResult>? _connecting;
  bool _closed = false;
  @override
  Future<McpConnectionResult> connect() {
    if (_closed) {
      return Future.value(
        const McpConnectionResult(
          status: McpOperationStatus.unavailable,
          message: 'Cliente MCP cerrado.',
        ),
      );
    }
    return _connecting ??= _connectSession().whenComplete(
      () => _connecting = null,
    );
  }

  @override
  Future<void> disconnect() async {
    if (_closed) return;
    _closed = true;
    await _disconnectSession();
  }

  @override
  Future<List<McpRemoteTool>> listTools() => _listCatalog();

  // QUÉ HACE: invoca una herramienta descubierta usando su nombre y argumentos JSON.
  // CÓMO/POR QUÉ: conserva JSON-RPC id y clasifica fallo HTTP, timeout y error MCP por separado.
  @override
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    if (_state != McpConnectionState.connected) {
      final conn = await connect();
      if (!conn.success) {
        return McpToolCallResult(
          status: conn.status,
          message: 'No conectado al servidor MCP: ${conn.message}',
        );
      }
    }
    return _toolCaller.callTool(call);
  }
}

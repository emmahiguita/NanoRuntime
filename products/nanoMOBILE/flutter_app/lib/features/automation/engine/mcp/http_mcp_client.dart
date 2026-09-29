/// Cliente JSON-RPC MCP por HTTP Streamable; los fallos se diagnostican sin secretos.
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'mcp_client_port.dart';
import 'http_mcp_parser.dart';
import 'mcp_http_diagnostics.dart';
import 'http_mcp_tool_caller.dart';

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

  // Inicializa MCP; valida transporte/endpoint y conserva el id para diagnosticar errores HTTP.
  @override
  Future<McpConnectionResult> connect() async {
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

      final response = await _httpClient
          .post(
            endpoint,
            headers: mcpHttpHeaders(
              descriptor,
              credentialToken: credentialToken,
            ),
            body: jsonEncode(reqBody),
          )
          .timeout(requestTimeout);

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
        final initialized = await _httpClient
            .post(
              endpoint,
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
            )
            .timeout(requestTimeout);
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

  // Cierra la sesión remota cuando el servidor la admite y libera el socket.
  @override
  Future<void> disconnect() async {
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

  // Descubre herramientas y registra fallos HTTP en vez de ocultar un 404 como lista vacía.
  @override
  Future<List<McpRemoteTool>> listTools() async {
    if (_state != McpConnectionState.connected) {
      final conn = await connect();
      if (!conn.success) {
        throw McpDiscoveryException(
          'MCP tools/list no pudo conectar (${conn.status.name}).',
        );
      }
    }
    Uri? endpoint;
    int? rpcId;
    try {
      endpoint = resolveMcpHttpEndpoint(descriptor);
      rpcId = _nextRequestId++;
      final reqBody = {
        'jsonrpc': '2.0',
        'id': rpcId,
        'method': 'tools/list',
        'params': const {},
      };

      final response = await _httpClient
          .post(
            endpoint,
            headers: mcpHttpHeaders(
              descriptor,
              credentialToken: credentialToken,
              sessionId: _sessionId,
              protocolVersion: _protocolVersion,
            ),
            body: jsonEncode(reqBody),
          )
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = decodeMcpJsonRpcResponse(response);
        if (data == null || data.containsKey('error')) {
          throw const FormatException('mcp_tools_list_jsonrpc_error');
        }
        final rawResult = data['result'];
        if (rawResult is! Map<String, dynamic>) {
          throw const FormatException('mcp_tools_list_missing_result');
        }
        final res = rawResult;
        return HttpMcpParser.parseTools(res, descriptor.id);
      }
      _state = McpConnectionState.failed;
      reportMcpHttpFailure(
        serverId: descriptor.id,
        operation: 'tools/list',
        rpcId: rpcId,
        statusCode: response.statusCode,
        endpoint: endpoint,
      );
      throw McpDiscoveryException(
        'MCP tools/list falló (HTTP ${response.statusCode}).',
      );
    } on TimeoutException catch (error) {
      _state = McpConnectionState.failed;
      reportMcpTransportFailure(
        serverId: descriptor.id,
        operation: 'tools/list',
        error: error,
        endpoint: endpoint,
        rpcId: rpcId,
      );
      throw const McpDiscoveryException('MCP tools/list agotó el tiempo.');
    } on FormatException catch (error) {
      _state = McpConnectionState.failed;
      reportMcpTransportFailure(
        serverId: descriptor.id,
        operation: 'tools/list',
        error: error,
        endpoint: endpoint,
        rpcId: rpcId,
      );
      throw const McpDiscoveryException(
        'MCP tools/list devolvió una respuesta inválida.',
      );
    } catch (error) {
      if (error is McpDiscoveryException) rethrow;
      _state = McpConnectionState.failed;
      reportMcpTransportFailure(
        serverId: descriptor.id,
        operation: 'tools/list',
        error: error,
        endpoint: endpoint,
        rpcId: rpcId,
      );
      throw McpDiscoveryException(
        'MCP tools/list falló (${error.runtimeType}).',
      );
    }
  }

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

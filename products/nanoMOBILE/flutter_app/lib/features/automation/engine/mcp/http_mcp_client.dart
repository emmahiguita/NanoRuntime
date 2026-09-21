/// HttpMcpClient — cliente real para servidores MCP remotos o locales (HTTP/SSE).
///
/// Implementa la especificación Model Context Protocol (MCP) mediante JSON-RPC 2.0:
/// - Handshake inicial `initialize`
/// - Descubrimiento de herramientas `tools/list`
/// - Ejecución segura de herramientas `tools/call`
///
/// Diseñado bajo principios SOLID (Single Responsibility, Liskov Substitution).
library;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'mcp_client_port.dart';
import 'http_mcp_parser.dart';

class HttpMcpClient implements McpClientPort {
  HttpMcpClient({
    required this.descriptor,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 12),
  }) : _httpClient = httpClient ?? http.Client();

  @override
  final McpServerDescriptor descriptor;
  final http.Client _httpClient;
  final Duration requestTimeout;

  McpConnectionState _state = McpConnectionState.disconnected;
  int _nextRequestId = 1;

  @override
  McpConnectionState get state => _state;

  Uri get _endpointUri {
    final ep = descriptor.endpoint?.trim() ?? '';
    if (ep.isEmpty) {
      throw StateError('El descriptor no tiene un endpoint configurado.');
    }
    return Uri.parse(ep);
  }

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
    };
    if (descriptor.credentialRef != null && descriptor.credentialRef!.isNotEmpty) {
      h['Authorization'] = 'Bearer ${descriptor.credentialRef}';
    }
    return h;
  }

  @override
  Future<McpConnectionResult> connect() async {
    _state = McpConnectionState.connecting;
    try {
      final reqBody = {
        'jsonrpc': '2.0',
        'id': _nextRequestId++,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': {'listChanged': true},
          },
          'clientInfo': {
            'name': 'NanoAI-Mobile',
            'version': '1.0.0',
          },
        },
      };

      final response = await _httpClient
          .post(_endpointUri, headers: _headers, body: jsonEncode(reqBody))
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _state = McpConnectionState.connected;
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final res = data?['result'] as Map<String, dynamic>?;
        final protoVer = res?['protocolVersion'] as String? ?? '2024-11-05';
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
          message: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on TimeoutException {
      _state = McpConnectionState.failed;
      return const McpConnectionResult(
        status: McpOperationStatus.timeout,
        message: 'Timeout al conectar con el servidor MCP.',
      );
    } catch (e) {
      _state = McpConnectionState.failed;
      return McpConnectionResult(
        status: McpOperationStatus.failed,
        message: 'Error de conexión: $e',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    _state = McpConnectionState.disconnected;
    _httpClient.close();
  }

  @override
  Future<List<McpRemoteTool>> listTools() async {
    if (_state != McpConnectionState.connected) {
      final conn = await connect();
      if (!conn.success) return const [];
    }

    try {
      final reqBody = {
        'jsonrpc': '2.0',
        'id': _nextRequestId++,
        'method': 'tools/list',
        'params': const {},
      };

      final response = await _httpClient
          .post(_endpointUri, headers: _headers, body: jsonEncode(reqBody))
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final res = data?['result'] as Map<String, dynamic>?;
        return HttpMcpParser.parseTools(res, descriptor.id);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

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

    try {
      final reqBody = {
        'jsonrpc': '2.0',
        'id': _nextRequestId++,
        'method': 'tools/call',
        'params': {
          'name': call.toolName,
          'arguments': call.arguments,
        },
      };

      final response = await _httpClient
          .post(_endpointUri, headers: _headers, body: jsonEncode(reqBody))
          .timeout(requestTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        if (data?['error'] != null) {
          final err = data!['error'] as Map<String, dynamic>;
          return McpToolCallResult(
            status: McpOperationStatus.failed,
            errorCode: err['code']?.toString(),
            message: err['message'] as String? ?? 'Error remoto en tool',
          );
        }

        final res = data?['result'] as Map<String, dynamic>?;
        return HttpMcpParser.parseCallResult(res);
      }

      return McpToolCallResult(
        status: McpOperationStatus.failed,
        message: 'HTTP ${response.statusCode}: ${response.body}',
      );
    } on TimeoutException {
      return const McpToolCallResult(
        status: McpOperationStatus.timeout,
        message: 'La llamada a la herramienta excedió el tiempo límite.',
      );
    } catch (e) {
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        message: 'Excepción durante ejecución MCP: $e',
      );
    }
  }
}

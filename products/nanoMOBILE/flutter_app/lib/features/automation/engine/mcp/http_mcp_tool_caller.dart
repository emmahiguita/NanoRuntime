/// Sends one MCP tools/call request and translates HTTP/RPC failures safely.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_mcp_parser.dart';
import 'mcp_client_port.dart';
import 'mcp_http_diagnostics.dart';

Map<String, dynamic>? decodeMcpJsonRpcResponse(http.Response response) {
  if (response.headers['content-type']?.contains('text/event-stream') != true) {
    return jsonDecode(response.body) as Map<String, dynamic>?;
  }
  for (final event in response.body.split(RegExp(r'\r?\n\r?\n'))) {
    final data = event
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trimLeft())
        .join('\n');
    if (data.isEmpty) continue;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic> &&
          (decoded.containsKey('result') || decoded.containsKey('error'))) {
        return decoded;
      }
    } on FormatException {
      continue;
    }
  }
  throw const FormatException('mcp_sse_response_missing_rpc_result');
}

class HttpMcpToolCaller {
  HttpMcpToolCaller({
    required this.descriptor,
    this.credentialToken,
    required this.sessionId,
    required this.protocolVersion,
    required this.httpClient,
    required this.requestTimeout,
    required this.nextRequestId,
    required this.onConnectionFailure,
  });

  final McpServerDescriptor descriptor;
  final String? credentialToken;
  final String? Function() sessionId;
  final String? Function() protocolVersion;
  final http.Client httpClient;
  final Duration requestTimeout;
  final int Function() nextRequestId;
  // QUÉ HACE: notifica al cliente de sesión para que refleje el fallo de transporte.
  final void Function() onConnectionFailure;

  // QUÉ HACE: ejecuta tools/call contra el endpoint configurado y devuelve resultado tipado.
  // CÓMO/POR QUÉ: separa transporte de sesión y clasifica HTTP, timeout y JSON-RPC sin filtrar secretos.
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    Uri? endpoint;
    int? rpcId;
    try {
      endpoint = resolveMcpHttpEndpoint(descriptor);
      rpcId = nextRequestId();
      final body = {
        'jsonrpc': '2.0',
        'id': rpcId,
        'method': 'tools/call',
        'params': {'name': call.toolName, 'arguments': call.arguments},
      };
      final response = await httpClient
          .post(
            endpoint,
            headers: mcpHttpHeaders(
              descriptor,
              credentialToken: credentialToken,
              sessionId: sessionId(),
              protocolVersion: protocolVersion(),
            ),
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        onConnectionFailure();
        return McpToolCallResult(
          status: McpOperationStatus.failed,
          message: reportMcpHttpFailure(
            serverId: descriptor.id,
            operation: 'tools/call',
            rpcId: rpcId,
            statusCode: response.statusCode,
            endpoint: endpoint,
          ),
        );
      }
      return _parseResponse(decodeMcpJsonRpcResponse(response));
    } on TimeoutException catch (error) {
      onConnectionFailure();
      reportMcpTransportFailure(
        serverId: descriptor.id,
        operation: 'tools/call',
        error: error,
        endpoint: endpoint,
        rpcId: rpcId,
      );
      return const McpToolCallResult(
        status: McpOperationStatus.timeout,
        message: 'La llamada a la herramienta excedió el tiempo límite.',
      );
    } catch (error) {
      onConnectionFailure();
      reportMcpTransportFailure(
        serverId: descriptor.id,
        operation: 'tools/call',
        error: error,
        endpoint: endpoint,
        rpcId: rpcId,
      );
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        message: 'Error en herramienta MCP (${error.runtimeType}).',
      );
    }
  }

  // QUÉ HACE: convierte una respuesta JSON-RPC válida en el resultado del puerto MCP.
  // CÓMO/POR QUÉ: mantiene separados errores de protocolo y errores HTTP de transporte.
  McpToolCallResult _parseResponse(Map<String, dynamic>? data) {
    if (data?['error'] case final Map<String, dynamic> error) {
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        errorCode: error['code']?.toString(),
        message: error['message'] as String? ?? 'Error remoto en tool',
      );
    }
    return HttpMcpParser.parseCallResult(
      data?['result'] as Map<String, dynamic>?,
    );
  }
}

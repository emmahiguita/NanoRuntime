/// HTTP helpers keep credentials and response bodies out of MCP diagnostics.
library;

import 'dart:developer' as developer;

import 'mcp_client_port.dart';

// QUÉ HACE: valida que este adaptador reciba un endpoint HTTP que pueda usar.
// CÓMO FUNCIONA: rechaza transportes distintos y no incluye la URL inválida en errores.
// POR QUÉ: evitar POST JSON-RPC a servidores SSE/stdio o rutas vacías que terminan en 404.
Uri resolveMcpHttpEndpoint(McpServerDescriptor descriptor) {
  if (descriptor.transport != McpTransportKind.streamableHttp) {
    throw const FormatException('unsupported_mcp_transport');
  }
  final endpoint = Uri.tryParse(descriptor.endpoint?.trim() ?? '');
  if (endpoint == null ||
      !{'http', 'https'}.contains(endpoint.scheme) ||
      endpoint.host.isEmpty) {
    throw const FormatException('invalid_mcp_http_endpoint');
  }
  return endpoint;
}

// QUÉ HACE: prepara cabeceras MCP y normaliza un token Bearer ingresado por la persona.
// CÓMO FUNCIONA: conserva el esquema si ya viene incluido y no registra el secreto.
// POR QUÉ: evita enviar "Bearer Bearer …" y mantiene la credencial fuera de Logcat.
Map<String, String> mcpHttpHeaders(
  McpServerDescriptor descriptor, {
  String? credentialToken,
  String? sessionId,
  String? protocolVersion,
}) {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream',
  };
  final token = credentialToken?.trim() ?? '';
  if (token.isNotEmpty) {
    headers['Authorization'] = token.toLowerCase().startsWith('bearer ')
        ? token
        : 'Bearer $token';
  }
  if (sessionId?.isNotEmpty == true) {
    headers['MCP-Session-Id'] = sessionId!;
  }
  if (protocolVersion != null && protocolVersion != '2024-11-05') {
    headers['MCP-Protocol-Version'] = protocolVersion;
  }
  return headers;
}

// QUÉ HACE: registra etapa, JSON-RPC id, HTTP status y host/ruta sin cuerpo ni query.
// CÓMO FUNCIONA: el texto también vuelve a la UI, y el log nunca incluye mensaje ni token.
// POR QUÉ: localizar errores 404/401 sin filtrar conversaciones o credenciales.
String reportMcpHttpFailure({
  required String serverId,
  required String operation,
  required int rpcId,
  required int statusCode,
  required Uri endpoint,
}) {
  final route = '${endpoint.host}${endpoint.path}';
  final detail =
      'MCP $operation failed server=$serverId rpc_id=$rpcId '
      'http=$statusCode endpoint=$route';
  developer.log(detail, name: 'nano.mcp', level: 1000);
  return detail;
}

// QUÉ HACE: registra fallos de red/timeout solo con etapa y tipo de excepción.
// CÓMO FUNCIONA: omite el texto de excepción, que puede contener URL o datos del servidor.
// POR QUÉ: conservar diagnóstico útil sin exponer credenciales ni argumentos de herramientas.
void reportMcpTransportFailure({
  required String serverId,
  required String operation,
  required Object error,
  required Uri? endpoint,
  int? rpcId,
}) {
  final request = rpcId == null ? '' : ' rpc_id=$rpcId';
  developer.log(
    'MCP $operation failed server=$serverId$request error=${error.runtimeType} '
    'endpoint=${endpoint?.host ?? 'unavailable'}',
    name: 'nano.mcp',
    level: 1000,
  );
}

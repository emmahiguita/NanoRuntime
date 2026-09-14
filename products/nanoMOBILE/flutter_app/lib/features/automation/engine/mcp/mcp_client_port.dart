/// MCP Client Port — contrato de infraestructura independiente del SDK MCP.
///
/// Nano no expone tipos de `mcp_client` al dominio. Un adapter posterior puede
/// envolver app-appplayer/mcp_client (o cualquier SDK compatible) sin acoplar
/// Agent Core, PolicyEngine ni UI a una versión concreta del protocolo.
library;

enum McpTransportKind {
  streamableHttp,
  sse,
  stdio,
  androidBinder,
  webSocketBridge,
}

enum McpConnectionState { disconnected, connecting, connected, failed }

enum McpOperationStatus {
  success,
  unavailable,
  unsupported,
  denied,
  timeout,
  cancelled,
  failed,
}

class McpServerDescriptor {
  const McpServerDescriptor({
    required this.id,
    required this.displayName,
    required this.transport,
    this.endpoint,
    this.credentialRef,
    this.metadata = const {},
  });

  final String id;
  final String displayName;
  final McpTransportKind transport;

  /// URL/identificador de transporte. Nunca debe contener secretos embebidos.
  final String? endpoint;

  /// Referencia opaca a almacenamiento seguro; nunca el token/API key real.
  final String? credentialRef;
  final Map<String, Object?> metadata;
}

class McpToolAnnotations {
  const McpToolAnnotations({
    this.readOnlyHint = false,
    this.destructiveHint = false,
    this.idempotentHint = false,
    this.openWorldHint = true,
  });

  final bool readOnlyHint;
  final bool destructiveHint;
  final bool idempotentHint;
  final bool openWorldHint;
}

class McpRemoteTool {
  const McpRemoteTool({
    required this.serverId,
    required this.name,
    required this.inputSchema,
    this.description = '',
    this.annotations = const McpToolAnnotations(),
    this.metadata = const {},
  });

  final String serverId;
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final McpToolAnnotations annotations;
  final Map<String, Object?> metadata;

  String get qualifiedName => '$serverId/$name';
}

class McpConnectionResult {
  const McpConnectionResult({
    required this.status,
    this.protocolVersion,
    this.message,
    this.metadata = const {},
  });

  final McpOperationStatus status;
  final String? protocolVersion;
  final String? message;
  final Map<String, Object?> metadata;

  bool get success => status == McpOperationStatus.success;
}

class McpToolCall {
  const McpToolCall({
    required this.serverId,
    required this.toolName,
    this.arguments = const {},
    this.requestId,
    this.metadata = const {},
  });

  final String serverId;
  final String toolName;
  final Map<String, Object?> arguments;
  final String? requestId;
  final Map<String, Object?> metadata;
}

class McpContentItem {
  const McpContentItem({
    required this.type,
    this.text,
    this.uri,
    this.mimeType,
    this.metadata = const {},
  });

  final String type;
  final String? text;
  final String? uri;
  final String? mimeType;
  final Map<String, Object?> metadata;
}

class McpToolCallResult {
  const McpToolCallResult({
    required this.status,
    this.content = const [],
    this.structuredContent,
    this.errorCode,
    this.message,
    this.metadata = const {},
  });

  final McpOperationStatus status;
  final List<McpContentItem> content;
  final Map<String, Object?>? structuredContent;
  final String? errorCode;
  final String? message;
  final Map<String, Object?> metadata;

  bool get success => status == McpOperationStatus.success;
}

/// Puerto de un único servidor MCP.
///
/// IMPORTANTE: [callTool] es infraestructura, no autorización. En producción
/// sólo debe invocarlo `McpToolHandler` después de Policy/Governance. El Agent
/// Core no recibe este puerto directamente.
abstract interface class McpClientPort {
  McpServerDescriptor get descriptor;
  McpConnectionState get state;

  Future<McpConnectionResult> connect();

  Future<void> disconnect();

  Future<List<McpRemoteTool>> listTools();

  Future<McpToolCallResult> callTool(McpToolCall call);
}

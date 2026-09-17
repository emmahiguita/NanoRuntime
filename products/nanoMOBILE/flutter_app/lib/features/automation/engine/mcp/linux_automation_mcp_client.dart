import '../../executors/linux/linux_automation_port.dart';
import '../execution/handlers/semantic_linux_tool_handler.dart';
import '../execution/tool_call.dart';
import 'mcp_client_port.dart';

/// Servidor MCP nativo para el subsistema Linux de Nano.
///
/// Expone las capacidades de bajo nivel y semánticas de Linux/Nanoshell
/// a través del protocolo estándar MCP, permitiendo que agentes autónomos (Koog,
/// subagentes, modelos remotos) utilicen Linux sin inventar comandos bash inseguros.
class LinuxAutomationMcpClient implements McpClientPort {
  static const String serverId = 'nano-linux';

  final ILinuxAutomationExecutor _executor;
  final SemanticLinuxToolHandler _toolHandler;
  McpConnectionState _state = McpConnectionState.disconnected;

  LinuxAutomationMcpClient({
    required ILinuxAutomationExecutor executor,
    SemanticLinuxToolHandler? toolHandler,
  })  : _executor = executor,
        _toolHandler = toolHandler ?? SemanticLinuxToolHandler(executor: executor);

  @override
  McpServerDescriptor get descriptor => const McpServerDescriptor(
        id: serverId,
        displayName: 'Nano Linux Automation Engine',
        transport: McpTransportKind.stdio,
        metadata: {
          'version': '1.0.0',
          'engine': 'Nanoshell',
          'runtime': 'Rootfs Linux',
        },
      );

  @override
  McpConnectionState get state => _state;

  @override
  Future<McpConnectionResult> connect() async {
    _state = McpConnectionState.connecting;
    if (!_executor.isAvailable) {
      await _executor.init();
    }

    if (!_executor.isAvailable) {
      _state = McpConnectionState.failed;
      return const McpConnectionResult(
        status: McpOperationStatus.unavailable,
        message: 'Subsistema Linux/Nanoshell no inicializado o rootfs ausente.',
      );
    }

    _state = McpConnectionState.connected;
    return const McpConnectionResult(
      status: McpOperationStatus.success,
      protocolVersion: '2024-11-05',
      message: 'Nano Linux Automation MCP conectado exitosamente.',
      metadata: {'nanoshellActive': true},
    );
  }

  @override
  Future<void> disconnect() async {
    _state = McpConnectionState.disconnected;
  }

  @override
  Future<List<McpRemoteTool>> listTools() async {
    return const [
      McpRemoteTool(
        serverId: serverId,
        name: 'nano.linux.fs.list',
        description: 'Lista archivos y carpetas estructurados en Linux.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Ruta absoluta'},
            'recursive': {'type': 'boolean', 'default': false},
          },
          'required': ['path'],
        },
        annotations: McpToolAnnotations(readOnlyHint: true, idempotentHint: true),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'nano.linux.fs.read',
        description: 'Lee el contenido de un archivo en Linux.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Ruta del archivo'},
            'maxBytes': {'type': 'integer', 'default': 4096},
          },
          'required': ['path'],
        },
        annotations: McpToolAnnotations(readOnlyHint: true, idempotentHint: true),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'nano.linux.fs.write',
        description: 'Escribe contenido en un archivo verificando su persistencia en disco.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Ruta del archivo'},
            'content': {'type': 'string', 'description': 'Contenido a escribir'},
          },
          'required': ['path', 'content'],
        },
        annotations: McpToolAnnotations(destructiveHint: true),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'nano.linux.archive.create',
        description: 'Crea un paquete tar/tar.gz con integridad verificada.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'sourcePath': {'type': 'string', 'description': 'Ruta de origen'},
            'tarPath': {'type': 'string', 'description': 'Ruta de destino tar.gz'},
            'gzip': {'type': 'boolean', 'default': true},
          },
          'required': ['sourcePath', 'tarPath'],
        },
        annotations: McpToolAnnotations(destructiveHint: true),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'nano.linux.git.status',
        description: 'Consulta el estado de cambios de un repositorio Git.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'repoPath': {'type': 'string', 'default': '.'},
          },
        },
        annotations: McpToolAnnotations(readOnlyHint: true, idempotentHint: true),
      ),
      McpRemoteTool(
        serverId: serverId,
        name: 'nano.linux.process.list',
        description: 'Lista los procesos actualmente en ejecución en Linux.',
        inputSchema: {'type': 'object'},
        annotations: McpToolAnnotations(readOnlyHint: true, idempotentHint: true),
      ),
    ];
  }

  @override
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    if (_state != McpConnectionState.connected) {
      return const McpToolCallResult(
        status: McpOperationStatus.unavailable,
        message: 'Servidor MCP nano-linux no conectado.',
      );
    }

    try {
      final toolCall = ToolCall(tool: call.toolName, args: call.arguments);
      final resultText = await _toolHandler.handleToolCall(toolCall);
      final isSuccess = resultText.startsWith('SUCCESS');

      return McpToolCallResult(
        status: isSuccess ? McpOperationStatus.success : McpOperationStatus.failed,
        message: resultText,
        structuredContent: {'result': resultText},
        content: [McpContentItem(type: 'text', text: resultText)],
      );
    } catch (e) {
      return McpToolCallResult(
        status: McpOperationStatus.failed,
        message: '$e',
        structuredContent: {'error': '$e'},
      );
    }
  }
}

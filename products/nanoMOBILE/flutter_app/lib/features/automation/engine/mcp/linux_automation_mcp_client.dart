import 'dart:convert';
import '../../executors/linux/linux_automation_port.dart';
import '../../executors/linux/linux_automation_types.dart';
import '../../executors/linux/linux_process_inspector.dart';
import '../execution/handlers/semantic_linux_tool_handler.dart';
import '../execution/tool_call.dart';
import 'mcp_client_port.dart';
import 'mcp_schema_validator.dart';

part 'linux_mcp_catalog.dart';
part 'linux_mcp_dispatch.dart';
part 'linux_mcp_result.dart';

/// Conector interno: comparte el ejecutor Linux, nunca una sesión PTY ni stdio.
/// La autorización pertenece al dispatcher; aquí se valida el contrato de entrada.
class LinuxAutomationMcpClient implements McpClientPort {
  static const String serverId = 'nano-linux';
  final ILinuxAutomationExecutor _executor;
  final SemanticLinuxToolHandler? _toolHandler;
  McpConnectionState _state = McpConnectionState.disconnected;

  LinuxAutomationMcpClient({
    required ILinuxAutomationExecutor executor,
    SemanticLinuxToolHandler? toolHandler,
  }) : _executor = executor,
       _toolHandler = toolHandler;

  @override
  McpServerDescriptor get descriptor => const McpServerDescriptor(
    id: serverId,
    displayName: 'Nano Linux',
    transport: McpTransportKind.inProcess,
    metadata: {
      'version': '1.1.0',
      'engine': 'Nanoshell',
      'runtime': 'Nanoshell: bootstrap o rootfs instalado',
      'session': 'independiente de la terminal PTY',
    },
  );

  @override
  McpConnectionState get state => _state;

  @override
  Future<McpConnectionResult> connect() async {
    _state = McpConnectionState.connecting;
    try {
      if (!_executor.isAvailable) await _executor.init();
      if (!_executor.isAvailable) throw StateError('Motor no disponible');
      _state = McpConnectionState.connected;
      return const McpConnectionResult(
        status: McpOperationStatus.success,
        message:
            'Motor Linux inicializado. No demuestra ejecución de herramientas.',
      );
    } catch (_) {
      _state = McpConnectionState.failed;
      return const McpConnectionResult(
        status: McpOperationStatus.unavailable,
        message:
            'Linux no disponible: comprueba el motor y su rootfs en Terminal.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    // El registro es dueño del conector; la terminal conserva sus propias tareas.
    _state = McpConnectionState.disconnected;
  }

  @override
  Future<List<McpRemoteTool>> listTools() async => _linuxMcpCatalog();

  @override
  Future<McpToolCallResult> callTool(McpToolCall call) async {
    if (_state != McpConnectionState.connected || call.serverId != serverId) {
      return const McpToolCallResult(
        status: McpOperationStatus.unavailable,
        message: 'Conector Linux no disponible para este servidor.',
      );
    }
    final matches = _linuxMcpCatalog().where((t) => t.name == call.toolName);
    if (matches.isEmpty) {
      return const McpToolCallResult(
        status: McpOperationStatus.unsupported,
        message: 'Operación Linux no publicada.',
      );
    }
    final problems = await McpSchemaValidator.validate(
      matches.first.inputSchema,
      call.arguments,
    );
    if (problems.isNotEmpty) {
      return McpToolCallResult(
        status: McpOperationStatus.denied,
        message: problems.join('\n'),
      );
    }
    try {
      // Conserva la inyección pública de adaptadores antiguos sin usarla en producción.
      if (_toolHandler != null) {
        final text = await _toolHandler.handleToolCall(
          ToolCall(tool: call.toolName, args: call.arguments),
        );
        final accepted =
            text.startsWith('SUCCESS') ||
            text.startsWith('[completedUnverified]');
        return McpToolCallResult(
          status: accepted
              ? McpOperationStatus.success
              : McpOperationStatus.failed,
          content: [McpContentItem(type: 'text', text: text)],
          metadata: const {'verified': false},
        );
      }
      return await _dispatch(call);
    } catch (_) {
      return const McpToolCallResult(
        status: McpOperationStatus.failed,
        message:
            'La operación Linux no pudo completarse; consulta su registro local.',
      );
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/semantic_linux_tool_handler.dart';
import 'package:nanoai/features/automation/engine/mcp/linux_automation_mcp_client.dart';
import 'package:nanoai/features/automation/engine/mcp/mcp_client_port.dart';
import 'package:nanoai/features/automation/executors/linux/linux_action_verifier.dart';
import 'package:nanoai/features/automation/executors/linux/linux_process_supervisor.dart';
import 'package:nanoai/features/automation/executors/linux/linux_security_policy.dart';
import 'package:nanoai/features/automation/executors/linux/nanoshell_linux_automation_executor.dart';
import 'package:nanoai/features/terminal/i_bin_executor.dart';
import 'package:nanoai/features/terminal/terminal_types.dart';

class MockMcpBinExecutor implements IBinExecutor {
  @override
  bool initialized = true;

  @override
  String? binDir = '/bin';

  @override
  String? usrDir = '/usr';

  @override
  String? baseDir = '/';

  final Map<String, ShellResult> toyboxMap = {};

  @override
  Future<void> init() async {}

  @override
  void killAll() {}

  @override
  bool killTag(String tag) => true;

  @override
  bool killTracked(String tag) => true;

  @override
  Future<ShellResult> toybox(List<String> args, {Map<String, String>? extraEnv, Duration? timeout}) async {
    final key = args.join(' ');
    if (toyboxMap.containsKey(key)) return toyboxMap[key]!;
    final cmd = args.first;
    if (toyboxMap.containsKey(cmd)) return toyboxMap[cmd]!;
    return const ShellResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  Future<ShellResult> bash(String cmd, {Map<String, String>? env, Duration? timeout}) async =>
      const ShellResult(stdout: '', stderr: '', exitCode: 0);

  @override
  Future<ShellResult> execRootfs(String binaryPath, List<String> args, {Map<String, String>? env, String? ldPreload, Duration? timeout}) async =>
      const ShellResult(stdout: '', stderr: '', exitCode: 0);

  @override
  Future<ShellResult?> execRootfsWorker(String binaryPath, List<String> args, {Map<String, String>? env, String? ldPreload, Duration? timeout}) async => null;

  @override
  Future<int> stream(String command, List<String> args, {String? workDir, Map<String, String>? env, void Function(String line)? onOut, void Function(String line)? onErr, Duration? timeout, String? trackTag}) async => 0;
}

void main() {
  group('LinuxAutomationMcpClient (Protocolo MCP para Linux en Nano)', () {
    late MockMcpBinExecutor mockShell;
    late LinuxAutomationMcpClient client;

    setUp(() {
      mockShell = MockMcpBinExecutor();
      const security = LinuxSecurityPolicy(allowedWriteRoots: ['/tmp']);
      final verifier = LinuxActionVerifier(binExecutor: mockShell);
      final supervisor = LinuxProcessSupervisor(binExecutor: mockShell);

      final executor = NanoshellLinuxAutomationExecutor(
        binExecutor: mockShell,
        securityPolicy: security,
        verifier: verifier,
        supervisor: supervisor,
      );

      final handler = SemanticLinuxToolHandler(executor: executor);
      client = LinuxAutomationMcpClient(executor: executor, toolHandler: handler);
    });

    test('descriptor: declara id nano-linux y transporte stdio', () {
      final desc = client.descriptor;
      expect(desc.id, equals('nano-linux'));
      expect(desc.displayName, contains('Linux'));
      expect(desc.transport, equals(McpTransportKind.stdio));
    });

    test('connect: handshake exitoso cuando el executor está disponible', () async {
      final conn = await client.connect();
      expect(conn.success, isTrue);
      expect(client.state, equals(McpConnectionState.connected));
      expect(conn.message, contains('conectado exitosamente'));
    });

    test('listTools: expone herramientas estructuradas con hints de seguridad', () async {
      final tools = await client.listTools();
      expect(tools.length, greaterThanOrEqualTo(5));

      final readTool = tools.firstWhere((t) => t.name == 'nano.linux.fs.read');
      expect(readTool.annotations.readOnlyHint, isTrue);

      final writeTool = tools.firstWhere((t) => t.name == 'nano.linux.fs.write');
      expect(writeTool.annotations.destructiveHint, isTrue);
    });

    test('callTool: ejecuta comando semántico vía MCP y retorna resultado', () async {
      await client.connect();
      mockShell.toyboxMap['ls -la /tmp'] = const ShellResult(
        stdout: '-rw-r--r-- 1 nano nano 512 Jan 1 00:00 file1.txt\n',
        stderr: '',
        exitCode: 0,
      );

      final result = await client.callTool(
        const McpToolCall(
          serverId: 'nano-linux',
          toolName: 'nano.linux.fs.list',
          arguments: {'path': '/tmp'},
        ),
      );

      expect(result.status, equals(McpOperationStatus.success));
      expect(result.structuredContent?['result'], contains('SUCCESS: 1 items en "/tmp"'));
    });
  });
}

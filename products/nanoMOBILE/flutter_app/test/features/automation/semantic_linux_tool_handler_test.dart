import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/handlers/semantic_linux_tool_handler.dart';
import 'package:nanoai/features/automation/engine/execution/tool_call.dart';
import 'package:nanoai/features/automation/executors/linux/linux_action_verifier.dart';
import 'package:nanoai/features/automation/executors/linux/linux_process_supervisor.dart';
import 'package:nanoai/features/automation/executors/linux/linux_security_policy.dart';
import 'package:nanoai/features/automation/executors/linux/nanoshell_linux_automation_executor.dart';
import 'package:nanoai/features/terminal/i_bin_executor.dart';
import 'package:nanoai/features/terminal/terminal_types.dart';

class StubBinExecutor implements IBinExecutor {
  @override
  bool initialized = true;

  @override
  String? binDir = '/bin';

  @override
  String? usrDir = '/usr';

  @override
  String? baseDir = '/';

  final Map<String, ShellResult> toyboxMap = {};
  final Map<String, ShellResult> execMap = {};
  final Map<String, ShellResult> bashMap = {};

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
  Future<ShellResult> bash(String cmd, {Map<String, String>? env, Duration? timeout}) async {
    for (final entry in bashMap.entries) {
      if (cmd.contains(entry.key)) return entry.value;
    }
    return const ShellResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  Future<ShellResult> execRootfs(String binaryPath, List<String> args, {Map<String, String>? env, String? ldPreload, Duration? timeout}) async {
    final key = '$binaryPath ${args.join(' ')}';
    if (execMap.containsKey(key)) return execMap[key]!;
    return const ShellResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  Future<ShellResult?> execRootfsWorker(String binaryPath, List<String> args, {Map<String, String>? env, String? ldPreload, Duration? timeout}) async => null;

  @override
  Future<int> stream(String command, List<String> args, {String? workDir, Map<String, String>? env, void Function(String line)? onOut, void Function(String line)? onErr, Duration? timeout, String? trackTag}) async {
    onOut?.call('started');
    return 0;
  }
}

void main() {
  group('SemanticLinuxToolHandler (Herramientas Tipadas y Resumen Compacto)', () {
    late StubBinExecutor stubShell;
    late SemanticLinuxToolHandler handler;

    setUp(() {
      stubShell = StubBinExecutor();
      const security = LinuxSecurityPolicy(allowedWriteRoots: ['/sdcard/Nanoai', '/tmp']);
      final verifier = LinuxActionVerifier(binExecutor: stubShell);
      final supervisor = LinuxProcessSupervisor(binExecutor: stubShell);

      final executor = NanoshellLinuxAutomationExecutor(
        binExecutor: stubShell,
        securityPolicy: security,
        verifier: verifier,
        supervisor: supervisor,
      );

      handler = SemanticLinuxToolHandler(executor: executor);
    });

    test('nano.linux.fs.list: devuelve conteo y muestra sin desbordar tokens', () async {
      stubShell.toyboxMap['ls -la /tmp'] = const ShellResult(
        stdout: '-rw-r--r-- 1 nano nano 1024 Jan 1 00:00 a.txt\n'
            '-rw-r--r-- 1 nano nano 2048 Jan 1 00:00 b.txt\n',
        stderr: '',
        exitCode: 0,
      );

      final out = await handler.handleToolCall(
        const ToolCall(tool: 'nano.linux.fs.list', args: {'path': '/tmp'}),
      );

      expect(out, contains('SUCCESS: 2 items en "/tmp"'));
      expect(out, contains('a.txt, b.txt'));
    });

    test('nano.linux.fs.write: escribe y verifica, retornando resumen estructurado', () async {
      stubShell.toyboxMap['test -f /sdcard/Nanoai/notes.txt'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);
      stubShell.toyboxMap['wc -c /sdcard/Nanoai/notes.txt'] =
          const ShellResult(stdout: '12\n', stderr: '', exitCode: 0);

      final out = await handler.handleToolCall(
        const ToolCall(
          tool: 'nano.linux.fs.write',
          args: {'path': '/sdcard/Nanoai/notes.txt', 'content': 'sample notes'},
        ),
      );

      expect(out, contains('SUCCESS: archivo "/sdcard/Nanoai/notes.txt" escrito y verificado en disco'));
    });

    test('nano.linux.archive.create: empaqueta y confirma verificación de integridad', () async {
      stubShell.toyboxMap['tar -czf /tmp/bundle.tar.gz /tmp/src'] =
          const ShellResult(stdout: '', stderr: '', exitCode: 0);
      stubShell.toyboxMap['tar -tzf /tmp/bundle.tar.gz'] =
          const ShellResult(stdout: 'f1\nf2\n', stderr: '', exitCode: 0);

      final out = await handler.handleToolCall(
        const ToolCall(
          tool: 'nano.linux.archive.create',
          args: {'sourcePath': '/tmp/src', 'tarPath': '/tmp/bundle.tar.gz'},
        ),
      );

      expect(out, contains('SUCCESS: archivo comprimido "/tmp/bundle.tar.gz" creado con integridad verificada'));
    });

    test('nano.linux.git.status: retorna salida estructurada y limpia', () async {
      stubShell.execMap['git status --short'] =
          const ShellResult(stdout: '?? new_module.dart\n', stderr: '', exitCode: 0);

      final out = await handler.handleToolCall(
        const ToolCall(tool: 'nano.linux.git.status', args: {'repoPath': '/repo'}),
      );

      expect(out, contains('SUCCESS: git status (/repo)'));
      expect(out, contains('?? new_module.dart'));
    });
  });
}

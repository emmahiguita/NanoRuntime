import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/linux_execution_backend.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';
import 'package:nanoai/features/automation/engine/orchestration/execution_journal.dart';
import 'package:nanoai/features/automation/engine/platform/linux_tool_adapter.dart';

class _RecordingLinuxExecutionBackend implements LinuxExecutionBackend {
  final List<LinuxExecutionRequest> requests = [];

  @override
  Future<LinuxExecutionResult> execute(LinuxExecutionRequest request) async {
    requests.add(request);
    return const LinuxExecutionResult(
      exitCode: 0,
      stdout: 'ok',
      stderr: '',
      duration: Duration.zero,
    );
  }
}

void main() {
  group('AgentToolProtocol Linux Contracts', () {
    test('parses linux.run with top-level command and cwd', () {
      const jsonStr = '{"tool": "linux.run", "command": "git status", "cwd": "/root"}';
      final call = AgentToolProtocol.extractToolCall(jsonStr);

      expect(call, isNotNull);
      expect(call!.tool, 'linux.run');
      expect(call.commandArg, 'git status');
      expect(call.textArg, 'git status');
      expect(call.args?['cwd'], '/root');
    });

    test('parses linux.run with command and list args', () {
      const jsonStr = '{"tool": "linux.run", "command": "git", "args": ["status", "--short"]}';
      final call = AgentToolProtocol.extractToolCall(jsonStr);

      expect(call, isNotNull);
      expect(call!.tool, 'linux.run');
      expect(call.commandArg, 'git');
      expect(call.args?['arguments'], ['status', '--short']);
      expect(call.args?['args'], ['status', '--short']);
    });

    test('parses linux.readFile with top-level path', () {
      const jsonStr = '{"tool": "linux.readFile", "path": "/etc/hosts"}';
      final call = AgentToolProtocol.extractToolCall(jsonStr);

      expect(call, isNotNull);
      expect(call!.tool, 'linux.readFile');
      expect(call.pathArg, '/etc/hosts');
      expect(call.textArg, '/etc/hosts');
      expect(call.selectorArg, '/etc/hosts');
    });

    test('parses linux.writeFile with top-level path and content', () {
      const jsonStr = '{"tool": "linux.writeFile", "path": "/tmp/a.txt", "content": "hola"}';
      final call = AgentToolProtocol.extractToolCall(jsonStr);

      expect(call, isNotNull);
      expect(call!.tool, 'linux.writeFile');
      expect(call.pathArg, '/tmp/a.txt');
      expect(call.args?['content'], 'hola');
    });

    test('parses list of tool calls preserving top-level keys', () {
      const jsonList =
          '[{"tool": "linux.readFile", "path": "/etc/issue"}, {"tool": "linux.run", "command": "uptime"}]';
      final calls = AgentToolProtocol.extractToolCalls(jsonList);

      expect(calls, hasLength(2));
      expect(calls[0].tool, 'linux.readFile');
      expect(calls[0].pathArg, '/etc/issue');
      expect(calls[1].tool, 'linux.run');
      expect(calls[1].commandArg, 'uptime');
    });
  });

  group('LinuxToolAdapter Backend Propagation', () {
    test('propagates cwd, environment, and timeout across calls', () async {
      final backend = _RecordingLinuxExecutionBackend();
      final adapter = LinuxToolAdapter(backend: backend);

      await adapter.runCommand(
        'echo test',
        cwd: '/custom/dir',
        environment: {'FOO': 'BAR'},
        timeout: const Duration(seconds: 45),
      );

      expect(backend.requests, hasLength(1));
      final req = backend.requests.single;
      expect(req.executable, 'bash');
      expect(req.arguments, ['-c', 'echo test']);
      expect(req.cwd, '/custom/dir');
      expect(req.environment['FOO'], 'BAR');
      expect(req.timeout, const Duration(seconds: 45));
    });
  });

  group('AgentToolDispatcher Linux Execution', () {
    test('linux.run requires confirmation by default, executes with confirmed: true', () async {
      final backend = _RecordingLinuxExecutionBackend();
      final adapter = LinuxToolAdapter(backend: backend);
      final dispatcher = AgentToolDispatcher(
        linuxAdapter: adapter,
        executionJournal: InMemoryExecutionJournal(),
      );

      const jsonStr = '{"tool": "linux.run", "command": "ls", "args": ["-l", "/tmp"]}';
      final call = AgentToolProtocol.extractToolCall(jsonStr)!;
      
      // Sin confirmación: la política de seguridad protege acciones en el dispositivo
      final unconfirmed = await dispatcher.runTool(call);
      expect(unconfirmed, contains('[policy]'));
      expect(backend.requests, isEmpty);

      // Con confirmación: ejecuta con argumentos formateados
      final outcome = await dispatcher.runToolGuarded(call, confirmed: true);
      expect(outcome.verdict, PolicyVerdict.allow);
      expect(backend.requests, hasLength(1));
      final req = backend.requests.single;
      expect(req.arguments, ['-c', "ls '-l' '/tmp'"]);
    });

    test('linux.readFile with top-level path executes directly (read risk)', () async {
      final backend = _RecordingLinuxExecutionBackend();
      final adapter = LinuxToolAdapter(backend: backend);
      final dispatcher = AgentToolDispatcher(
        linuxAdapter: adapter,
        executionJournal: InMemoryExecutionJournal(),
      );

      const jsonStr = '{"tool": "linux.readFile", "path": "/etc/os-release"}';
      final call = AgentToolProtocol.extractToolCall(jsonStr)!;
      final result = await dispatcher.runTool(call);

      expect(result, isNot(contains('[tool]')));
      expect(result, isNot(contains('[policy]')));
      expect(backend.requests, hasLength(1));
      final req = backend.requests.single;
      expect(req.executable, 'cat');
      expect(req.arguments, ['/etc/os-release']);
    });

    test('linux.writeFile requires confirmation by default, executes with confirmed: true', () async {
      final backend = _RecordingLinuxExecutionBackend();
      final adapter = LinuxToolAdapter(backend: backend);
      final dispatcher = AgentToolDispatcher(
        linuxAdapter: adapter,
        executionJournal: InMemoryExecutionJournal(),
      );

      const jsonStr = '{"tool": "linux.writeFile", "path": "/tmp/note.txt", "content": "hello world"}';
      final call = AgentToolProtocol.extractToolCall(jsonStr)!;

      // Sin confirmación: externalWrite requiere confirmación
      final unconfirmed = await dispatcher.runTool(call);
      expect(unconfirmed, contains('[policy]'));
      expect(backend.requests, isEmpty);

      // Con confirmación: ejecuta escritura
      final outcome = await dispatcher.runToolGuarded(call, confirmed: true);
      expect(outcome.verdict, PolicyVerdict.allow);
      expect(backend.requests, hasLength(1));
      final req = backend.requests.single;
      expect(req.executable, 'bash');
      expect(req.arguments.last, contains('hello world'));
    });
  });
}

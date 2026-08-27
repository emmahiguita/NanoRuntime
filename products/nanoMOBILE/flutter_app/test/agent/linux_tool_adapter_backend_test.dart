import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/linux_execution_backend.dart';
import 'package:nanoai/features/automation/engine/platform/linux_tool_adapter.dart';

/// T1.6 — parity (estructural) Automation ↔ backend CORE.
///
/// La paridad factual ya está garantizada por composición: tanto el Terminal
/// (vía IBinExecutor) como Automation (vía ShellExecutorLinuxBackend) terminan
/// en el MISMO ShellExecutor.toybox/execRootfs → Nanoshell FFI. Lo que este
/// test protege es la paridad SEMÁNTICA de las requests: Automation debe emitir
/// `executable + arguments` para operaciones estructuradas, NO `bash -c string`.
/// Una regresión aquí (volver a `bash -c "ls -la"`) rompería la unificación.
class RecordingLinuxExecutionBackend implements LinuxExecutionBackend {
  final List<LinuxExecutionRequest> requests = [];

  @override
  Future<LinuxExecutionResult> execute(LinuxExecutionRequest request) async {
    requests.add(request);
    return const LinuxExecutionResult(
      exitCode: 0,
      stdout: '',
      stderr: '',
      duration: Duration.zero,
    );
  }
}

void main() {
  test('list usa executable + arguments (ls -la), no bash -c', () async {
    final backend = RecordingLinuxExecutionBackend();
    final adapter = LinuxToolAdapter(backend: backend);

    await adapter.list('/tmp');

    expect(backend.requests, hasLength(1));
    final req = backend.requests.single;
    expect(req.executable, 'ls');
    expect(req.arguments, ['-la', '/tmp']);
  });

  test('readFile usa executable + arguments (cat), no bash -c', () async {
    final backend = RecordingLinuxExecutionBackend();
    final adapter = LinuxToolAdapter(backend: backend);

    await adapter.readFile('/tmp/a.txt');

    final req = backend.requests.single;
    expect(req.executable, 'cat');
    expect(req.arguments, ['/tmp/a.txt']);
  });

  test('runCommand usa shell explícito (bash -c) — gobernado aguas arriba',
      () async {
    final backend = RecordingLinuxExecutionBackend();
    final adapter = LinuxToolAdapter(backend: backend);

    await adapter.runCommand('git status');

    final req = backend.requests.single;
    expect(req.executable, 'bash');
    expect(req.arguments, ['-c', 'git status']);
  });

  test('writeFile usa shell heredoc (bash -c) con contenido', () async {
    final backend = RecordingLinuxExecutionBackend();
    final adapter = LinuxToolAdapter(backend: backend);

    await adapter.writeFile('/tmp/x.txt', 'hola');

    final req = backend.requests.single;
    expect(req.executable, 'bash');
    expect(req.arguments, hasLength(2));
    expect(req.arguments.first, '-c');
    expect(req.arguments.last, contains('hola'));
  });

  test('list/readFile NUNCA pasan por bash -c (regresión de unificación)',
      () async {
    final backend = RecordingLinuxExecutionBackend();
    final adapter = LinuxToolAdapter(backend: backend);

    await adapter.list('/tmp');
    await adapter.readFile('/tmp/a.txt');

    for (final req in backend.requests) {
      expect(
        req.executable,
        isNot('bash'),
        reason: 'Operación estructurada no debe colapsar a bash -c.',
      );
    }
  });
}

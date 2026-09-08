/// T1 — adapter delgado: LinuxExecutionBackend sobre ShellExecutor.
///
/// NO es otro motor. ShellExecutor (Nanoshell FFI / rootfs / toybox) es el
/// backend factual; este adapter solo traduce [LinuxExecutionRequest] a su API.
/// Applets de toybox (`ls`, `cat`, `echo`, ...) van por `toybox`; binarios del
/// rootfs van por `execRootfs`.
library;

import '../../features/terminal/terminal_types.dart' show ShellResult;
import 'linux_execution_backend.dart';
import 'shell_executor.dart';

class ShellExecutorLinuxBackend implements LinuxExecutionBackend {
  ShellExecutorLinuxBackend(this._executor);

  final ShellExecutor _executor;

  /// Applets BusyBox conocidos → se ejecutan vía toybox (más rápido, sin
  /// resolver binario). El resto → execRootfs (binario real del rootfs).
  static const _applets = {
    'ls',
    'cat',
    'cd',
    'pwd',
    'mkdir',
    'touch',
    'rm',
    'cp',
    'mv',
    'echo',
    'grep',
    'find',
    'wc',
    'head',
    'tail',
    'chmod',
    'tree',
    'sed',
    'awk',
    'ps',
    'kill',
    'df',
    'free',
    'seq',
    'expr',
    'basename',
    'dirname',
  };

  @override
  Future<LinuxExecutionResult> execute(LinuxExecutionRequest request) async {
    // Auto-init idempotente: el backend es autocontenido (el caller no debe
    // recordar init()). ShellExecutor.init() es no-op si ya está inicializado,
    // así que el Terminal (que ya llama init en bootstrap) no se ve afectado.
    if (!_executor.initialized) {
      await _executor.init();
    }
    // cwd post-fork: el worker (:nanoshell) ejecuta tareas en procesos hijos
    // forkeados. NANO_CWD es interpretado en nanoshell.c post-fork de forma
    // segura y aislada (sin colisión entre hilos ni alteración global).
    final Map<String, String> env = Map<String, String>.from(request.environment);
    if (request.cwd != null && request.cwd!.isNotEmpty) {
      env['NANO_CWD'] = request.cwd!;
      env['PWD'] = request.cwd!;
    }
    final started = DateTime.now();
    final Map<String, String>? effectiveEnv = env.isEmpty ? null : env;
    final ShellResult r = _applets.contains(request.executable)
        ? await _executor.toybox(
            [request.executable, ...request.arguments],
            extraEnv: effectiveEnv,
            timeout: request.timeout,
          )
        : await _executor.execRootfs(
            request.executable,
            request.arguments,
            env: effectiveEnv,
            timeout: request.timeout,
          );
    return LinuxExecutionResult(
      exitCode: r.exitCode,
      stdout: r.stdout,
      stderr: r.stderr,
      duration: DateTime.now().difference(started),
    );
  }
}

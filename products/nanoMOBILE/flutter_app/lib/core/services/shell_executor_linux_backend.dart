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
    // GAP-1: cwd falla honesto. El worker (:nanoshell) ejecuta tareas en
    // threads concurrentes — chdir de proceso sería una raza entre tareas.
    // La vía segura es chdir post-fork en libnanoshell.so (nativo); hasta
    // entonces, NUNCA ignorar cwd en silencio: el error vuelve al LLM como
    // infrastructureError y puede corregir (usar rutas absolutas).
    if (request.cwd != null && request.cwd!.isNotEmpty) {
      throw UnsupportedError(
        'cwd no soportado por la vía worker (chdir post-fork requiere libnanoshell); '
        'usa rutas absolutas o un binario del rootfs (bash -c "cd ... && ...")',
      );
    }
    final started = DateTime.now();
    final Map<String, String>? env = request.environment.isEmpty
        ? null
        : request.environment;
    final ShellResult r = _applets.contains(request.executable)
        ? await _executor.toybox([
            request.executable,
            ...request.arguments,
          ], extraEnv: env, timeout: request.timeout)
        : await _executor.execRootfs(
            request.executable,
            request.arguments,
            env: env,
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

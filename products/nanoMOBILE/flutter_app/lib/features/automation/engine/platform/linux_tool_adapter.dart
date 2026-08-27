/// LinuxToolAdapter (Fase C9) — acceso CONTROLADO al subsistema Linux.
///
/// Regla del plan maestro: NO dar bash sin restricciones al LLM. Este adapter
/// expone operaciones estructuradas (list/readFile/writeFile/run) con
/// resultados tipados (stdout/stderr/exitCode/duration) y la gobernanza la
/// aplica el [PolicyEngine] ANTES de writes/comandos destructivos (el
/// dispatcher, nunca el adapter).
///
/// DIP: la ejecución real (PTY) se inyecta vía [LinuxCommandRunner]; los
/// tests usan fakes. El adapter es puro: formatea comandos y resultados.
library;

import 'dart:async';
import 'dart:convert';

import '../../../../core/services/linux_execution_backend.dart';
import '../../../../core/services/pty_shell.dart';

/// Resultado estructurado de un comando Linux. El exitCode es null cuando la
/// vía de ejecución no puede determinarlo (pty interactivo) — nunca se
/// inventa.
class LinuxCommandResult {
  final String stdout;
  final String stderr;

  /// null si no determinable.
  final int? exitCode;
  final Duration duration;

  /// Fallo de infraestructura (sin shell, timeout, pty roto). null = el
  /// comando se ejecutó (aunque haya terminado con error propio).
  final String? infrastructureError;

  const LinuxCommandResult({
    this.stdout = '',
    this.stderr = '',
    this.exitCode,
    required this.duration,
    this.infrastructureError,
  });

  bool get ok => infrastructureError == null;
}

/// LEGACY (T1.2): el adapter productivo ya consume [LinuxExecutionBackend].
/// Este runner y [PtyLinuxCommandRunner] quedan SIN callers productivos; son
/// candidatos a eliminación en T1.3 (no son fallback automático).
abstract interface class LinuxCommandRunner {
  Future<LinuxCommandResult> run(String command, {Duration timeout});
}

/// Adapter de alto nivel: operaciones estructuradas sobre el subsistema.
/// T1.2: consume el contrato core [LinuxExecutionBackend] (compartido con el
/// Terminal), NO el runner PTY legacy. Operaciones estructuradas usan
/// `executable + arguments`; solo writeFile/runCommand usan shell (heredoc/
/// comando libre), y esa semántica shell queda gobernada aguas arriba.
class LinuxToolAdapter {
  LinuxToolAdapter({required LinuxExecutionBackend backend})
    : _backend = backend;

  final LinuxExecutionBackend _backend;

  Future<LinuxCommandResult> list(String path) =>
      _exec('ls', ['-la', path]);

  Future<LinuxCommandResult> readFile(String path) => _exec('cat', [path]);

  Future<LinuxCommandResult> writeFile(String path, String content) {
    // Heredoc con delimitador aleatorio: contenido arbitrario sin escapes.
    final marker = 'NANOEOF${DateTime.now().microsecondsSinceEpoch}';
    final script = 'cat > ${_quote(path)} << "$marker"\n$content\n$marker';
    return _shell(script);
  }

  /// Comando libre (p.ej. git, python) — la política del dispatcher decide
  /// si es seguro; el adapter no valida contenido.
  Future<LinuxCommandResult> runCommand(String command) => _shell(command);

  Future<LinuxCommandResult> _exec(String executable, List<String> args) async {
    try {
      final r = await _backend.execute(
        LinuxExecutionRequest(
          executable: executable,
          arguments: args,
          timeout: const Duration(seconds: 20),
        ),
      );
      return LinuxCommandResult(
        stdout: r.stdout,
        stderr: r.stderr,
        exitCode: r.exitCode,
        duration: r.duration,
      );
    } catch (e) {
      return LinuxCommandResult(
        duration: Duration.zero,
        infrastructureError: '$e',
      );
    }
  }

  Future<LinuxCommandResult> _shell(String script) async {
    try {
      final r = await _backend.execute(
        LinuxExecutionRequest(
          executable: 'bash',
          arguments: ['-c', script],
          timeout: const Duration(seconds: 20),
        ),
      );
      return LinuxCommandResult(
        stdout: r.stdout,
        stderr: r.stderr,
        exitCode: r.exitCode,
        duration: r.duration,
      );
    } catch (e) {
      return LinuxCommandResult(
        duration: Duration.zero,
        infrastructureError: '$e',
      );
    }
  }

  static String _quote(String s) => "'${s.replaceAll("'", r"'\''")}'";
}

/// Runner real sobre [PtySession] (canal `com.nanoai/pty`, libnanoshell.so).
/// Ejecuta `bash -c <comando>` con el rootfs (ldPreload libnanoroot.so) y
/// recolecta la salida hasta cierre o timeout.
class PtyLinuxCommandRunner implements LinuxCommandRunner {
  PtyLinuxCommandRunner({
    required this.bashPath,
    this.env = const {},
    this.ldPreload = 'libnanoroot.so',
    this.rows = 24,
    this.cols = 120,
  });

  final String bashPath;
  final Map<String, String> env;
  final String? ldPreload;
  final int rows;
  final int cols;

  @override
  Future<LinuxCommandResult> run(
    String command, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final started = DateTime.now();
    final session = await PtySession.open(
      argv: [bashPath, '-c', command],
      env: env,
      ldPreload: ldPreload,
      rows: rows,
      cols: cols,
    );
    final buffer = StringBuffer();
    final completer = Completer<void>();
    late StreamSubscription<List<int>> sub;
    sub = session.output.listen(
      (bytes) {
        try {
          buffer.write(utf8.decode(bytes, allowMalformed: true));
        } catch (_) {
          // bytes no textuales: ignorar (el pty puede emitir escapes).
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      // `bash -c` termina solo; el cierre del pty llega con el done.
      await completer.future.timeout(timeout);
    } on TimeoutException {
      session.close();
      await sub.cancel();
      return LinuxCommandResult(
        duration: DateTime.now().difference(started),
        infrastructureError: 'Tiempo límite de $timeout excedido.',
      );
    }
    await sub.cancel();
    session.close();
    return LinuxCommandResult(
      stdout: buffer.toString(),
      duration: DateTime.now().difference(started),
      // El pty no expone exitCode: solo distinguimos éxito (salida o cierre
      // limpio) de fallo de infraestructura.
      exitCode: null,
    );
  }
}

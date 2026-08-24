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

/// Ejecutor de un comando Linux. Interfaz mínima (ISP): el adapter no sabe
/// de pty ni canales.
abstract interface class LinuxCommandRunner {
  Future<LinuxCommandResult> run(String command, {Duration timeout});
}

/// Adapter de alto nivel: operaciones estructuradas sobre el subsistema.
class LinuxToolAdapter {
  LinuxToolAdapter({required LinuxCommandRunner runner}) : _runner = runner;

  final LinuxCommandRunner _runner;

  Future<LinuxCommandResult> list(String path) =>
      _run('ls -la ${_quote(path)}');

  Future<LinuxCommandResult> readFile(String path) =>
      _run('cat ${_quote(path)}');

  Future<LinuxCommandResult> writeFile(String path, String content) {
    // Heredoc con delimitador aleatorio: contenido arbitrario sin escapes.
    final marker = 'NANOEOF${DateTime.now().microsecondsSinceEpoch}';
    final command = 'cat > ${_quote(path)} << "$marker"\n$content\n$marker';
    return _run(command);
  }

  /// Comando libre (p.ej. git, python) — la política del dispatcher decide
  /// si es seguro; el adapter no valida contenido.
  Future<LinuxCommandResult> runCommand(String command) => _run(command);

  Future<LinuxCommandResult> _run(
    String command, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    return _runner.run(command, timeout: timeout);
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

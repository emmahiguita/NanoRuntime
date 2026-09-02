/// LinuxToolAdapter (Fase C9) — acceso CONTROLADO al subsistema Linux.
///
/// Regla del plan maestro: NO dar bash sin restricciones al LLM. Este adapter
/// expone operaciones estructuradas (list/readFile/writeFile/run) con
/// resultados tipados (stdout/stderr/exitCode/duration) y la gobernanza la
/// aplica el [PolicyEngine] ANTES de writes/comandos destructivos (el
/// dispatcher, nunca el adapter).
///
/// DIP: la ejecución real se inyecta vía [LinuxExecutionBackend] (contrato
/// core compartido con el Terminal); los tests usan fakes. El adapter es
/// puro: formatea comandos y resultados.
library;

import '../../../../core/services/linux_execution_backend.dart';

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

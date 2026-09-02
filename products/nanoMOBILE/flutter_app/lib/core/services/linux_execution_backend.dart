/// T1 — contrato CORE de ejecución Linux (no-interactivo).
///
/// Definido en core/services para que Terminal y Automation lo consuman SIN
/// conocerse entre sí. Evita que Automation dependa de la orquestación del UI
/// del Terminal (CommandExecutor: aliases/historial/registry/prompt/PTY).
///
/// La API es TIPADA (executable + arguments), NO `execute(String shellCommand)`,
/// para no convertir el shell string en la API principal del sistema.
library;

/// Solicitud de ejecución de UN ejecutable con argumentos.
class LinuxExecutionRequest {
  final String executable;
  final List<String> arguments;
  final String? cwd;
  final Map<String, String> environment;
  final Duration? timeout;

  const LinuxExecutionRequest({
    required this.executable,
    this.arguments = const [],
    this.cwd,
    this.environment = const {},
    this.timeout,
  });
}

/// Resultado tipado de una ejecución. No hay strings de estado libres.
class LinuxExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  const LinuxExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  bool get ok => exitCode == 0;
}

/// Backend de ejecución Linux no-interactivo. Implementaciones:
/// ShellExecutorLinuxBackend (Nanoshell FFI / rootfs / toybox).
abstract interface class LinuxExecutionBackend {
  Future<LinuxExecutionResult> execute(LinuxExecutionRequest request);
}

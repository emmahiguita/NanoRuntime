import 'terminal_types.dart'; // ShellResult

/// Interface para ejecución de comandos del rootfs.
///
/// Rompe la dependencia directa de CommandDispatcher, PtyManager, plugins y
/// managers sobre ShellExecutor concreto. Permite testing con mocks y desacopla
/// los comandos del terminal de la implementación específica de ejecución.
///
/// Implementaciones:
///   ShellExecutor — ejecución real vía Nanoshell FFI + worker process
///   (futuro) MockExecutor — para tests unitarios sin device
abstract class IBinExecutor {
  // ── Estado ──
  bool get initialized;

  // ── Directorios (delegan en RootfsManager internamente) ──
  String? get binDir;
  String? get usrDir;
  String? get baseDir;

  // ── Ciclo de vida ──
  Future<void> init();
  void killAll();

  // ── Ejecución ──

  /// Ejecuta en el worker (:nanoshell, sin GPU). Fallback in-process si
  /// el worker no está disponible. Retorna null si worker falla.
  Future<ShellResult?> execRootfsWorker(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
    Duration timeout,
  });

  /// Ejecuta in-process vía Nanoshell FFI. Sincrónico (bloqueante).
  Future<ShellResult> execRootfs(
    String binaryPath,
    List<String> args, {
    Map<String, String>? env,
    String? ldPreload,
  });

  /// BusyBox applet vía Nanoshell FFI.
  Future<ShellResult> toybox(
    List<String> args, {
    Map<String, String>? extraEnv,
  });

  /// Ejecuta vía /system/bin/sh -c (Process.start).
  Future<ShellResult> bash(
    String cmd, {
    Map<String, String>? env,
    Duration timeout,
  });

  /// Ejecuta con streaming de output línea por línea vía Process.start.
  /// Usado por ProotManager para proot (requiere stdout/stderr en tiempo real).
  Future<int> stream(
    String command,
    List<String> args, {
    String? workDir,
    Map<String, String>? env,
    void Function(String line)? onOut,
    void Function(String line)? onErr,
    Duration timeout,
    String? trackTag,
  });

  /// Mata un proceso lanzado con [stream] bajo [trackTag].
  /// SIGTERM inmediato + SIGKILL a los 2s. Retorna false si no existe.
  bool killTracked(String tag);
}

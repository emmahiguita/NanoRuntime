import 'linux_automation_types.dart';

/// Puerto primario (contrato de Clean Architecture) para el subsistema Linux
/// integrado en el cerebro de automatización de Nano.
///
/// Cumple:
/// - Inversión de Dependencias (DIP): Automation depende de este contrato abstracto,
///   no de implementaciones de bajo nivel de terminal ni de FFI directo.
/// - Segregación de Interfaces (ISP): Agrupa capacidades tipadas (FS, Archive, Process, Git)
///   sin forzar al agente a pasar por strings de shell no gobernados.
/// - EXECUTED ≠ VERIFIED: Todas las operaciones retornan [LinuxActionResult] con
///   evidencia de post-condición comprobada.
abstract interface class ILinuxAutomationExecutor {
  /// Indica si el subsistema Linux subyacente (rootfs/toybox) está disponible.
  bool get isAvailable;

  /// Asegura la inicialización asíncrona del subsistema.
  Future<void> init();

  // ── Operaciones de Sistema de Archivos (FS) ──

  /// Lista el contenido estructurado de un directorio.
  Future<LinuxActionResult<List<LinuxFileEntry>>> listFiles(
    String path, {
    bool recursive = false,
    Duration? timeout,
  });

  /// Lee el contenido textual de un archivo con límite de bytes opcional.
  Future<LinuxActionResult<String>> readFile(
    String path, {
    int? maxBytes,
    Duration? timeout,
  });

  /// Escribe contenido en un archivo y verifica post-condición en disco.
  Future<LinuxActionResult<bool>> writeFile(
    String path,
    String content, {
    bool verifyWritten = true,
    Duration? timeout,
  });

  /// Elimina un archivo o directorio y certifica que ha desaparecido.
  Future<LinuxActionResult<bool>> removePath(
    String path, {
    bool recursive = false,
    bool verifyDeleted = true,
    Duration? timeout,
  });

  /// Copia un archivo o directorio verificando el destino.
  Future<LinuxActionResult<bool>> copyPath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  });

  /// Mueve un archivo o directorio verificando origen y destino.
  Future<LinuxActionResult<bool>> movePath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  });

  /// Obtiene metadatos de una ruta específica.
  Future<LinuxActionResult<LinuxFileEntry>> statPath(
    String path, {
    Duration? timeout,
  });

  // ── Operaciones de Empaquetado y Archivos (Archive) ──

  /// Crea un archivo tar/tar.gz y verifica su integridad.
  Future<LinuxActionResult<bool>> createTar(
    String sourcePath,
    String tarPath, {
    bool gzip = true,
    bool verifyIntegrity = true,
    Duration? timeout,
  });

  /// Extrae un archivo tar/tar.gz y verifica la extracción en destino.
  Future<LinuxActionResult<bool>> extractTar(
    String tarPath,
    String targetDir, {
    bool gzip = true,
    Duration? timeout,
  });

  // ── Gestión y Supervisión de Procesos (Process) ──

  /// Lista los procesos actualmente en ejecución.
  Future<LinuxActionResult<List<LinuxProcessInfo>>> listProcesses({
    Duration? timeout,
  });

  /// Inicia un proceso en segundo plano con streaming y supervisión por tag.
  Future<LinuxActionResult<LinuxProcessHandle>> startTracked(
    String command,
    List<String> arguments, {
    required String trackTag,
    String? workDir,
    Map<String, String>? environment,
    Duration? timeout,
  });

  /// Detiene un proceso supervisado mediante su tag único (SIGTERM + SIGKILL).
  Future<LinuxActionResult<bool>> stopTracked(String trackTag);

  // ── Operaciones de Control de Versiones (Git) ──

  /// Consulta el estado de un repositorio Git.
  Future<LinuxActionResult<String>> gitStatus(
    String repoPath, {
    Duration? timeout,
  });

  /// Consulta el diff de cambios en un repositorio Git.
  Future<LinuxActionResult<String>> gitDiff(
    String repoPath, {
    Duration? timeout,
  });

  /// Consulta el historial reciente de commits en un repositorio Git.
  Future<LinuxActionResult<String>> gitLog(
    String repoPath, {
    int limit = 10,
    Duration? timeout,
  });

  // ── Ejecución Estructurada General ──

  /// Ejecuta un binario estructurado con argumentos explícitos y verificación opcional.
  Future<LinuxActionResult<String>> executeStructured(
    String executable,
    List<String> arguments, {
    String? cwd,
    Map<String, String>? environment,
    Duration? timeout,
    Future<LinuxVerificationDetail> Function(LinuxActionResult<void> rawResult)? customVerifier,
  });
}

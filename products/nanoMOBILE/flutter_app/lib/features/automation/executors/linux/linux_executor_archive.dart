part of 'nanoshell_linux_automation_executor.dart';

/// Operaciones de archive; delega al motor real y conserva su verificación.
mixin _LinuxExecutorArchive on _LinuxExecutorState {
  // ── Archive Delegation ──

  @override
  Future<LinuxActionResult<bool>> createTar(
    String sourcePath,
    String tarPath, {
    bool gzip = true,
    bool verifyIntegrity = true,
    Duration? timeout,
  }) => _archiveOps.createTar(
    sourcePath,
    tarPath,
    gzip: gzip,
    verifyIntegrity: verifyIntegrity,
    timeout: timeout,
  );

  @override
  Future<LinuxActionResult<bool>> extractTar(
    String tarPath,
    String targetDir, {
    bool gzip = true,
    Duration? timeout,
  }) =>
      _archiveOps.extractTar(tarPath, targetDir, gzip: gzip, timeout: timeout);
}

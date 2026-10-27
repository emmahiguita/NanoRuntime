part of 'nanoshell_linux_automation_executor.dart';

/// Operaciones de fs; delega al motor real y conserva su verificación.
mixin _LinuxExecutorFs on _LinuxExecutorState {
  // ── FS Delegation ──

  @override
  Future<LinuxActionResult<List<LinuxFileEntry>>> listFiles(
    String path, {
    bool recursive = false,
    Duration? timeout,
  }) => _fsOps.listFiles(path, recursive: recursive, timeout: timeout);

  @override
  Future<LinuxActionResult<String>> readFile(
    String path, {
    int? maxBytes,
    Duration? timeout,
  }) => _fsOps.readFile(path, maxBytes: maxBytes, timeout: timeout);

  @override
  Future<LinuxActionResult<bool>> writeFile(
    String path,
    String content, {
    bool verifyWritten = true,
    Duration? timeout,
  }) => _fsOps.writeFile(
    path,
    content,
    verifyWritten: verifyWritten,
    timeout: timeout,
  );

  @override
  Future<LinuxActionResult<bool>> removePath(
    String path, {
    bool recursive = false,
    bool verifyDeleted = true,
    Duration? timeout,
  }) => _fsOps.removePath(
    path,
    recursive: recursive,
    verifyDeleted: verifyDeleted,
    timeout: timeout,
  );

  @override
  Future<LinuxActionResult<bool>> copyPath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  }) => _fsOps.copyPath(
    source,
    destination,
    verifyTarget: verifyTarget,
    timeout: timeout,
  );

  @override
  Future<LinuxActionResult<bool>> movePath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  }) => _fsOps.movePath(
    source,
    destination,
    verifyTarget: verifyTarget,
    timeout: timeout,
  );

  @override
  Future<LinuxActionResult<LinuxFileEntry>> statPath(
    String path, {
    Duration? timeout,
  }) => _fsOps.statPath(path, timeout: timeout);
}

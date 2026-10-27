part of 'nanoshell_linux_fs_operations.dart';

/// Operaciones linux_fs_transfer: verifica rutas y conserva los resultados reales.
mixin _LinuxFsTransfer on _LinuxFsState {
  Future<LinuxActionResult<bool>> copyPath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isPathAllowed(destination, isWrite: true)) {
      return _securityViolation('Copia prohibida hacia destino: $destination');
    }

    final res = await _binExecutor.toybox([
      'cp',
      '-r',
      source,
      destination,
    ], timeout: timeout);
    LinuxVerificationDetail verification = LinuxVerificationDetail.skipped();
    if (res.exitCode == 0 && verifyTarget) {
      verification = await _verifier.verifyTargetPresent(destination);
    }

    return LinuxActionResult(
      data: verification.verified,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: verification,
    );
  }

  Future<LinuxActionResult<bool>> movePath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isPathAllowed(source, isWrite: true) ||
        !_securityPolicy.isPathAllowed(destination, isWrite: true)) {
      return _securityViolation('Movimiento no permitido en rutas protegidas.');
    }

    final res = await _binExecutor.toybox([
      'mv',
      source,
      destination,
    ], timeout: timeout);
    LinuxVerificationDetail verification = LinuxVerificationDetail.skipped();
    if (res.exitCode == 0 && verifyTarget) {
      verification = await _verifier.verifyTargetPresent(destination);
    }

    return LinuxActionResult(
      data: verification.verified,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: verification,
    );
  }
}

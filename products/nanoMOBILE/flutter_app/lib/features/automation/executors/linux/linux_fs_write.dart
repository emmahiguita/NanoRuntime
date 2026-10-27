part of 'nanoshell_linux_fs_operations.dart';

/// Operaciones linux_fs_write: verifica rutas y conserva los resultados reales.
mixin _LinuxFsWrite on _LinuxFsState {
  Future<LinuxActionResult<bool>> writeFile(
    String path,
    String content, {
    bool verifyWritten = true,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isPathAllowed(path, isWrite: true)) {
      return _securityViolation('Escritura prohibida en ruta protegida: $path');
    }

    final bytes = utf8.encode(content);
    if (bytes.length > 64 * 1024 || content.contains('\u0000')) {
      return _securityViolation(
        'La escritura de texto admite hasta 64 KiB y no admite bytes NUL.',
      );
    }
    // printf no añade saltos; las comillas protegen contenido como código literal.
    final script =
        "printf '%s' ${_LinuxFsState.quote(content)} > ${_LinuxFsState.quote(path)}";
    final res = await _binExecutor.bash(
      script,
      timeout: timeout ?? const Duration(seconds: 30),
    );

    LinuxVerificationDetail verification = LinuxVerificationDetail.skipped();
    if (res.exitCode == 0 && verifyWritten) {
      verification = await _verifier.verifyFileWritten(
        path,
        minBytes: bytes.length,
        expectedSha256: sha256.convert(bytes).toString(),
      );
    } else if (res.exitCode != 0) {
      verification = LinuxVerificationDetail.failed('file_write', res.stderr);
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

  Future<LinuxActionResult<bool>> removePath(
    String path, {
    bool recursive = false,
    bool verifyDeleted = true,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isPathAllowed(path, isWrite: true)) {
      return _securityViolation(
        'Eliminación prohibida en ruta protegida: $path',
      );
    }

    final args = ['rm', recursive ? '-rf' : '-f', path];
    final res = await _binExecutor.toybox(args, timeout: timeout);

    LinuxVerificationDetail verification = LinuxVerificationDetail.skipped();
    if (res.exitCode == 0 && verifyDeleted) {
      verification = await _verifier.verifyDeleted(path);
    } else if (res.exitCode != 0) {
      verification = LinuxVerificationDetail.failed('path_remove', res.stderr);
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

import '../../../terminal/i_bin_executor.dart';
import 'linux_action_verifier.dart';
import 'linux_automation_types.dart';
import 'linux_security_policy.dart';

/// Operaciones estructuradas del sistema de archivos sobre Nanoshell.
class NanoshellLinuxFsOperations {
  final IBinExecutor _binExecutor;
  final LinuxSecurityPolicy _securityPolicy;
  final LinuxActionVerifier _verifier;

  const NanoshellLinuxFsOperations({
    required IBinExecutor binExecutor,
    required LinuxSecurityPolicy securityPolicy,
    required LinuxActionVerifier verifier,
  })  : _binExecutor = binExecutor,
        _securityPolicy = securityPolicy,
        _verifier = verifier;

  Future<LinuxActionResult<List<LinuxFileEntry>>> listFiles(
    String path, {
    bool recursive = false,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final args = ['ls', recursive ? '-laR' : '-la', path];
    final res = await _binExecutor.toybox(args, timeout: timeout);

    final entries = <LinuxFileEntry>[];
    if (res.exitCode == 0) {
      final lines = res.stdout.split('\n');
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 8 && !parts[0].startsWith('total')) {
          final isDir = parts[0].startsWith('d');
          final name = parts.sublist(8).join(' ');
          if (name != '.' && name != '..') {
            entries.add(LinuxFileEntry(
              path: '$path/$name'.replaceAll('//', '/'),
              name: name,
              type: isDir ? LinuxFileType.directory : LinuxFileType.file,
              sizeBytes: int.tryParse(parts[4]) ?? 0,
              permissions: parts[0],
            ));
          }
        }
      }
    }

    return LinuxActionResult(
      data: entries,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied('fs_listed', 'Contenido listado.')
          : LinuxVerificationDetail.failed('fs_listed', res.stderr),
    );
  }

  Future<LinuxActionResult<String>> readFile(
    String path, {
    int? maxBytes,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final List<String> args = (maxBytes != null && maxBytes > 0)
        ? ['head', '-c', '$maxBytes', path]
        : ['cat', path];
    final res = await _binExecutor.toybox(args, timeout: timeout);

    return LinuxActionResult(
      data: res.exitCode == 0 ? res.stdout : null,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied('file_read', 'Lectura completada.')
          : LinuxVerificationDetail.failed('file_read', res.stderr),
    );
  }

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

    final marker = 'NANOEOF${DateTime.now().microsecondsSinceEpoch}';
    final script = 'cat > ${_quote(path)} << "$marker"\n$content\n$marker';
    final res = await _binExecutor.bash(script, timeout: timeout ?? const Duration(seconds: 30));

    LinuxVerificationDetail verification = LinuxVerificationDetail.skipped();
    if (res.exitCode == 0 && verifyWritten) {
      verification = await _verifier.verifyFileWritten(path, minBytes: content.isEmpty ? 0 : 1);
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
      return _securityViolation('Eliminación prohibida en ruta protegida: $path');
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

    final res = await _binExecutor.toybox(['cp', '-r', source, destination], timeout: timeout);
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

    final res = await _binExecutor.toybox(['mv', source, destination], timeout: timeout);
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

  Future<LinuxActionResult<LinuxFileEntry>> statPath(
    String path, {
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final res = await _binExecutor.toybox(['stat', '-c', '%s|%a|%F', path], timeout: timeout);

    LinuxFileEntry? entry;
    if (res.exitCode == 0) {
      final parts = res.stdout.trim().split('|');
      entry = LinuxFileEntry(
        path: path,
        name: path.split('/').last,
        type: parts.length > 2 && parts[2].toLowerCase().contains('directory')
            ? LinuxFileType.directory
            : LinuxFileType.file,
        sizeBytes: parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0,
        permissions: parts.length > 1 ? parts[1] : '',
      );
    }

    return LinuxActionResult(
      data: entry,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied('stat_ok', 'Metadatos leídos.')
          : LinuxVerificationDetail.failed('stat_ok', res.stderr),
    );
  }

  LinuxActionResult<T> _securityViolation<T>(String reason) {
    return LinuxActionResult<T>(
      exitCode: -1,
      stderr: reason,
      duration: Duration.zero,
      verification: LinuxVerificationDetail.failed('security_policy', reason),
    );
  }

  static String _quote(String s) => "'${s.replaceAll("'", r"'\''")}'";
}

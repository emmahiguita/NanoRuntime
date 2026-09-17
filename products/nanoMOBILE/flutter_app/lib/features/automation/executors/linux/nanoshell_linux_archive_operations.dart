import '../../../terminal/i_bin_executor.dart';
import 'linux_action_verifier.dart';
import 'linux_automation_types.dart';
import 'linux_security_policy.dart';

/// Operaciones de empaquetado y compresión sobre Nanoshell.
class NanoshellLinuxArchiveOperations {
  final IBinExecutor _binExecutor;
  final LinuxSecurityPolicy _securityPolicy;
  final LinuxActionVerifier _verifier;

  const NanoshellLinuxArchiveOperations({
    required IBinExecutor binExecutor,
    required LinuxSecurityPolicy securityPolicy,
    required LinuxActionVerifier verifier,
  })  : _binExecutor = binExecutor,
        _securityPolicy = securityPolicy,
        _verifier = verifier;

  Future<LinuxActionResult<bool>> createTar(
    String sourcePath,
    String tarPath, {
    bool gzip = true,
    bool verifyIntegrity = true,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isPathAllowed(tarPath, isWrite: true)) {
      return _securityViolation('Creación de archivo prohibida en: $tarPath');
    }

    final flag = gzip ? '-czf' : '-cf';
    final res = await _binExecutor.toybox(['tar', flag, tarPath, sourcePath], timeout: timeout);

    LinuxVerificationDetail verification = LinuxVerificationDetail.skipped();
    if (res.exitCode == 0 && verifyIntegrity) {
      verification = await _verifier.verifyArchiveIntegrity(tarPath, gzip: gzip);
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

  Future<LinuxActionResult<bool>> extractTar(
    String tarPath,
    String targetDir, {
    bool gzip = true,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isPathAllowed(targetDir, isWrite: true)) {
      return _securityViolation('Extracción prohibida en destino: $targetDir');
    }

    final flag = gzip ? '-xzf' : '-xf';
    final res = await _binExecutor.toybox(['tar', flag, tarPath, '-C', targetDir], timeout: timeout);

    return LinuxActionResult(
      data: res.exitCode == 0,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied('archive_extracted', 'Extracción exitosa.')
          : LinuxVerificationDetail.failed('archive_extracted', res.stderr),
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
}

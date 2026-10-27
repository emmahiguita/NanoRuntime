part of 'nanoshell_linux_fs_operations.dart';

/// Dependencias y errores compartidos de las operaciones de archivo.
abstract class _LinuxFsState {
  final IBinExecutor _binExecutor;
  final LinuxSecurityPolicy _securityPolicy;
  final LinuxActionVerifier _verifier;

  const _LinuxFsState({
    required IBinExecutor binExecutor,
    required LinuxSecurityPolicy securityPolicy,
    required LinuxActionVerifier verifier,
  }) : _binExecutor = binExecutor,
       _securityPolicy = securityPolicy,
       _verifier = verifier;

  LinuxActionResult<T> _securityViolation<T>(String reason) {
    return LinuxActionResult<T>(
      exitCode: -1,
      stderr: reason,
      duration: Duration.zero,
      verification: LinuxVerificationDetail.failed('security_policy', reason),
    );
  }

  static String quote(String s) => "'${s.replaceAll("'", r"'\''")}'";
}

part of 'nanoshell_linux_automation_executor.dart';

/// Operaciones de execution; delega al motor real y conserva su verificación.
mixin _LinuxExecutorExecution on _LinuxExecutorState {
  // ── Structured Execution ──

  @override
  Future<LinuxActionResult<String>> executeStructured(
    String executable,
    List<String> arguments, {
    String? cwd,
    Map<String, String>? environment,
    Duration? timeout,
    Future<LinuxVerificationDetail> Function(LinuxActionResult<void>)?
    customVerifier,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isExecutableSafe(executable)) {
      return LinuxActionResult(
        exitCode: -1,
        stderr: 'Ejecutable no seguro bloqueado por política: $executable',
        duration: Duration.zero,
        verification: LinuxVerificationDetail.failed(
          'security_policy',
          'Ejecutable no seguro: $executable',
        ),
      );
    }

    final env = Map<String, String>.from(environment ?? const {});
    if (cwd != null && cwd.isNotEmpty) {
      env['NANO_CWD'] = cwd;
      env['PWD'] = cwd;
    }

    final res = await _binExecutor.execRootfs(
      executable,
      arguments,
      env: env.isEmpty ? null : env,
      timeout: timeout,
    );

    LinuxVerificationDetail verification = LinuxVerificationDetail.skipped();
    if (customVerifier != null) {
      final raw = LinuxActionResult<void>(
        exitCode: res.exitCode,
        stdout: res.stdout,
        stderr: res.stderr,
        duration: DateTime.now().difference(started),
        verification: verification,
      );
      verification = await customVerifier(raw);
    } else if (res.exitCode == 0) {
      verification = LinuxVerificationDetail.satisfied(
        'cmd_executed',
        'Comando finalizado con exitCode 0.',
      );
    } else {
      verification = LinuxVerificationDetail.failed(
        'cmd_executed',
        'exitCode=${res.exitCode}: ${res.stderr}',
      );
    }

    return LinuxActionResult(
      data: res.exitCode == 0 ? res.stdout : null,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: verification,
    );
  }
}

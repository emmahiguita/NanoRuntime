part of 'nanoshell_linux_automation_executor.dart';

/// Operaciones de process; delega al motor real y conserva su verificación.
mixin _LinuxExecutorProcess on _LinuxExecutorState {
  // ── Process Management ──

  @override
  Future<LinuxActionResult<List<LinuxProcessInfo>>> listProcesses({
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final res = await _binExecutor.toybox([
      'ps',
      '-A',
      '-o',
      'PID,STAT,ARGS',
    ], timeout: timeout);

    final processes = <LinuxProcessInfo>[];
    if (res.exitCode == 0) {
      final lines = res.stdout.split('\n');
      for (final line in lines.skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          final pid = int.tryParse(parts[0]) ?? 0;
          if (pid > 0) {
            processes.add(
              LinuxProcessInfo(
                pid: pid,
                command: parts.sublist(2).join(' '),
                state: parts[1],
              ),
            );
          }
        }
      }
    }

    return LinuxActionResult(
      data: processes,
      exitCode: res.exitCode,
      stdout: res.stdout,
      stderr: res.stderr,
      duration: DateTime.now().difference(started),
      verification: res.exitCode == 0
          ? LinuxVerificationDetail.satisfied(
              'ps_listed',
              '${processes.length} procesos observados.',
            )
          : LinuxVerificationDetail.failed(
              'ps_failed',
              'No se pudo leer la tabla de procesos.',
            ),
    );
  }

  @override
  Future<LinuxActionResult<LinuxProcessHandle>> startTracked(
    String command,
    List<String> arguments, {
    required String trackTag,
    String? workDir,
    Map<String, String>? environment,
    Duration? timeout,
  }) => _supervisor.startProcess(
    command: command,
    arguments: arguments,
    trackTag: trackTag,
    workDir: workDir,
    environment: environment,
    timeout: timeout ?? const Duration(minutes: 30),
  );

  @override
  Future<LinuxActionResult<bool>> stopTracked(String trackTag) =>
      _supervisor.stopProcess(trackTag);
}

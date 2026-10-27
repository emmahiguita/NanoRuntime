part of 'nanoshell_linux_automation_executor.dart';

/// Operaciones de git; delega al motor real y conserva su verificación.
mixin _LinuxExecutorGit on _LinuxExecutorState {
  // ── Git Operations ──

  @override
  Future<LinuxActionResult<String>> gitStatus(
    String repoPath, {
    Duration? timeout,
  }) => executeStructured(
    'git',
    ['status', '--short'],
    cwd: repoPath,
    timeout: timeout,
  );

  @override
  Future<LinuxActionResult<String>> gitDiff(
    String repoPath, {
    Duration? timeout,
  }) => executeStructured('git', ['diff'], cwd: repoPath, timeout: timeout);

  @override
  Future<LinuxActionResult<String>> gitLog(
    String repoPath, {
    int limit = 10,
    Duration? timeout,
  }) => executeStructured(
    'git',
    ['log', '-n', '$limit', '--oneline'],
    cwd: repoPath,
    timeout: timeout,
  );
}

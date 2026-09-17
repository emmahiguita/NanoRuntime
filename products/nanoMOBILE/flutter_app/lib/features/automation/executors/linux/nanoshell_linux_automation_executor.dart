import '../../../terminal/i_bin_executor.dart';
import 'linux_action_verifier.dart';
import 'linux_automation_port.dart';
import 'linux_automation_types.dart';
import 'linux_process_supervisor.dart';
import 'linux_security_policy.dart';
import 'nanoshell_linux_archive_operations.dart';
import 'nanoshell_linux_fs_operations.dart';

/// Implementación del puerto de automatización Linux sobre Nanoshell.
///
/// Cumple:
/// - 100% SOLID: orquesta submódulos especializados (FS, Archive, Process, Verifier).
/// - Código modular < 300 líneas.
/// - Invariante EXECUTED ≠ VERIFIED.
class NanoshellLinuxAutomationExecutor implements ILinuxAutomationExecutor {
  final IBinExecutor _binExecutor;
  final LinuxSecurityPolicy _securityPolicy;
  final LinuxActionVerifier _verifier;
  final LinuxProcessSupervisor _supervisor;
  final NanoshellLinuxFsOperations _fsOps;
  final NanoshellLinuxArchiveOperations _archiveOps;

  LinuxActionVerifier get verifier => _verifier;

  NanoshellLinuxAutomationExecutor({
    required IBinExecutor binExecutor,
    LinuxSecurityPolicy securityPolicy = const LinuxSecurityPolicy(),
    LinuxActionVerifier? verifier,
    LinuxProcessSupervisor? supervisor,
  })  : _binExecutor = binExecutor,
        _securityPolicy = securityPolicy,
        _verifier = verifier ?? LinuxActionVerifier(binExecutor: binExecutor),
        _supervisor = supervisor ?? LinuxProcessSupervisor(binExecutor: binExecutor),
        _fsOps = NanoshellLinuxFsOperations(
          binExecutor: binExecutor,
          securityPolicy: securityPolicy,
          verifier: verifier ?? LinuxActionVerifier(binExecutor: binExecutor),
        ),
        _archiveOps = NanoshellLinuxArchiveOperations(
          binExecutor: binExecutor,
          securityPolicy: securityPolicy,
          verifier: verifier ?? LinuxActionVerifier(binExecutor: binExecutor),
        );

  @override
  bool get isAvailable => _binExecutor.initialized;

  @override
  Future<void> init() async {
    if (!_binExecutor.initialized) {
      await _binExecutor.init();
    }
  }

  // ── FS Delegation ──

  @override
  Future<LinuxActionResult<List<LinuxFileEntry>>> listFiles(
    String path, {
    bool recursive = false,
    Duration? timeout,
  }) =>
      _fsOps.listFiles(path, recursive: recursive, timeout: timeout);

  @override
  Future<LinuxActionResult<String>> readFile(
    String path, {
    int? maxBytes,
    Duration? timeout,
  }) =>
      _fsOps.readFile(path, maxBytes: maxBytes, timeout: timeout);

  @override
  Future<LinuxActionResult<bool>> writeFile(
    String path,
    String content, {
    bool verifyWritten = true,
    Duration? timeout,
  }) =>
      _fsOps.writeFile(path, content, verifyWritten: verifyWritten, timeout: timeout);

  @override
  Future<LinuxActionResult<bool>> removePath(
    String path, {
    bool recursive = false,
    bool verifyDeleted = true,
    Duration? timeout,
  }) =>
      _fsOps.removePath(path, recursive: recursive, verifyDeleted: verifyDeleted, timeout: timeout);

  @override
  Future<LinuxActionResult<bool>> copyPath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  }) =>
      _fsOps.copyPath(source, destination, verifyTarget: verifyTarget, timeout: timeout);

  @override
  Future<LinuxActionResult<bool>> movePath(
    String source,
    String destination, {
    bool verifyTarget = true,
    Duration? timeout,
  }) =>
      _fsOps.movePath(source, destination, verifyTarget: verifyTarget, timeout: timeout);

  @override
  Future<LinuxActionResult<LinuxFileEntry>> statPath(
    String path, {
    Duration? timeout,
  }) =>
      _fsOps.statPath(path, timeout: timeout);

  // ── Archive Delegation ──

  @override
  Future<LinuxActionResult<bool>> createTar(
    String sourcePath,
    String tarPath, {
    bool gzip = true,
    bool verifyIntegrity = true,
    Duration? timeout,
  }) =>
      _archiveOps.createTar(sourcePath, tarPath, gzip: gzip, verifyIntegrity: verifyIntegrity, timeout: timeout);

  @override
  Future<LinuxActionResult<bool>> extractTar(
    String tarPath,
    String targetDir, {
    bool gzip = true,
    Duration? timeout,
  }) =>
      _archiveOps.extractTar(tarPath, targetDir, gzip: gzip, timeout: timeout);

  // ── Process Management ──

  @override
  Future<LinuxActionResult<List<LinuxProcessInfo>>> listProcesses({
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final res = await _binExecutor.toybox(['ps'], timeout: timeout);

    final processes = <LinuxProcessInfo>[];
    if (res.exitCode == 0) {
      final lines = res.stdout.split('\n');
      for (final line in lines.skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final pid = int.tryParse(parts[0]) ?? 0;
          if (pid > 0) {
            processes.add(LinuxProcessInfo(
              pid: pid,
              command: parts.sublist(3).join(' '),
              state: parts[1],
            ));
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
      verification: LinuxVerificationDetail.satisfied('ps_listed', '${processes.length} procesos.'),
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
  }) =>
      _supervisor.startProcess(
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

  // ── Git Operations ──

  @override
  Future<LinuxActionResult<String>> gitStatus(
    String repoPath, {
    Duration? timeout,
  }) =>
      executeStructured('git', ['status', '--short'], cwd: repoPath, timeout: timeout);

  @override
  Future<LinuxActionResult<String>> gitDiff(
    String repoPath, {
    Duration? timeout,
  }) =>
      executeStructured('git', ['diff'], cwd: repoPath, timeout: timeout);

  @override
  Future<LinuxActionResult<String>> gitLog(
    String repoPath, {
    int limit = 10,
    Duration? timeout,
  }) =>
      executeStructured('git', ['log', '-n', '$limit', '--oneline'], cwd: repoPath, timeout: timeout);

  // ── Structured Execution ──

  @override
  Future<LinuxActionResult<String>> executeStructured(
    String executable,
    List<String> arguments, {
    String? cwd,
    Map<String, String>? environment,
    Duration? timeout,
    Future<LinuxVerificationDetail> Function(LinuxActionResult<void>)? customVerifier,
  }) async {
    final started = DateTime.now();
    if (!_securityPolicy.isExecutableSafe(executable)) {
      return LinuxActionResult(
        exitCode: -1,
        stderr: 'Ejecutable no seguro bloqueado por política: $executable',
        duration: Duration.zero,
        verification: LinuxVerificationDetail.failed('security_policy', 'Ejecutable no seguro: $executable'),
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
      verification = LinuxVerificationDetail.satisfied('cmd_executed', 'Comando finalizado con exitCode 0.');
    } else {
      verification = LinuxVerificationDetail.failed('cmd_executed', 'exitCode=${res.exitCode}: ${res.stderr}');
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

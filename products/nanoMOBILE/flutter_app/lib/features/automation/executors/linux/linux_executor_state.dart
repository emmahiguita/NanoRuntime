part of 'nanoshell_linux_automation_executor.dart';

/// Dependencias compartidas; el inspector observa tareas sin inventar un PID.
abstract class _LinuxExecutorState
    implements ILinuxAutomationExecutor, LinuxProcessInspector {
  final IBinExecutor _binExecutor;
  final LinuxSecurityPolicy _securityPolicy;
  final LinuxActionVerifier _verifier;
  final LinuxProcessSupervisor _supervisor;
  final NanoshellLinuxFsOperations _fsOps;
  final NanoshellLinuxArchiveOperations _archiveOps;

  LinuxActionVerifier get verifier => _verifier;

  _LinuxExecutorState({
    required IBinExecutor binExecutor,
    LinuxSecurityPolicy securityPolicy = const LinuxSecurityPolicy(),
    LinuxActionVerifier? verifier,
    LinuxProcessSupervisor? supervisor,
  }) : _binExecutor = binExecutor,
       _securityPolicy = securityPolicy,
       _verifier = verifier ?? LinuxActionVerifier(binExecutor: binExecutor),
       _supervisor =
           supervisor ?? LinuxProcessSupervisor(binExecutor: binExecutor),
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

  @override
  Map<String, Object?> inspectTracked(String tag) => _supervisor.inspect(tag);
}

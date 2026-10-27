import '../../../terminal/i_bin_executor.dart';
import 'linux_action_verifier.dart';
import 'linux_automation_port.dart';
import 'linux_automation_types.dart';
import 'linux_process_supervisor.dart';
import 'linux_security_policy.dart';
import 'nanoshell_linux_archive_operations.dart';
import 'nanoshell_linux_fs_operations.dart';

import 'linux_process_inspector.dart';

part 'linux_executor_state.dart';
part 'linux_executor_fs.dart';
part 'linux_executor_archive.dart';
part 'linux_executor_process.dart';
part 'linux_executor_git.dart';
part 'linux_executor_execution.dart';

/// Adaptador Linux: compone operaciones reales sin compartir la sesión PTY.
class NanoshellLinuxAutomationExecutor extends _LinuxExecutorState
    with
        _LinuxExecutorFs,
        _LinuxExecutorArchive,
        _LinuxExecutorProcess,
        _LinuxExecutorGit,
        _LinuxExecutorExecution {
  NanoshellLinuxAutomationExecutor({
    required super.binExecutor,
    super.securityPolicy,
    super.verifier,
    super.supervisor,
  });
}

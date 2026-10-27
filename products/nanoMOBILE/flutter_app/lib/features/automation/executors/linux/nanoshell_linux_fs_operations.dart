import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../terminal/i_bin_executor.dart';
import 'linux_action_verifier.dart';
import 'linux_automation_types.dart';
import 'linux_security_policy.dart';

/// Operaciones estructuradas del sistema de archivos sobre Nanoshell.

part 'linux_fs_state.dart';
part 'linux_fs_read.dart';
part 'linux_fs_write.dart';
part 'linux_fs_transfer.dart';

/// Conserva el puerto de filesystem y separa lectura, escritura y transferencias.
class NanoshellLinuxFsOperations extends _LinuxFsState
    with _LinuxFsRead, _LinuxFsWrite, _LinuxFsTransfer {
  const NanoshellLinuxFsOperations({
    required super.binExecutor,
    required super.securityPolicy,
    required super.verifier,
  });
}

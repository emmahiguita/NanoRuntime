part of 'linux_process_supervisor.dart';

/// Observa tareas y limita historial. Un Future pendiente no se presenta como PID vivo.
extension _LinuxProcessObservation on LinuxProcessSupervisor {
  Map<String, Object?> _inspect(String tag) => {
    'tag': tag,
    'known': _activeHandles.containsKey(tag),
    'state': _states[tag] ?? 'unknown',
    'pending': _runningTags.contains(tag),
    'pid': null,
    'pidVerified': false,
    'exitCode': _exitCodes[tag],
    'log': getLogs(tag),
  };

  void _purgeInactive() {
    final tags = _activeHandles.keys
        .where((tag) => !_runningTags.contains(tag))
        .toList();
    for (final tag in tags) {
      _activeHandles.remove(tag);
      _outputLogs.remove(tag);
      _states.remove(tag);
      _exitCodes.remove(tag);
      _completion.remove(tag);
    }
  }
}

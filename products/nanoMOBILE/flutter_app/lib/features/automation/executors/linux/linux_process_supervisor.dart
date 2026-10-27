import 'dart:async';
import 'dart:collection';
import '../../../terminal/i_bin_executor.dart';
import 'linux_automation_types.dart';
part 'linux_process_observation.dart';

/// Supervisa solicitudes y su finalización real. Solicitar no demuestra arranque.
class LinuxProcessSupervisor {
  LinuxProcessSupervisor({
    required IBinExecutor binExecutor,
    this.maxLogLines = 300,
  }) : _binExecutor = binExecutor;
  final IBinExecutor _binExecutor;
  final int maxLogLines;
  final _activeHandles = <String, LinuxProcessHandle>{};
  final _outputLogs = <String, Queue<String>>{};
  final _runningTags = <String>{};
  final _completion = <String, Future<int>>{};
  final _states = <String, String>{};
  final _exitCodes = <String, int>{};

  List<LinuxProcessHandle> get activeProcesses => _activeHandles.entries
      .where((entry) => _runningTags.contains(entry.key))
      .map((entry) => entry.value)
      .toList();
  // Compatibilidad: tarea pendiente; el estado observable vive en inspect().
  bool isRunning(String tag) => _runningTags.contains(tag);
  List<String> getLogs(String tag) => _outputLogs[tag]?.toList() ?? const [];
  Map<String, Object?> inspect(String tag) => _inspect(tag);
  void purgeInactive() => _purgeInactive();

  Future<LinuxActionResult<LinuxProcessHandle>> startProcess({
    required String command,
    List<String> arguments = const [],
    required String trackTag,
    String? workDir,
    Map<String, String>? environment,
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final started = DateTime.now();
    if (_runningTags.contains(trackTag) || _runningTags.length >= 8) {
      return LinuxActionResult(
        exitCode: -1,
        duration: Duration.zero,
        verification: LinuxVerificationDetail.failed(
          'process_capacity',
          'Tag ocupado o límite de ocho tareas pendientes.',
        ),
      );
    }
    // Conserva como máximo 32 historiales; nunca mata tareas para liberar espacio.
    if (_activeHandles.length >= 32) _purgeInactive();
    final handle = LinuxProcessHandle(
      trackTag: trackTag,
      command: command,
      arguments: arguments,
      startedAt: started,
    );
    _activeHandles[trackTag] = handle;
    _outputLogs[trackTag] = Queue<String>();
    _states[trackTag] = 'requested';
    _exitCodes.remove(trackTag);
    _runningTags.add(trackTag);
    void observe(String line, String source) {
      if (!identical(_activeHandles[trackTag], handle)) return;
      if (_runningTags.contains(trackTag)) _states[trackTag] = 'outputObserved';
      _appendLog(trackTag, '$source $line');
    }

    final operation = Future<int>.sync(
      () => _binExecutor.stream(
        command,
        arguments,
        workDir: workDir,
        env: environment,
        trackTag: trackTag,
        timeout: timeout,
        onOut: (line) => observe(line, '[OUT]'),
        onErr: (line) => observe(line, '[ERR]'),
      ),
    );
    // El futuro compartido se completa también en fallos de arranque.
    final tracked = operation.then(
      (code) {
        if (identical(_activeHandles[trackTag], handle)) {
          _runningTags.remove(trackTag);
          _exitCodes[trackTag] = code;
          _states[trackTag] = code == 0 ? 'completed' : 'failed';
          _appendLog(trackTag, '[SYS] Finalizó con código $code');
        }
        return code;
      },
      onError: (Object error) {
        if (identical(_activeHandles[trackTag], handle)) {
          _runningTags.remove(trackTag);
          _states[trackTag] = 'failed';
          _exitCodes[trackTag] = -1;
          _appendLog(trackTag, '[SYS] No se pudo completar el proceso.');
        }
        return -1;
      },
    );
    _completion[trackTag] = tracked;
    return LinuxActionResult(
      data: handle,
      exitCode: 0,
      duration: DateTime.now().difference(started),
      verification: LinuxVerificationDetail.failed(
        'process_requested',
        'Solicitud registrada; consulta el tag para conocer su resultado. No hay PID verificado.',
      ),
    );
  }

  Future<LinuxActionResult<bool>> stopProcess(String tag) async {
    final started = DateTime.now();
    final completion = _completion[tag];
    final signalled =
        _runningTags.contains(tag) && _binExecutor.killTracked(tag);
    if (!signalled || completion == null) {
      return LinuxActionResult(
        data: false,
        exitCode: -1,
        duration: Duration.zero,
        verification: LinuxVerificationDetail.failed(
          'process_not_signalled',
          'No se encontró un proceso nativo para ese tag.',
        ),
      );
    }
    _states[tag] = 'stopping';
    try {
      await completion.timeout(const Duration(seconds: 3));
      return LinuxActionResult(
        data: true,
        exitCode: 0,
        duration: DateTime.now().difference(started),
        verification: LinuxVerificationDetail.satisfied(
          'process_exited',
          'Se confirmó la finalización de la tarea tras solicitar su parada.',
        ),
      );
    } on TimeoutException {
      return LinuxActionResult(
        data: false,
        exitCode: 0,
        duration: DateTime.now().difference(started),
        verification: LinuxVerificationDetail.failed(
          'process_stop_pending',
          'Se envió la señal; la finalización aún no está confirmada.',
        ),
      );
    }
  }

  void _appendLog(String tag, String line) {
    final queue = _outputLogs.putIfAbsent(tag, () => Queue<String>());
    if (queue.length >= maxLogLines.clamp(1, 1000)) queue.removeFirst();
    queue.addLast(line.length > 4096 ? '${line.substring(0, 4096)}…' : line);
  }
}

import 'dart:collection';
import '../../../terminal/i_bin_executor.dart';
import 'linux_automation_types.dart';

/// Supervisor de procesos en streaming y segundo plano para el motor Linux.
///
/// Gestiona tareas de larga duración (servidores, compilaciones, pipelines)
/// evitando colisiones de tags, fugas de memoria y procesos zombis.
class LinuxProcessSupervisor {
  final IBinExecutor _binExecutor;
  final int maxLogLines;

  final Map<String, LinuxProcessHandle> _activeHandles = {};
  final Map<String, Queue<String>> _outputLogs = {};
  final Set<String> _runningTags = {};

  LinuxProcessSupervisor({
    required IBinExecutor binExecutor,
    this.maxLogLines = 300,
  }) : _binExecutor = binExecutor;

  /// Lista los handles de procesos actualmente supervisados.
  List<LinuxProcessHandle> get activeProcesses => _activeHandles.values.toList();

  /// Indica si un tag de proceso específico sigue en ejecución activa.
  bool isRunning(String trackTag) => _runningTags.contains(trackTag);

  /// Retorna las líneas de log acumuladas para un proceso.
  List<String> getLogs(String trackTag) =>
      _outputLogs[trackTag]?.toList() ?? const [];

  /// Inicia un proceso en streaming supervisado bajo un tag único.
  Future<LinuxActionResult<LinuxProcessHandle>> startProcess({
    required String command,
    List<String> arguments = const [],
    required String trackTag,
    String? workDir,
    Map<String, String>? environment,
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final started = DateTime.now();

    if (_runningTags.contains(trackTag)) {
      return LinuxActionResult(
        exitCode: -1,
        duration: Duration.zero,
        stderr: 'Ya existe un proceso activo con trackTag: "$trackTag"',
        verification: LinuxVerificationDetail.failed(
          'unique_track_tag',
          'Conflicto de trackTag activo.',
        ),
      );
    }

    final handle = LinuxProcessHandle(
      trackTag: trackTag,
      command: command,
      arguments: arguments,
      startedAt: started,
    );

    _activeHandles[trackTag] = handle;
    _outputLogs[trackTag] = Queue<String>();
    _runningTags.add(trackTag);

    // Disparar en streaming asíncrono
    _binExecutor.stream(
      command,
      arguments,
      workDir: workDir,
      env: environment,
      trackTag: trackTag,
      timeout: timeout,
      onOut: (line) => _appendLog(trackTag, '[OUT] $line'),
      onErr: (line) => _appendLog(trackTag, '[ERR] $line'),
    ).then((exitCode) {
      _runningTags.remove(trackTag);
      _appendLog(trackTag, '[SYS] Proceso finalizado con código $exitCode');
    }).catchError((error) {
      _runningTags.remove(trackTag);
      _appendLog(trackTag, '[SYS] Error de ejecución: $error');
    });

    return LinuxActionResult(
      data: handle,
      exitCode: 0,
      duration: DateTime.now().difference(started),
      verification: LinuxVerificationDetail.satisfied(
        'process_started',
        'Proceso iniciado y supervisado bajo tag "$trackTag".',
      ),
    );
  }

  /// Detiene y mata un proceso supervisado.
  Future<LinuxActionResult<bool>> stopProcess(String trackTag) async {
    final started = DateTime.now();
    final killed = _binExecutor.killTracked(trackTag);
    _runningTags.remove(trackTag);

    return LinuxActionResult(
      data: killed,
      exitCode: killed ? 0 : 1,
      duration: DateTime.now().difference(started),
      verification: killed
          ? LinuxVerificationDetail.satisfied(
              'process_killed',
              'Señal de terminación enviada con éxito a "$trackTag".',
            )
          : LinuxVerificationDetail.failed(
              'process_killed',
              'No se encontró un proceso activo con trackTag "$trackTag".',
            ),
    );
  }

  void _appendLog(String trackTag, String line) {
    final queue = _outputLogs.putIfAbsent(trackTag, () => Queue<String>());
    if (queue.length >= maxLogLines) {
      queue.removeFirst();
    }
    queue.addLast(line);
  }

  /// Limpia registros de procesos ya finalizados.
  void purgeInactive() {
    final inactiveTags = _activeHandles.keys
        .where((tag) => !_runningTags.contains(tag))
        .toList();
    for (final tag in inactiveTags) {
      _activeHandles.remove(tag);
      _outputLogs.remove(tag);
    }
  }
}

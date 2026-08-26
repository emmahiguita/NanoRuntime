import 'dart:async';

import 'terminal_types.dart';

/// Tarea programada para crontab interno.
class CronJob {
  final int intervalMin;
  final String command;
  Timer timer;
  CronJob({
    required this.intervalMin,
    required this.command,
    required this.timer,
  });
}

/// Planificador de tareas periódicas: crontab + watch.
///
/// Extraído de _TermState (SRP). Gestiona el ciclo de vida de timers,
/// expone comandos crontab y watch como CmdFn, y limpia en dispose().
class CronScheduler {
  final List<CronJob> _cronJobs = [];
  final List<Timer> _timers = [];

  /// Callback que ejecuta un comando (inyectado por _TermState).
  final Future<void> Function(String raw) execCmd;

  /// Callback para verificar si el widget sigue mounted + alive.
  final bool Function() isAlive;

  CronScheduler({required this.execCmd, required this.isAlive});

  List<CronJob> get jobs => List.unmodifiable(_cronJobs);
  List<Timer> get timers => List.unmodifiable(_timers);

  /// Registra comandos crontab y watch en el registry.
  void register(void Function(String, CmdFn) r, void Function(String, Ln) o) {
    r('crontab', (a, c, out, af) {
      if (a.isEmpty || a[0] == '-l') {
        if (_cronJobs.isEmpty) {
          out('crontab: sin tareas programadas', Ln.info);
          return;
        }
        out('CRON JOBS:', Ln.header);
        for (int i = 0; i < _cronJobs.length; i++) {
          out(
            '  [$i] */${_cronJobs[i].intervalMin} * * * *  ${_cronJobs[i].command}',
            Ln.stdout,
          );
        }
      } else if (a[0] == '-e' && a.length >= 2) {
        final interval = int.tryParse(a[1]);
        if (interval == null || interval < 1) {
          out('crontab: intervalo invalido', Ln.stderr);
          return;
        }
        final command = a.sublist(2).join(' ');
        if (command.isEmpty) {
          out('crontab: comando requerido', Ln.stderr);
          return;
        }
        final job = CronJob(
          intervalMin: interval,
          command: command,
          timer: Timer.periodic(Duration(minutes: interval), (_) {
            if (!isAlive()) return;
            execCmd(command);
          }),
        );
        _cronJobs.add(job);
        _timers.add(job.timer);
        out('crontab: agendado #${_cronJobs.length - 1}', Ln.success);
      } else if (a[0] == '-r' && a.length >= 2) {
        final idx = int.tryParse(a[1]);
        if (idx == null || idx < 0 || idx >= _cronJobs.length) {
          out('crontab: indice invalido', Ln.stderr);
          return;
        }
        final removed = _cronJobs.removeAt(idx);
        removed.timer.cancel();
        _timers.remove(removed.timer);
        out('crontab: tarea #$idx eliminada.', Ln.success);
      } else {
        out(
          'crontab: uso: crontab -l | -e "<min>" "<cmd>" | -r <num>',
          Ln.stderr,
        );
      }
    });

    r('watch', (a, c, out, af) {
      if (a.length < 2) {
        out('watch: uso: watch <segundos> <comando>', Ln.stderr);
        return;
      }
      final sec = int.tryParse(a[0]);
      if (sec == null || sec < 1) {
        out('watch: segundos invalidos', Ln.stderr);
        return;
      }
      final command = a.sublist(1).join(' ');
      out('watch: ejecutando "$command" cada ${sec}s.', Ln.info);
      execCmd(command);
      final timer = Timer.periodic(Duration(seconds: sec), (_) {
        if (!isAlive()) return;
        execCmd(command);
      });
      _timers.add(timer);
    });
  }

  /// Cancela todos los timers y limpia las listas.
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _cronJobs.clear();
  }
}

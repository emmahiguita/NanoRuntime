part of 'terminal_core.dart';

/// Componente registry: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalRegistry on _TerminalStateBase {
  @override
  void _buildRegistry() {
    _registerPlugins();
    _registerDiagnostics();
    _registerInference();
    _registerTuning();
    _registerGpu();
  }

  void _registerPlugins() {
    final s = _services;
    void r(String n, CmdFn f) => _cmds[n] = f;
    SystemPlugin().register(r, s);
    MonitorPlugin().register(r, s);
    ProcessPlugin().register(r, s);
    PkgPlugin().register(r, s);
    NetworkPlugin().register(r, s);
    DevOpsPlugin().register(r, s);
    DashboardPlugin().register(r, s);
    _cron = CronScheduler(
      execCmd: (raw) => CommandExecutor.execute(raw, _execCtx()),
      isAlive: () => _alive,
    )..register(r, _out);
    _cmds['pty'] = (a, c, o, af) {
      final cmd = a.isNotEmpty ? a[0] : 'bash';
      _ptyOpen([cmd, ...a.skip(1)], o: o);
    };
  }
}

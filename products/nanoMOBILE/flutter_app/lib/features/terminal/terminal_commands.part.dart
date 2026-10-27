part of 'terminal_core.dart';

/// Componente commands: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalCommands on _TerminalStateBase {
  void _exec(String raw) {
    CommandExecutor.execute(raw, _execCtx());
  }

  /// TER-10 — "usar" un comando de la Noar Library en el terminal activo.
  /// Con bash PTY: bytes crudos + \r (mismo camino del KeyEvent, verificado
  /// en device — el onSubmitted del IME no alimenta al PTY). Sin PTY:
  /// insertar en el input y ejecutar vía dispatcher.
  @override
  void _useCommand(String cmd) {
    if (_ptyActive) {
      _pty!.writeBytes(utf8.encode(cmd));
      _pty!.writeBytes([0x0d]);
      _fn.requestFocus();
    } else {
      _in.text = cmd;
      _exec(cmd);
    }
  }

  /// Expone la ejecución de comandos para que la Barra Universal
  /// pueda inyectar comandos directamente en la sesión activa.
  @override
  Future<void> executeCommand(String cmd) async {
    if (!_alive || !mounted) return;
    await CommandExecutor.execute(cmd, _execCtx());
  }

  /// Construye el contexto de ejecución del CommandExecutor (T0.1B). Cada
  /// campo mutable se toma del state en el momento de la llamada; el executor
  /// es la única implementación del pipeline, el state solo presta sus campos.
  @override
  CmdExecCtx _execCtx() {
    // TER-29: _hist crecía sin límite en memoria — el executor añade cada
    // comando ejecutado y el cap de 500 solo se aplica al persistir. Trim
    // vivo aquí, punto único de entrega al executor.
    if (_hist.length > 1000) {
      _hist.removeRange(0, _hist.length - 1000);
    }
    return CmdExecCtx(
      out: _out,
      after: _after,
      pty: _pty,
      ptyActive: _ptyActive,
      closePty: () => _ptyClose(),
      openPty: (argv) => _ptyOpen(argv),
      ps1: _ps1,
      history: _hist,
      historyIndex: _hIdx,
      input: _in,
      saveToNoar: (cmd, tag) => _noar.save(cmd, tag),
      tagFor: (cmd) => CommandTagger.tag(cmd),
      dispatcher: _dispatcher,
      hasShellOps: _hasShellOps,
      shell: _shell,
      bashCwd: _bashCwd,
      rootfs: _rootfs,
      realFs: _realFs,
      isAndroid: Platform.isAndroid,
      rootfsEnv: _deps.rootfsEnv,
      shellOut: _shellOut,
      tokenize: _tok,
      ctx: _ctx,
      cmds: _cmds,
      audit: null,
      alive: _alive,
    );
  }

  /// Vuelca la salida de un ShellResult en el buffer del terminal.
  void _shellOut(ShellResult r) {
    if (!_alive || !mounted) return;
    for (final l in r.stdout.split('\n')) {
      if (l.isNotEmpty) _out(l, Ln.stdout);
    }
    for (final l in r.stderr.split('\n')) {
      if (l.isNotEmpty) _out(l, Ln.stderr);
    }
  }
}

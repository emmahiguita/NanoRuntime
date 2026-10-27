part of 'terminal_core.dart';

/// Componente lifecycle: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalLifecycle on _TerminalStateBase {
  @override
  void _out(String t, Ln ty) {
    if (t.isEmpty && ty == Ln.stdout) return;
    if (!mounted) return;
    _controller.out(t, ty);
    if (!_scrollPending) {
      _scrollPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollPending = false;
        if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
      });
    }
  }

  @override
  void _after(Duration d, VoidCallback cb) {
    late final Timer t;
    t = Timer(d, () {
      _timers.remove(t); // no acumular timers muertos en sesiones largas
      if (_alive) cb();
    });
    _timers.add(t);
  }

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? LLMEngineClient();
    _ctx.cwd = widget.initialCwd;
    _realFs = RealFsShell(
      root: Platform.isAndroid
          ? '/data/data/dev.nanoai.mobile/files/nano'
          : '${Directory.systemTemp.path}/nano_real_root',
    );
    _buildRegistry(); // terminal-specific commands (ai, gpu, docker, kali, etc.)
    _fetchDeviceIdentity(); // async: uid, uname, hostname reales del device
    _initShell(); // async: extrae bash/toybox + verifica rootfs (crea ShellExecutor + RootfsManager compartidos)
    _noar.load(); // async: carga librería de comandos guardados
    _out('NanoTerminal  rootfs ARM64', Ln.header);
    _out('Modo: auto-PTY (bash interactivo real)', Ln.info);
    _out('', Ln.stdout);
    _loadHistory();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void handleLifecycleState(AppLifecycleState state) {
    _ptyManager?.handleLifecycleState(state);
  }

  @override
  void didUpdateWidget(covariant NanoTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      final pm = _ptyManager;
      if (pm != null) {
        if (widget.visible) {
          pm.resumePolling();
        } else {
          pm.pausePolling();
        }
      }
      // TER-27: lazy open — el tab nace oculto en el IndexedStack y
      // visible NUNCA cambia desde false, así que el auto-open del init
      // gateado por visible deja el PTY sin abrir para siempre. Abrirlo
      // aquí, en la transición false→true, una sola vez.
      if (widget.visible &&
          !_autoPtyDone &&
          widget.initialCommand == null &&
          _shell?.initialized == true) {
        _autoOpenBash();
      }
    }
  }

  /// TER-21/TER-27: auto bash PTY con PROMPT_COMMAND OSC 7 (cwd real).
  /// Un solo punto de apertura — init (si visible) y transición a visible.
  @override
  void _autoOpenBash() {
    _autoPtyDone = true;
    _after(
      const Duration(milliseconds: 500),
      () => _ptyOpen(
        ['bash'],
        env: {'PROMPT_COMMAND': r'printf "\033]7;file://%s\033\\" "$PWD"'},
      ),
    );
  }

  @override
  void dispose() {
    _saveHistory();
    _alive = false;

    _ptyClose(notify: false);
    _ptyManager?.dispose();
    _ptyManager = null;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _cron?.dispose();
    _cron = null;
    // TER-AUT-03: mata daemons activos (share_http / sshd_daemon) si el tab
    // se cierra sin `stop` explícito. El ShellExecutor pertenece a
    // TerminalDependencies (singleton); solo matamos los tags de ESTA sesión.
    _dispatcher?.dispose();
    _realFs.killActiveProcess();
    // El shell y el runtime Docker pertenecen a TerminalDependencies
    // (singleton compartido entre pestañas). Cerrar UNA pestaña no debe
    // matar los workers FFI ni el runtime de las demás sesiones: el dueño
    // único los libera en TerminalDependencies.dispose() (vida de la app).
    _localIn.dispose();
    _sc.dispose();
    _localFn.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }
}

part of 'terminal_core.dart';

/// Componente pty: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalPty on _TerminalStateBase {
  /// Aplica el tamaño del área visible al PTY y al buffer ANSI. Los apps fullscreen (vim/htop) consultan TIOCGWINSZ en cada redibujo; sin resize real dibujan en 24x80 aunque la pantalla sea mayor. Se difiere a post-frame porque toca ChangeNotifier (evita rebuild en build).
  ///
  /// Usa las MISMAS métricas de celda que AnsiTerminalView (AnsiMetrics):
  /// antes se asumía 7.6px de ancho y 20px de alto a mano; con la fuente
  /// real del device el grid del render y el del buffer divergían y las
  /// cajas/columnas de apps fullscreen se descuadraban (errores de píxel).
  @override
  void _applyPtySize(double w, double h) {
    if (_pty == null || !_ptyActive || _ansi == null) return;
    final m = AnsiMetrics.measure(terminalTextStyle);
    final rows = (h / m.cellH).floor().clamp(1, 200);
    final cols = (w / m.cellW).floor().clamp(1, 300);
    if (rows == _ptyRows && cols == _ptyCols) return;
    _ptyRows = rows;
    _ptyCols = cols;
    // TER-28: capturar en schedule — la sesión puede cerrarse (pty=null)
    // entre el schedule y el callback; _pty! aquí era NPE en vivo.
    final ansi = _ansi;
    final pty = _pty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || pty == null || pty.isClosed) return;
      ansi?.reset(rows: rows, cols: cols);
      pty.resize(rows, cols);
    });
  }

  /// Abre una sesión PTY con [argv]. Si falla, vuelca error por [o].
  @override
  Future<void> _ptyOpen(
    List<String> argv, {
    Map<String, String>? env,
    String? ldPreload,
    void Function(String, Ln)? o,
  }) async {
    final out = o ?? _out;
    final pm = _ptyManager;
    if (pm == null) {
      out('[pty] gestor de sesiones no inicializado.', Ln.stderr);
      return;
    }
    final ok = await pm.open(
      argv,
      env: env,
      ldPreload:
          ldPreload ?? (_rootfs?.isInstalled == true ? 'libnanoroot.so' : null),
    );
    if (!ok) {
      out('[pty] no se pudo abrir la sesión interactiva.', Ln.stderr);
      return;
    }
    _pty = pm.session;
    _ansi = pm.ansi;
    if (mounted) setState(() {});
    out(
      '— terminal interactivo (Ctrl+C para SIGINT, escribe "exit") —',
      Ln.system,
    );
    out('pty> ', Ln.prompt);
  }

  @override
  Future<void> _ptyClose({bool notify = true}) async {
    _pty = null;
    _ansi = null;
    _ptyLines.clear();
    final pm = _ptyManager;
    if (pm != null) {
      await pm.close();
    }
    if (notify && mounted) setState(() {});
  }
}

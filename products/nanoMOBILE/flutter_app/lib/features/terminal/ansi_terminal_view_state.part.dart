part of 'ansi_terminal.dart';

/// Componente ANSI: conserva el protocolo y separa su representación.
class _AnsiTerminalViewState extends State<AnsiTerminalView>
    with WidgetsBindingObserver {
  bool _foreground = true, _visible = true, _reducedMotion = false;
  Timer? _blink;
  bool _cursorOn = true;
  ScrollController? _sc;
  bool _wasAtBottom = true;
  bool _pendingScroll = false;

  AnsiTerminal get _term => widget.terminal;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
    WidgetsBinding.instance.addObserver(this);
    // Cuando el buffer cambia (feed), si estábamos en el fondo, seguirlo.
    _term.addListener(_onBufferChange);
  }

  @override
  void didUpdateWidget(covariant AnsiTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBlink();
    // TER-31: el PTY puede reemplazarse in-place (`pty python` sobre bash
    // activo) sin que este State se desmonte — el listener quedaba en el
    // terminal viejo (dispuesto) y el auto-scroll moría para la sesión nueva.
    if (!identical(oldWidget.terminal, widget.terminal)) {
      oldWidget.terminal.removeListener(_onBufferChange);
      _term.addListener(_onBufferChange);
    }
  }

  void _onBufferChange() {
    final sc = _sc;
    if (sc != null && sc.hasClients) {
      final pos = sc.position;
      _wasAtBottom = pos.maxScrollExtent - pos.pixels < 32;
    }
    _pendingScroll = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blink?.cancel();
    _term.removeListener(_onBufferChange);
    _sc?.dispose();
    super.dispose();
  }

  /// El cursor trabaja solo para la pestaña visible y la aplicación en primer plano.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.of(context);
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncBlink();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncBlink();
  }

  void _syncBlink() {
    _blink?.cancel();
    _blink = null;
    _cursorOn = true;
    if (!_foreground || !_visible || !widget.active || _reducedMotion) return;
    _blink = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final mono = base.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['monospace'],
      height: 1.15,
    );
    final defFg = mono.color ?? const Color(0xFFE0E0E0);
    final showCursor = _term.cursorVisible && _cursorOn;
    final metrics = AnsiMetrics.measure(mono);

    return AnimatedBuilder(
      animation: _term,
      builder: (_, __) {
        // Auto-scroll al fondo tras un feed (si el usuario no subió).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_pendingScroll) return;
          _pendingScroll = false;
          final sc = _sc;
          if (sc != null && sc.hasClients && _wasAtBottom) {
            sc.jumpTo(sc.position.maxScrollExtent);
          }
        });

        final hist = _term.historyLength;
        final totalRows = hist + _term.rows;
        return ListView.builder(
          controller: _sc,
          padding: const EdgeInsets.all(6),
          itemCount: totalRows,
          itemExtent: metrics.cellH,
          itemBuilder: (context, i) {
            if (i < hist) {
              return RepaintBoundary(
                child: _TermLine(
                  cells: _term.historyRow(i),
                  baseStyle: mono,
                  defFg: defFg,
                  defaultBg: Theme.of(context).colorScheme.surface,
                  lineHeight: metrics.cellH,
                ),
              );
            }
            final r = i - hist;
            final isCursorRow = r == _term.cursorRow;
            final cursorCol = showCursor && isCursorRow
                ? _term.cursorCol
                : null;
            return RepaintBoundary(
              child: _TermLine(
                cells: _term.row(r),
                baseStyle: mono,
                defFg: defFg,
                defaultBg: Theme.of(context).colorScheme.surface,
                cursorCol: cursorCol,
                lineHeight: metrics.cellH,
              ),
            );
          },
        );
      },
    );
  }
}

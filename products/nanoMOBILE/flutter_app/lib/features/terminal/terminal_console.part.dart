part of 'terminal_core.dart';

/// Componente console: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalConsole on _TerminalStateBase {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _ptyActive ? 'Consola interactiva' : 'Modo comando';
    return DefaultTextStyle(
      style: terminalTextStyle.copyWith(color: scheme.onSurface),
      child: ColoredBox(
        color: scheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _ptyActive ? Icons.terminal_rounded : Icons.code_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _fn.requestFocus(),
                // Conserva los clics de programas que habilitan ratón en el protocolo PTY.
                onTapDown: _ansi?.mouseEnabled == true
                    ? (details) {
                        final cell = AnsiMetrics.measure(terminalTextStyle);
                        final row = (details.localPosition.dy / cell.cellH)
                            .floor();
                        final col = (details.localPosition.dx / cell.cellW)
                            .floor();
                        _pty?.writeBytes([27, 91, 77, 32, col + 33, row + 33]);
                      }
                    : null,
                child: _ansi != null
                    ? LayoutBuilder(
                        builder: (context, box) {
                          _applyPtySize(box.maxWidth, box.maxHeight);
                          return SelectionArea(
                            child: AnsiTerminalView(
                              _ansi!,
                              active: widget.visible,
                            ),
                          );
                        },
                      )
                    : SelectionArea(
                        child: ListenableBuilder(
                          listenable: _controller,
                          builder: (context, _) => ListView.builder(
                            controller: _sc,
                            padding: const EdgeInsets.all(12),
                            itemCount: _lines.length,
                            itemBuilder: (context, index) {
                              final line = _lines[index];
                              return Text(
                                line.text,
                                style: terminalTextStyle.copyWith(
                                  color: line.type == Ln.stderr
                                      ? scheme.error
                                      : scheme.onSurface,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ),
            if (_ptyActive)
              TerminalKeysRow(onWriteBytes: (bytes) => _pty?.writeBytes(bytes)),
          ],
        ),
      ),
    );
  }
}

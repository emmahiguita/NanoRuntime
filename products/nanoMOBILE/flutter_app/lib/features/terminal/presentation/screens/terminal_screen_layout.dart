part of 'terminal_screen.dart';

/// Editor y salida comparten dueño; el teclado descuenta espacio una sola vez.
extension _TerminalLayout on _TerminalTabScreenState {
  Widget _buildTerminalLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardOpen = View.of(context).viewInsets.bottom > 0;
        final ownInset = MediaQuery.viewInsetsOf(context).bottom;
        final compact = constraints.maxHeight < 500;
        final box = TerminalViewBox(
          sessions: _sessions,
          activeIndex: _active,
          isSquareMode: _isSquareMode,
          fgColor: scheme.onSurface,
          isDark: scheme.brightness == Brightness.dark,
          engine: _engine,
          commandFocusNode: _commandFocusNode,
          commandController: _commandController,
          initialCommand: widget.initialCommand,
          directInput: _directInput,
          onTitleChanged: (index, title) {
            if (title != _sessions[index].name) {
              _update(() => _sessions[index].name = title);
            }
          },
        );
        return ColoredBox(
          color: scheme.surface,
          // El shell ya protege el borde superior; no duplicar su margen.
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: ownInset + (keyboardOpen ? 0 : 64),
              ),
              child: Column(
                children: [
                  TerminalTopBar(
                    sessions: _sessions,
                    activeIndex: _active,
                    isSquareMode: _isSquareMode,
                    chromeColor: scheme.surface,
                    fgColor: scheme.onSurface,
                    isDark: scheme.brightness == Brightness.dark,
                    onSelectTab: (index) => _update(() => _active = index),
                    onCloseTab: _closeTab,
                    onAddTab: _addNewTab,
                    onToggleSquare: () =>
                        _update(() => _isSquareMode = !_isSquareMode),
                  ),
                  Expanded(
                    child: _isSquareMode && !compact
                        ? Center(child: AspectRatio(aspectRatio: 1, child: box))
                        : box,
                  ),
                  TerminalCommandBar(
                    controller: _commandController,
                    focusNode: _commandFocusNode,
                    onSubmit: _submitTerminalCommand,
                    onInstallPackages: () => showTerminalPackageDialog(context),
                    directInput: _directInput,
                    onToggleDirect: () =>
                        _update(() => _directInput = !_directInput),
                    onOpenLibrary: () {
                      if (_sessions.isNotEmpty) {
                        (_sessions[_active].key.currentState
                                as NanoTerminalState?)
                            ?.openCommandLibrary();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Conserva bytes del comando. Enter y botón usan el mismo camino de ejecución.
  void _submitTerminalCommand(String text) {
    if (text.trim().isEmpty ||
        _sessions.isEmpty ||
        _active >= _sessions.length) {
      return;
    }
    final state = _sessions[_active].key.currentState as NanoTerminalState?;
    if (state == null) return;
    state.executeCommand(text);
    _commandController.clear();
    _commandFocusNode.requestFocus();
  }
}

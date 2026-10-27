part of 'terminal_core.dart';

/// Componente keyboard: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalKeyboard on _TerminalStateBase {
  /// Handler global de teclado (HardwareKeyboard).  En modo PTY interactivo cada keydown se convierte a bytes y se envía al terminal (vim/htop/python necesitan teclas individuales, no líneas con Enter). Fuera de PTY conserva Ctrl+L/C de la shell integrada.
  @override
  bool _onKey(KeyEvent e) {
    // Ninguna tecla de otra pantalla o pestaña se envía a este PTY.
    if (!_alive || !mounted || !widget.visible || !_fn.hasFocus) {
      _ctrl = false;
      return false;
    }
    if (e is! KeyDownEvent) {
      if (e is KeyUpEvent &&
          (e.logicalKey == LogicalKeyboardKey.controlLeft ||
              e.logicalKey == LogicalKeyboardKey.controlRight)) {
        _ctrl = false;
      }
      return false;
    }
    if (e.logicalKey == LogicalKeyboardKey.controlLeft ||
        e.logicalKey == LogicalKeyboardKey.controlRight) {
      _ctrl = true;
      return false;
    }
    // El editor conserva caracteres, mayúsculas y composición IME. El modo directo
    // queda disponible para programas interactivos con teclado físico.
    if (_ptyActive &&
        !widget.directInput &&
        !_ctrl &&
        !HardwareKeyboard.instance.isAltPressed)
      return false;
    if (_ptyActive) {
      if (_ctrl) {
        if (e.logicalKey == LogicalKeyboardKey.keyC) {
          _ctrl = false;
          // TER-11 v2: signal(2)=kill(-pid) NO mata en este device — sticky
          // Ctrl + "c" dejó el sleep 60 vivo (verificado por ps). Seccomp
          // ColorOS filtra kill desde la app (precedente shmget→SIGSYS).
          // El byte 0x03 por ISIG del kernel SÍ genera SIGINT al foreground
          // (probado: tecla Ctrl+C mató el sleep 30). Unificado al camino byte.
          _pty!.writeBytes([0x03]);
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyL) {
          _ctrl = false;
          _pty!.write('\x0c');
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyZ) {
          _ctrl = false;
          _pty!.write('\x1a');
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyD) {
          _ctrl = false;
          _pty!.write('\x04');
          return true;
        }
        final ch = const KeyboardMapper().logicalToChar(e.logicalKey);
        if (ch != null && ch >= 0x61 && ch <= 0x7a) {
          _pty!.writeBytes([ch - 0x60]);
          return true;
        }
        if (ch != null && ch >= 0x41 && ch <= 0x5a) {
          _pty!.writeBytes([ch - 0x40]);
          return true;
        }
        return false;
      }
      if (HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isControlPressed) {
        final bytes = const KeyboardMapper().keyToPtyBytes(
          e.logicalKey,
          ctrl: _ctrl,
        );
        if (bytes != null && bytes.length == 1 && bytes[0] >= 0x20) {
          _pty!.writeBytes([0x1b, bytes[0]]);
          return true;
        }
      }
      final bytes = const KeyboardMapper().keyToPtyBytes(
        e.logicalKey,
        ctrl: _ctrl,
      );
      if (bytes != null) _pty!.writeBytes(bytes);
      return bytes != null;
    }
    if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyL) {
      _controller.clear();
      _ctrl = false;
      return true;
    }
    if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyC) {
      _out('^C', Ln.stdout);
      _in.clear();
      _ctrl = false;
      return true;
    }
    return false;
  }
}

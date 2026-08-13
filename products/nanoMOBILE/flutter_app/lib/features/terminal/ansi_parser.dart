import 'dart:convert';

import 'term_screen.dart';

/// Máquina de estados ANSI/VT100: bytes → operaciones en [TermScreen].
///
/// Extraído de ansi_terminal.dart (SRP). Sin dependencias de Flutter —
/// solo opera sobre [TermScreen] vía métodos públicos.
class AnsiParser {
  final TermScreen screen;
  int _state = 0; // 0 texto, 1 esc, 2 csi, 3 osc, 4 charset
  final StringBuffer _csi = StringBuffer();
  final StringBuffer _osc = StringBuffer();
  void Function(String title)? onTitle; // OSC 0/2 callback
  /// Called when ?1004 focus-event mode is active and the terminal gains or
  /// loses focus. The owner should write \x1b[I (gained) or \x1b[O (lost)
  /// directly to the PTY. Null when focus events are disabled.
  void Function({required bool focused})? onFocusChange;
  /// Respuestas a queries del programa (DA \x1b[c, DSR \x1b[6n). El owner
  /// escribe este string directo al PTY. Null = se ignora la query.
  void Function(String data)? onResponse;
  /// OSC 52 (clipboard): texto deserializado de la secuencia Base64. El owner
  /// lo escribe al portapapeles. Null = se ignora.
  void Function(String text)? onClipboard;

  AnsiParser(this.screen);

  void reset() {
    _state = 0;
    _csi.clear();
    _osc.clear();
  }

  void consume(int ch) {
    switch (_state) {
      case 0:
        _text(ch);
        return;
      case 1:
        _esc(ch);
        return;
      case 2:
        _csiState(ch);
        return;
      case 3:
        if (ch == 0x07 || ch == 0x1b) {
          _handleOsc(_osc.toString());
          _osc.clear();
          _state = (ch == 0x1b) ? 1 : 0;
        } else if (ch >= 0x20 && _osc.length < 4096) {
          _osc.writeCharCode(ch);
        }
        return;
      default:
        _state = 0;
        return;
    }
  }

  void _text(int ch) {
    switch (ch) {
      case 0x1b:
        _state = 1;
        return;
      case 0x0d:
        screen.carriageReturn();
        return;
      case 0x0a:
      case 0x0b:
      case 0x0c:
        screen.newline();
        return;
      case 0x08:
        screen.backspace();
        return;
      // P3: DEL caía al default y dibujaba un glifo fantasma en el grid
      // (0x7F >= 0x20). Es control, jamás imprimible — VT100 clásico lo
      // trata como backspace (teclas con kbs=^?).
      case 0x7f:
        screen.backspace();
        return;
      case 0x09:
        screen.tab();
        return;
      case 0x07:
        return;
      default:
        if (ch >= 0x20) screen.put(ch);
    }
  }

  void _esc(int ch) {
    _state = 0;
    switch (ch) {
      case 0x5b:
        _state = 2;
        _csi.clear();
        return;
      case 0x5d:
        _state = 3;
        return;
      case 0x28:
      case 0x29:
      case 0x2a:
      case 0x2b:
        _state = 4;
        return;
      case 0x37:
        screen.saveCursor();
        return;
      case 0x38:
        screen.restoreCursor();
        return;
      case 0x63:
        screen.clearAll();
        return;
      case 0x4d:
        screen.scrollDown();
        return; // RI
      case 0x45:
        screen.carriageReturn();
        screen.newline();
        return; // NEL
      case 0x41:
        screen.moveRow(-1);
        return;
      case 0x42:
        screen.moveRow(1);
        return;
      case 0x43:
        screen.moveCol(1);
        return;
      case 0x44:
        screen.moveCol(-1);
        return;
      default:
        return;
    }
  }

  void _handleOsc(String osc) {
    final semi = osc.indexOf(';');
    if (semi < 0) return;
    final ps = int.tryParse(osc.substring(0, semi)) ?? -1;
    final pt = osc.substring(semi + 1);
    if ((ps == 0 || ps == 2) && pt.isNotEmpty) {
      onTitle?.call(pt);
    } else if (ps == 8) {
      // OSC 8 hyperlink: "params;url" o "url". URL vacía cierra el link.
      final semi2 = pt.indexOf(';');
      final url = semi2 >= 0 ? pt.substring(semi2 + 1) : pt;
      screen.setLink(url.isEmpty ? null : url);
    } else if (ps == 52) {
      // OSC 52 clipboard: "selector;base64". Solo selector "c" (portapapeles).
      final semi2 = pt.indexOf(';');
      if (semi2 >= 0) {
        final selector = pt.substring(0, semi2);
        final b64 = pt.substring(semi2 + 1);
        if (selector == 'c' && b64.isNotEmpty) {
          try {
            onClipboard?.call(utf8.decode(base64.decode(b64)));
          } catch (_) {
            // base64 inválida: ignorar silenciosamente.
          }
        }
      }
    }
  }

  void _csiState(int ch) {
    if (ch >= 0x40 && ch <= 0x7e) {
      _state = 0;
      _dispatch(ch, _csi.toString());
    } else if (_csi.length < 1024) {
      _csi.writeCharCode(ch);
    } else {
      _state = 0;
      _csi.clear();
    }
  }

  void _dispatch(int cmd, String raw) {
    final private = raw.startsWith('?');
    final p = _parseParams(raw);
    switch (cmd) {
      case 0x41:
        screen.moveRow(-_at(p, 0));
        break;
      case 0x42:
        screen.moveRow(_at(p, 0));
        break;
      case 0x43:
        screen.moveCol(_at(p, 0));
        break;
      case 0x44:
        screen.moveCol(-_at(p, 0));
        break;
      case 0x48:
      case 0x66:
        _place(p);
        break;
      case 0x4a:
        final m = _at(p, 0) % 3;
        if (m == 2) {
          screen.clearAll();
        } else if (m == 1) {
          screen.clearAbove();
        } else {
          screen.clearBelow();
        }
        break;
      case 0x4b:
        screen.clearLine(_at(p, 0) % 4);
        break;
      case 0x6d:
        _sgr(p);
        break;
      case 0x40:
        screen.insertChars(_at(p, 0));
        break;
      case 0x50:
        screen.deleteChars(_at(p, 0));
        break;
      case 0x58:
        screen.eraseChars(_at(p, 0));
        break;
      case 0x4c:
        screen.insertLines(_at(p, 0));
        break;
      case 0x4d:
        screen.deleteLines(_at(p, 0));
        break;
      case 0x68:
      case 0x6c:
        _decMode(cmd == 0x68, private: private, p: p);
        break;
      case 0x72: // DECSTBM: margen de scroll (vim/tmux)
        if (p.isEmpty || (p.length == 1 && p[0] == 0)) {
          screen.resetScrollRegion();
        } else {
          final top = _at(p, 0);
          final bottom = p.length > 1 && p[1] > 0 ? p[1] : screen.rows;
          screen.setScrollRegion(top, bottom);
        }
        break;
      case 0x63: // DA: reportar atributos del dispositivo
        onResponse?.call('\x1b[?1;2c');
        break;
      case 0x6e: // DSR: reportar posición del cursor (solo 6n)
        if (_at(p, 0) == 6) {
          onResponse
              ?.call('\x1b[${screen.cursorRow + 1};${screen.cursorCol + 1}R');
        }
        break;
      default:
        break;
    }
  }

  void _place(List<int> p) {
    if (p.isEmpty || (p.length == 1 && p[0] == 0)) {
      screen.setCursor(0, 0);
      return;
    }
    final r = _at(p, 0) - 1;
    final c = (p.length > 1 && p[1] > 0) ? p[1] - 1 : 0;
    screen.setCursor(r, c);
  }

  void _decMode(bool set, {required bool private, required List<int> p}) {
    if (!private || p.isEmpty) return;
    switch (p[0]) {
      case 1049:
      case 1047:
      case 47:
        if (set) {
          screen.enterAlt();
        } else {
          screen.leaveAlt();
        }
        break;
      case 25:
        screen.setCursorVisible(set);
        break;
      case 1000:
      case 1002:
      case 1003:
        screen.mouseEnabled = set;
        break;
      // Bracketed Paste Mode: when enabled the remote program expects paste
      // content wrapped in \x1b[200~ ... \x1b[201~. The modifier bar must
      // check screen.bracketedPasteMode before wrapping clipboard text.
      case 2004:
        screen.bracketedPasteMode = set;
        break;
      // Focus Event Reporting: when enabled, send \x1b[I on focus-in and
      // \x1b[O on focus-out. The owner wires up onFocusChange to handle this.
      case 1004:
        screen.focusEventsMode = set;
        break;
      default:
        break;
    }
  }

  /// Precompilados: _parseParams corre por cada secuencia CSI del stream.
  /// Compilar dos RegExp por invocación era un cuello de botella real en
  /// redraws densos (htop/vim/`ls --color`) — el compilador de regex hacía
  /// backtracking en cada cursor-move/SGR/clear.
  static final RegExp _numEnd = RegExp(r'[0-9]+\z');
  static final RegExp _numAny = RegExp(r'[0-9]+');

  List<int> _parseParams(String s) {
    if (s.isEmpty) return const [0];
    final out = <int>[];
    for (final part in s.split(';')) {
      final clean = part.replaceAll('?', '');
      final m = _numEnd.firstMatch(clean) ?? _numAny.firstMatch(clean);
      out.add(m == null ? 0 : (int.tryParse(m.group(0)!) ?? 0));
    }
    return out;
  }

  int _at(List<int> p, int i) => (i < p.length && p[i] > 0) ? p[i] : 1;

  void _sgr(List<int> p) {
    if (p.isEmpty) {
      screen.sgrReset();
      return;
    }
    var i = 0;
    while (i < p.length) {
      final v = p[i];
      switch (v) {
        case 0:
          screen.sgrReset();
          break;
        case 1:
          screen.sgrBoldOn();
          break;
        case 2:
          screen.sgrDimOn();
          break;
        case 22:
          screen.sgrWeightOff();
          break;
        case 7:
          screen.sgrReverseOn();
          break;
        case 27:
          screen.sgrReverseOff();
          break;
        case 3:
          screen.sgrItalicOn();
          break;
        case 23:
          screen.sgrItalicOff();
          break;
        case 4:
          screen.sgrUnderlineOn();
          break;
        case 24:
          screen.sgrUnderlineOff();
          break;
        case 5:
          screen.sgrBlinkOn();
          break;
        case 25:
          screen.sgrBlinkOff();
          break;
        case 9:
          screen.sgrStrikeOn();
          break;
        case 29:
          screen.sgrStrikeOff();
          break;
        case 53:
          screen.sgrOverlineOn();
          break;
        case 55:
          screen.sgrOverlineOff();
          break;
        case 39:
          screen.sgrFg(255);
          break;
        case 49:
          screen.sgrBg(256);
          break;
        case 38:
          if (i + 2 < p.length && p[i + 1] == 5) {
            screen.sgrFg(p[i + 2]);
            i += 2;
          } else if (i + 4 < p.length && p[i + 1] == 2) {
            screen.sgrFgRgb(
                (p[i + 2] << 16) | (p[i + 3] << 8) | p[i + 4]);
            i += 4;
          }
          break;
        case 48:
          if (i + 2 < p.length && p[i + 1] == 5) {
            screen.sgrBg(p[i + 2]);
            i += 2;
          } else if (i + 4 < p.length && p[i + 1] == 2) {
            screen.sgrBgRgb(
                (p[i + 2] << 16) | (p[i + 3] << 8) | p[i + 4]);
            i += 4;
          }
          break;
        default:
          if (v >= 30 && v <= 37) {
            screen.sgrFg(v - 30);
          } else if (v >= 40 && v <= 47) {
            screen.sgrBg(v - 40);
          } else if (v >= 90 && v <= 97) {
            screen.sgrFg(8 + (v - 90));
          } else if (v >= 100 && v <= 107) {
            screen.sgrBg(8 + (v - 100));
          }
      }
      i++;
    }
  }
}

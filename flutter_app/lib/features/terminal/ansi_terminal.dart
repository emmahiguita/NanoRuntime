import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ============================================================================
// PALETA xterm 256 (16 base + 6x6x6 cube + 24 grises)
// ============================================================================
const List<int> _base16 = <int>[
  0x000000, 0xCD0000, 0x00CD00, 0xCDCD00,
  0x0000EE, 0xCD00CD, 0x00CDCD, 0xE5E5E5,
  0x7F7F7F, 0xFF0000, 0x00FF00, 0xFFFF00,
  0x5C5CFF, 0xFF00FF, 0x00FFFF, 0xFFFFFF,
];

final List<Color> _palette256 = _buildPalette();

List<Color> _buildPalette() {
  final out = <Color>[];
  for (var i = 0; i < 16; i++) out.add(Color(_base16[i]));
  const levels = [0, 95, 135, 175, 215, 255];
  for (final r in levels) {
    for (final g in levels) {
      for (final b in levels) {
        out.add(Color.fromARGB(255, r, g, b));
      }
    }
  }
  for (var g = 0; g < 24; g++) {
    final v = 8 + g * 10;
    out.add(Color.fromARGB(255, v, v, v));
  }
  return out;
}

/// 255 = foreground por defecto (tema), 256 = fondo transparente.
Color _rfg(int idx, Color def) =>
    idx == 255 ? def : _palette256[idx >= 0 && idx < 256 ? idx : 255];
Color? _rbg(int idx) => idx == 256 ? null : _palette256[idx & 0xFF];

// ============================================================================
// 1. MODELO â€” celda + pantalla (screen buffer). SRP: solo estado de imagen.
// ============================================================================
class TermCell {
  int ch = 0;
  int fg = 255;
  int bg = 256;
  bool bold = false;
  bool dim = false;
  bool reverse = false;
  int? fgRgb;
  int? bgRgb;
  bool wide = false; // double-width char (CJK, emoji)

  void reset() {
    ch = 0; fg = 255; bg = 256; bold = false; dim = false; reverse = false;
    fgRgb = null; bgRgb = null; wide = false;
  }
}

class TermScreen {
  int rows;
  int cols;
  late List<List<TermCell>> _main;
  List<List<TermCell>>? _alt;

  /// Scrollback: filas que salen del viewport al hacer scroll (historial).
  final List<List<TermCell>> _history = [];
  static const int maxHistory = 2000;

  int _row = 0, _col = 0;
  int _saveR = 0, _saveC = 0;
  int _fg = 255, _bg = 256;
  int? _fgRgb, _bgRgb; // truecolor overrides
  bool _bold = false, _dim = false, _reverse = false;
  bool _cursorVisible = true; // DECSET/DECRST 25
  bool _mouseEnabled = false;  // DECSET/DECRST 1000

  TermScreen({this.rows = 24, this.cols = 80}) {
    _main = List.generate(rows, (_) => _blankRow());
  }

  List<TermCell> _blankRow() => List.generate(cols, (_) => TermCell());
  List<List<TermCell>> get _cellList => _alt ?? _main;

  // lectura / render
  TermCell getCell(int r, int c) => _cellList[r][c];
  int get cursorRow => _row;
  int get cursorCol => _col;
  bool get inAltScreen => _alt != null;
  bool get cursorVisible => _cursorVisible;
  void setCursorVisible(bool v) => _cursorVisible = v;
  bool get mouseEnabled => _mouseEnabled;
  set mouseEnabled(bool v) => _mouseEnabled = v;

  /// Filas del scrollback (historial arriba del viewport).
  List<TermCell> historyRow(int i) => _history[i];
  int get historyLength => _history.length;
  void clearHistory() => _history.clear();

  /// Redimensiona conservando contenido actual visible.
  void resize(int r, int c) {
    rows = r.clamp(1, 200);
    cols = c.clamp(1, 300);
    final old = _main;
    final src = _alt ?? old;
    _main = List.generate(rows, (_) => _blankRow());
    for (var rr = 0; rr < rows && rr < src.length; rr++) {
      for (var cc = 0; cc < cols && cc < src[rr].length; cc++) {
        _main[rr][cc] = src[rr][cc];
      }
    }
    _alt = null;
    _row = _row.clamp(0, rows - 1);
    _col = _col.clamp(0, cols - 1);
  }

  // controles bÃ¡sicos
  void put(int ch) {
    if (_row >= rows || _col >= cols) return;
    final wide = _isWideChar(ch);
    // Wide char at last column: wrap to next line
    if (wide && _col >= cols - 1) { _col = 0; newline(); if (_row >= rows) return; }
    final cell = _cellList[_row][_col];
    cell.ch = ch; cell.fg = _fg; cell.bg = _bg;
    cell.fgRgb = _fgRgb; cell.bgRgb = _bgRgb;
    cell.bold = _bold; cell.dim = _dim; cell.reverse = _reverse;
    cell.wide = wide;
    _col++;
    if (wide && _col < cols) {
      // Marcar siguiente celda como continuation (zero-width)
      final next = _cellList[_row][_col];
      next.ch = 0; next.fg = _fg; next.bg = _bg;
      next.fgRgb = _fgRgb; next.bgRgb = _bgRgb;
      next.bold = false; next.dim = false; next.reverse = false;
      next.wide = false; // continuation, not wide itself
      _col++;
    }
    if (_col >= cols) { _col = 0; newline(); }
  }

  /// Unicode East Asian Width: caracteres que ocupan 2 celdas (CJK, emoji, etc.)
  static bool _isWideChar(int cp) {
    // CJK Unified Ideographs + Extensions
    if (cp >= 0x4E00 && cp <= 0x9FFF) return true;
    if (cp >= 0x3400 && cp <= 0x4DBF) return true; // Ext A
    if (cp >= 0x20000 && cp <= 0x2A6DF) return true; // Ext B
    // CJK Compatibility
    if (cp >= 0xF900 && cp <= 0xFAFF) return true;
    if (cp >= 0x2F800 && cp <= 0x2FA1F) return true;
    // Fullwidth forms
    if (cp >= 0xFF01 && cp <= 0xFF60) return true;
    if (cp >= 0xFFE0 && cp <= 0xFFE6) return true;
    // Hangul Syllables
    if (cp >= 0xAC00 && cp <= 0xD7AF) return true;
    // Katakana/Hiragana (some are wide in terminal context)
    if (cp >= 0x3040 && cp <= 0x309F) return false; // Hiragana = narrow
    if (cp >= 0x30A0 && cp <= 0x30FF) return true; // Katakana = wide
    // Emoji & symbols (U+1F000-U+1FFFF, U+2600-U+27BF, U+2300-U+23FF)
    if (cp >= 0x1F000 && cp <= 0x1FFFF) return true;
    if (cp >= 0x2600 && cp <= 0x27BF) return true;
    if (cp >= 0x2300 && cp <= 0x23FF) return true;
    // Chinese/Japanese brackets & punctuation
    if (cp >= 0x3000 && cp <= 0x303F) return true; // CJK Symbols
    return false;
  }

  void newline() {
    if (_row + 1 >= rows) scrollUp();
    else _row++;
  }

  void carriageReturn() => _col = 0;
  void backspace() {
    if (_col <= 0) return;
    _col--;
    // Si la celda anterior era wide, retroceder una más
    if (_col > 0 && _cellList[_row][_col].wide) _col--;
  }
  void tab() => _col = math.min(cols - 1, ((_col ~/ 8) + 1) * 8);
  void indexUp() { if (_row > 0) _row--; }
  void indexLineLF() => newline(); // NEL

  void moveRow(int d) => _row = (_row + d).clamp(0, rows - 1);
  void moveCol(int d) {
    _col = (_col + d).clamp(0, cols - 1);
    _snapFromContinuation();
  }

  /// Si el cursor está en una celda de continuación (ch=0 post-wide),
  /// retrocede a la celda wide real. Solo aplica si la celda anterior es wide.
  void _snapFromContinuation() {
    if (_col > 0 && _col < cols) {
      final c = _cellList[_row][_col];
      final prev = _cellList[_row][_col - 1];
      if (c.ch == 0 && !c.wide && prev.wide) _col--;
    }
  }
  void setCursor(int r, int c) {
    _row = r.clamp(0, rows - 1);
    _col = c.clamp(0, cols - 1);
    _snapFromContinuation();
  }
  void saveCursor() { _saveR = _row; _saveC = _col; }
  void restoreCursor() { _row = _saveR; _col = _saveC; _snapFromContinuation(); }

  // borrado
  void clearAll() {
    _cellList.forEach((l) => l.forEach((c) => c.reset()));
    _row = 0; _col = 0;
    clearHistory();
  }
  void clearBelow() {
    for (var c = _col; c < cols; c++) _cellList[_row][c].reset();
    for (var r = _row + 1; r < rows; r++)
      for (var c = 0; c < cols; c++) _cellList[r][c].reset();
  }
  void clearAbove() {
    for (var r = 0; r <= _row; r++)
      for (var c = 0; c < cols; c++) _cellList[r][c].reset();
  }
  void clearLine(int mode) {
    if (_row >= rows) return;
    final l = _cellList[_row];
    if (mode == 0) { for (var c = _col; c < cols; c++) l[c].reset(); }
    else if (mode == 1) { for (var c = 0; c <= _col; c++) l[c].reset(); }
    else { for (var c = 0; c < cols; c++) l[c].reset(); }
  }

  // insertar / borrar
  void insertChars(int n) {
    final m = math.min(n, cols - _col);
    if (m <= 0) return;
    for (var c = cols - 1; c >= _col + m; c--) _cellList[_row][c] = _cellList[_row][c - m];
    for (var c = _col; c < _col + m; c++) _cellList[_row][c] = TermCell();
  }
  void deleteChars(int n) {
    final m = math.min(n, cols - _col);
    if (m <= 0) return;
    for (var c = _col; c < cols - m; c++) _cellList[_row][c] = _cellList[_row][c + m];
    for (var c = cols - m; c < cols; c++) _cellList[_row][c] = TermCell();
  }
  void eraseChars(int n) {
    final m = math.min(n, cols - _col);
    for (var c = _col; c < _col + m; c++) _cellList[_row][c] = TermCell();
  }
  void insertLines(int n) {
    final m = math.min(n, rows - _row);
    for (var rr = rows - 1; rr >= _row + m; rr--) _cellList[rr] = _cellList[rr - m];
    for (var rr = _row; rr < _row + m; rr++) _cellList[rr] = _blankRow();
  }
  void deleteLines(int n) {
    final m = math.min(n, rows - _row);
    if (m <= 0) return;
    for (var rr = _row; rr < rows - m; rr++) _cellList[rr] = _cellList[rr + m];
    for (var rr = rows - m; rr < rows; rr++) _cellList[rr] = _blankRow();
  }
  void scrollUp() {
    // La fila que sale del viewport va al scrollback (solo pantalla
    // principal; en pantalla alterna de vim/htop no hay historial).
    if (_alt == null) {
      _history.add(List.of(_cellList[0]));
      if (_history.length > maxHistory) _history.removeAt(0);
    }
    for (var r = 0; r < rows - 1; r++) _cellList[r] = _cellList[r + 1];
    _cellList[rows - 1] = _blankRow();
    if (_row > 0) _row--;
  }
  void scrollDown() {
    for (var r = rows - 1; r > 0; r--) _cellList[r] = _cellList[r - 1];
    _cellList[0] = _blankRow();
  }

  // pantalla alterna
  void enterAlt() {
    if (_alt != null) return;
    _saveR = _row; _saveC = _col;
    _alt = List.generate(rows, (_) => _blankRow());
    _row = 0; _col = 0;
  }
  void leaveAlt() {
    if (_alt == null) return;
    _alt = null;
    _row = _saveR; _col = _saveC;
  }

  // SGR
  void sgrReset() { _fg = 255; _bg = 256; _fgRgb = null; _bgRgb = null; _bold = _dim = _reverse = false; }
  void sgrFg(int v) => _fg = v;
  void sgrBg(int v) => _bg = v;
  void sgrFgRgb(int rgb) { _fgRgb = rgb; _fg = 255; }
  void sgrBgRgb(int rgb) { _bgRgb = rgb; _bg = 256; }
  void sgrBoldOn() { _bold = true; _dim = false; }
  void sgrDimOn() { _dim = true; _bold = false; }
  void sgrWeightOff() { _bold = false; _dim = false; }
  void sgrReverseOn() => _reverse = true;
  void sgrReverseOff() => _reverse = false;
}

// ============================================================================
// 2. PARSER â€” mÃ¡quina de estados. SRP: bytes â†’ ops en TermScreen.
// ============================================================================
class AnsiParser {
  final TermScreen screen;
  int _state = 0; // 0 texto, 1 esc, 2 csi, 3 osc, 4 charset
  final StringBuffer _csi = StringBuffer();
  final StringBuffer _osc = StringBuffer();
  void Function(String title)? onTitle; // OSC 0/2 callback

  AnsiParser(this.screen);

  void reset() { _state = 0; _csi.clear(); _osc.clear(); }

  void consume(int ch) {
    switch (_state) {
      case 0: _text(ch); return;
      case 1: _esc(ch); return;
      case 2: _csiState(ch); return;
      case 3:
        if (ch == 0x07 || ch == 0x1b) {
          _handleOsc(_osc.toString()); _osc.clear(); _state = (ch == 0x1b) ? 1 : 0;
        } else if (ch >= 0x20) {
          _osc.writeCharCode(ch);
        }
        return;
      default: _state = 0; return;
    }
  }

  void _text(int ch) {
    switch (ch) {
      case 0x1b: _state = 1; return;
      case 0x0d: screen.carriageReturn(); return;
      case 0x0a: case 0x0b: case 0x0c: screen.newline(); return;
      case 0x08: screen.backspace(); return;
      case 0x09: screen.tab(); return;
      case 0x07: return;
      default: if (ch >= 0x20) screen.put(ch);
    }
  }

  void _esc(int ch) {
    _state = 0;
    switch (ch) {
      case 0x5b: _state = 2; _csi.clear(); return;
      case 0x5d: _state = 3; return;
      case 0x28: case 0x29: case 0x2a: case 0x2b: _state = 4; return;
      case 0x37: screen.saveCursor(); return;
      case 0x38: screen.restoreCursor(); return;
      case 0x63: screen.clearAll(); return;
      case 0x4d: screen.scrollDown(); return; // RI
      case 0x45: screen.carriageReturn(); screen.newline(); return; // NEL
      case 0x41: screen.moveRow(-1); return;
      case 0x42: screen.moveRow(1); return;
      case 0x43: screen.moveCol(1); return;
      case 0x44: screen.moveCol(-1); return;
      default: return;
    }
  }

  void _handleOsc(String osc) {
    // OSC Ps ; Pt BEL | ST
    // Ps=0,2: set window/icon title
    final semi = osc.indexOf(';');
    if (semi < 0) return;
    final ps = int.tryParse(osc.substring(0, semi)) ?? -1;
    final pt = osc.substring(semi + 1);
    if ((ps == 0 || ps == 2) && pt.isNotEmpty) {
      onTitle?.call(pt);
    }
  }

  void _csiState(int ch) {
    if (ch >= 0x40 && ch <= 0x7e) {
      _state = 0;
      _dispatch(ch, _csi.toString());
    } else {
      _csi.writeCharCode(ch);
    }
  }

  void _dispatch(int cmd, String raw) {
    final private = raw.startsWith('?');
    final p = _parseParams(raw);
    switch (cmd) {
      case 0x41: screen.moveRow(-_at(p, 0)); break;
      case 0x42: screen.moveRow(_at(p, 0)); break;
      case 0x43: screen.moveCol(_at(p, 0)); break;
      case 0x44: screen.moveCol(-_at(p, 0)); break;
      case 0x48: case 0x66: _place(p); break;
      case 0x4a:
        // ED: modo en p[0] (0=abajo, 1=arriba, 2/3=todo). _at usa índice 0.
        final m = _at(p, 0) % 3;
        if (m == 2) screen.clearAll();
        else if (m == 1) screen.clearAbove();
        else screen.clearBelow();
        break;
      case 0x4b: screen.clearLine(_at(p, 0) % 4); break;
      case 0x6d: _sgr(p); break;
      case 0x40: screen.insertChars(_at(p, 0)); break;
      case 0x50: screen.deleteChars(_at(p, 0)); break;
      case 0x58: screen.eraseChars(_at(p, 0)); break;
      case 0x4c: screen.insertLines(_at(p, 0)); break;
      case 0x4d: screen.deleteLines(_at(p, 0)); break;
      case 0x68: case 0x6c: _decMode(cmd == 0x68, private: private, p: p); break;
      default: break;
    }
  }

  void _place(List<int> p) {
    if (p.isEmpty || (p.length == 1 && p[0] == 0)) { screen.setCursor(0, 0); return; }
    final r = _at(p, 0) - 1;
    final c = (p.length > 1 && p[1] > 0) ? p[1] - 1 : 0;
    screen.setCursor(r, c);
  }

  void _decMode(bool set, {required bool private, required List<int> p}) {
    if (!private || p.isEmpty) return;
    switch (p[0]) {
      case 1049: case 1047: case 47:
        if (set) screen.enterAlt(); else screen.leaveAlt();
        break;
      case 25: // DECTCEM: mostrar/ocultar cursor
        screen.setCursorVisible(set);
        break;
      case 1000: case 1002: case 1003: // Mouse tracking
        screen.mouseEnabled = set;
        break;
      default: break;
    }
  }

  List<int> _parseParams(String s) {
    if (s.isEmpty) return const [0];
    final out = <int>[];
    for (final part in s.split(';')) {
      final clean = part.replaceAll('?', '');
      final m = RegExp(r'[0-9]+\z').firstMatch(clean) ??
          RegExp(r'[0-9]+').firstMatch(clean);
      out.add(m == null ? 0 : (int.tryParse(m.group(0)!) ?? 0));
    }
    return out;
  }

  int _at(List<int> p, int i) => (i < p.length && p[i] > 0) ? p[i] : 1;

  void _sgr(List<int> p) {
    if (p.isEmpty) { screen.sgrReset(); return; }
    var i = 0;
    while (i < p.length) {
      final v = p[i];
      switch (v) {
        case 0: screen.sgrReset(); break;
        case 1: screen.sgrBoldOn(); break;
        case 2: screen.sgrDimOn(); break;
        case 22: screen.sgrWeightOff(); break;
        case 7: screen.sgrReverseOn(); break;
        case 27: screen.sgrReverseOff(); break;
        case 39: screen.sgrFg(255); break;
        case 49: screen.sgrBg(256); break;
        case 38:
          if (i + 2 < p.length && p[i + 1] == 5) { screen.sgrFg(p[i + 2]); i += 2; }
          else if (i + 4 < p.length && p[i + 1] == 2) { screen.sgrFgRgb((p[i + 2] << 16) | (p[i + 3] << 8) | p[i + 4]); i += 4; }
          break;
        case 48:
          if (i + 2 < p.length && p[i + 1] == 5) { screen.sgrBg(p[i + 2]); i += 2; }
          else if (i + 4 < p.length && p[i + 1] == 2) { screen.sgrBgRgb((p[i + 2] << 16) | (p[i + 3] << 8) | p[i + 4]); i += 4; }
          break;
        default:
          if (v >= 30 && v <= 37) screen.sgrFg(v - 30);
          else if (v >= 40 && v <= 47) screen.sgrBg(v - 40);
          else if (v >= 90 && v <= 97) screen.sgrFg(8 + (v - 90));
          else if (v >= 100 && v <= 107) screen.sgrBg(8 + (v - 100));
      }
      i++;
    }
  }
}

// ============================================================================
// 3. FACADE â€” AnsiTerminal: screen + parser; API del consumidor + notificaciÃ³n.
// ============================================================================
class AnsiTerminal extends ChangeNotifier {
  final TermScreen screen;
  late final AnsiParser _parser;
  int rows, cols;
  String _title = '';
  String get title => _title;

  AnsiTerminal({int rows = 24, int cols = 80})
      : rows = rows,
        cols = cols,
        screen = TermScreen(rows: rows, cols: cols) {
    _parser = AnsiParser(screen);
    _parser.onTitle = (t) { _title = t; notifyListeners(); };
  }

  int get cursorRow => screen.cursorRow;
  int get cursorCol => screen.cursorCol;
  bool get inAltScreen => screen.inAltScreen;
  bool get cursorVisible => screen.cursorVisible;
  bool get mouseEnabled => screen.mouseEnabled;
  int get historyLength => screen.historyLength;
  TermCell getCell(int r, int c) => screen.getCell(r, c);
  List<TermCell> row(int r) =>
      List.generate(cols, (c) => screen.getCell(r, c));
  List<TermCell> historyRow(int i) => screen.historyRow(i);
  void clearHistory() => screen.clearHistory();

  void reset({int? rows, int? cols}) {
    screen.resize(rows ?? this.rows, cols ?? this.cols);
    this.rows = screen.rows;
    this.cols = screen.cols;
    _parser.reset();
    notifyListeners();
  }

  void feed(String text) {
    for (var i = 0; i < text.length; i++) _parser.consume(text.codeUnitAt(i));
    notifyListeners();
  }

  void feedBytes(Uint8List data) {
    feed(utf8.decode(data, allowMalformed: true));
  }
}

// ============================================================================
// 4. RENDER — widget que dibuja el grid como RichText. SRP: solo visual.
//    StatefulWidget: parpadeo del cursor (Timer) + auto-scroll al fondo.
// ============================================================================
class AnsiTerminalView extends StatefulWidget {
  final AnsiTerminal terminal;
  const AnsiTerminalView(this.terminal, {super.key});

  @override
  State<AnsiTerminalView> createState() => _AnsiTerminalViewState();
}

class _AnsiTerminalViewState extends State<AnsiTerminalView> {
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
    // Parpadeo del cursor (~1Hz, como un terminal real).
    _blink = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _cursorOn = !_cursorOn);
    });
    // Cuando el buffer cambia (feed), si estábamos en el fondo, seguirlo.
    _term.addListener(_onBufferChange);
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
    _blink?.cancel();
    _term.removeListener(_onBufferChange);
    _sc?.dispose();
    super.dispose();
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
          itemExtent: 20,
          itemBuilder: (context, i) {
            if (i < hist) {
              return RepaintBoundary(
                child: _TermLine(
                  cells: _term.historyRow(i),
                  baseStyle: mono,
                  defFg: defFg,
                ),
              );
            }
            final r = i - hist;
            final isCursorRow = r == _term.cursorRow;
            final cursorCol = showCursor && isCursorRow ? _term.cursorCol : null;
            return RepaintBoundary(
              child: _TermLine(
                cells: _term.row(r),
                baseStyle: mono,
                defFg: defFg,
                cursorCol: cursorCol,
              ),
            );
          },
        );
      },
    );
  }
}

class _TermLine extends StatelessWidget {
  final List<TermCell> cells;
  final TextStyle baseStyle;
  final Color defFg;
  final int? cursorCol;
  const _TermLine({
    required this.cells,
    required this.baseStyle,
    required this.defFg,
    this.cursorCol,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var start = 0;
    final n = cells.length;

    while (start < n) {
      final ref = cells[start];
      var end = start + 1;
      while (end < n && _same(ref, cells[end])) end++;

      // El cursor corta el run en su columna (block cursor).
      if (cursorCol != null && cursorCol! >= start && cursorCol! < end) {
        _pushSpan(spans, cells, start, cursorCol!, baseStyle, defFg);
        _pushCursor(spans, cells[cursorCol!], baseStyle, defFg);
        start = cursorCol! + 1;
        continue;
      }

      _pushSpan(spans, cells, start, end, baseStyle, defFg);
      start = end;
    }

    return SizedBox(
      height: 20,
      child: Text.rich(
        TextSpan(children: spans),
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }

  void _pushSpan(List<InlineSpan> out, List<TermCell> cells, int a, int b,
      TextStyle base, Color defFg) {
    if (b <= a) return;
    final ref = cells[a];
    final run = StringBuffer();
    var lastWide = false;
    for (var i = a; i < b; i++) {
      final c = cells[i];
      if (c.ch == 0 && !c.wide && lastWide) { lastWide = false; continue; }
      lastWide = c.wide;
      run.writeCharCode(c.ch == 0 ? 0x20 : c.ch);
    }
    Color fg = ref.fgRgb != null ? Color(0xFF000000 | ref.fgRgb!) : _rfg(ref.fg, defFg);
    Color? bg = ref.bgRgb != null ? Color(0xFF000000 | ref.bgRgb!) : _rbg(ref.bg);
    var style = base.copyWith(
      color: ref.dim ? fg.withValues(alpha: 0.6) : fg,
      fontWeight: ref.bold ? FontWeight.bold : FontWeight.normal,
    );
    if (ref.reverse) {
      style = style.copyWith(
        color: bg ?? defFg,
        backgroundColor: fg,
      );
    } else if (bg != null) {
      style = style.copyWith(backgroundColor: bg);
    }
    out.add(TextSpan(text: run.toString(), style: style));
  }

  /// Block cursor: celda invertida (fondo = fg del terminal, texto oscuro).
  void _pushCursor(List<InlineSpan> out, TermCell cell, TextStyle base,
      Color defFg) {
    Color fg = _rfg(cell.fg, defFg);
    final textColor = _rbg(cell.bg) ?? const Color(0xFF0A0F1A);
    out.add(TextSpan(
      text: String.fromCharCode(cell.ch == 0 ? 0x20 : cell.ch),
      style: base.copyWith(
        color: textColor,
        backgroundColor: fg,
        fontWeight: FontWeight.bold,
      ),
    ));
  }

  bool _same(TermCell a, TermCell b) =>
      a.fg == b.fg && a.bg == b.bg && a.bold == b.bold &&
      a.dim == b.dim && a.reverse == b.reverse &&
      a.wide == b.wide && a.fgRgb == b.fgRgb && a.bgRgb == b.bgRgb;
}
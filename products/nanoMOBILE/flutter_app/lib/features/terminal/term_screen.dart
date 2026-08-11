import 'dart:math' as math;

/// Celda individual del buffer de terminal.
///
/// Extraído de ansi_terminal.dart (SRP). Modelo puro sin dependencias
/// de Flutter — solo datos e inmutabilidad vía clone().
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
    ch = 0;
    fg = 255;
    bg = 256;
    bold = false;
    dim = false;
    reverse = false;
    fgRgb = null;
    bgRgb = null;
    wide = false;
  }

  /// Deep copy: crea una celda independiente con los mismos atributos.
  /// Necesario para scrollUp/insertLines/deleteLines: las filas se mueven
  /// por referencia y sin deep copy comparten objetos TermCell mutables,
  /// causando corrupción visual entre filas y en el scrollback.
  TermCell clone() {
    return TermCell()
      ..ch = ch
      ..fg = fg
      ..bg = bg
      ..bold = bold
      ..dim = dim
      ..reverse = reverse
      ..fgRgb = fgRgb
      ..bgRgb = bgRgb
      ..wide = wide;
  }
}

/// Buffer de pantalla del terminal: grid de [TermCell], cursor, scrollback.
///
/// SRP: solo estado de imagen. El parser (AnsiParser) muta este estado;
/// el renderer (AnsiTerminalView) lo lee.
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
  bool mouseEnabled = false; // DECSET/DECRST 1000

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

  // controles básicos
  void put(int ch) {
    if (_row >= rows || _col >= cols) return;
    final wide = _isWideChar(ch);
    if (wide && _col >= cols - 1) {
      _col = 0;
      newline();
      if (_row >= rows) return;
    }
    final cell = _cellList[_row][_col];
    cell.ch = ch;
    cell.fg = _fg;
    cell.bg = _bg;
    cell.fgRgb = _fgRgb;
    cell.bgRgb = _bgRgb;
    cell.bold = _bold;
    cell.dim = _dim;
    cell.reverse = _reverse;
    cell.wide = wide;
    _col++;
    if (wide && _col < cols) {
      final next = _cellList[_row][_col];
      next.ch = 0;
      next.fg = _fg;
      next.bg = _bg;
      next.fgRgb = _fgRgb;
      next.bgRgb = _bgRgb;
      next.bold = false;
      next.dim = false;
      next.reverse = false;
      next.wide = false;
      _col++;
    }
    if (_col >= cols) {
      _col = 0;
      newline();
    }
  }

  /// Unicode East Asian Width: caracteres que ocupan 2 celdas (CJK, emoji, etc.)
  static bool _isWideChar(int cp) {
    if (cp >= 0x4E00 && cp <= 0x9FFF) return true;
    if (cp >= 0x3400 && cp <= 0x4DBF) return true;
    if (cp >= 0x20000 && cp <= 0x2A6DF) return true;
    if (cp >= 0xF900 && cp <= 0xFAFF) return true;
    if (cp >= 0x2F800 && cp <= 0x2FA1F) return true;
    if (cp >= 0xFF01 && cp <= 0xFF60) return true;
    if (cp >= 0xFFE0 && cp <= 0xFFE6) return true;
    if (cp >= 0xAC00 && cp <= 0xD7AF) return true;
    if (cp >= 0x3040 && cp <= 0x309F) return false;
    if (cp >= 0x30A0 && cp <= 0x30FF) return true;
    if (cp >= 0x1F000 && cp <= 0x1FFFF) return true;
    if (cp >= 0x2600 && cp <= 0x27BF) return true;
    if (cp >= 0x2300 && cp <= 0x23FF) return true;
    if (cp >= 0x3000 && cp <= 0x303F) return true;
    return false;
  }

  void newline() {
    if (_row + 1 >= rows) {
      scrollUp();
    } else {
      _row++;
    }
  }

  void carriageReturn() => _col = 0;
  void backspace() {
    if (_col <= 0) return;
    _col--;
    if (_col > 0 && _cellList[_row][_col].wide) _col--;
  }
  void tab() => _col = math.min(cols - 1, ((_col ~/ 8) + 1) * 8);
  void indexUp() {
    if (_row > 0) _row--;
  }
  void indexLineLF() => newline();

  void moveRow(int d) => _row = (_row + d).clamp(0, rows - 1);
  void moveCol(int d) {
    _col = (_col + d).clamp(0, cols - 1);
    _snapFromContinuation();
  }

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
  void saveCursor() {
    _saveR = _row;
    _saveC = _col;
  }
  void restoreCursor() {
    _row = _saveR;
    _col = _saveC;
    _snapFromContinuation();
  }

  // borrado
  void clearAll() {
    for (var l in _cellList) {
      for (var c in l) {
        c.reset();
      }
    }
    _row = 0;
    _col = 0;
    clearHistory();
  }
  void clearBelow() {
    for (var c = _col; c < cols; c++) {
      _cellList[_row][c].reset();
    }
    for (var r = _row + 1; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        _cellList[r][c].reset();
      }
    }
  }
  void clearAbove() {
    for (var r = 0; r <= _row; r++) {
      for (var c = 0; c < cols; c++) {
        _cellList[r][c].reset();
      }
    }
  }
  void clearLine(int mode) {
    if (_row >= rows) return;
    final l = _cellList[_row];
    if (mode == 0) {
      for (var c = _col; c < cols; c++) {
        l[c].reset();
      }
    } else if (mode == 1) {
      for (var c = 0; c <= _col; c++) {
        l[c].reset();
      }
    } else {
      for (var c = 0; c < cols; c++) {
        l[c].reset();
      }
    }
  }

  // insertar / borrar
  void insertChars(int n) {
    final m = math.min(n, cols - _col);
    if (m <= 0) return;
    for (var c = cols - 1; c >= _col + m; c--) {
      _cellList[_row][c] = _cellList[_row][c - m];
    }
    for (var c = _col; c < _col + m; c++) {
      _cellList[_row][c] = TermCell();
    }
  }
  void deleteChars(int n) {
    final m = math.min(n, cols - _col);
    if (m <= 0) return;
    for (var c = _col; c < cols - m; c++) {
      _cellList[_row][c] = _cellList[_row][c + m];
    }
    for (var c = cols - m; c < cols; c++) {
      _cellList[_row][c] = TermCell();
    }
  }
  void eraseChars(int n) {
    final m = math.min(n, cols - _col);
    for (var c = _col; c < _col + m; c++) {
      _cellList[_row][c] = TermCell();
    }
  }
  void insertLines(int n) {
    final m = math.min(n, rows - _row);
    final recycled = <List<TermCell>>[];
    for (var rr = rows - 1; rr >= rows - m; rr--) {
      recycled.add(_cellList[rr]);
    }
    for (var r in recycled) {
      for (var c in r) c.reset();
    }
    for (var rr = rows - 1; rr >= _row + m; rr--) {
      _cellList[rr] = _cellList[rr - m];
    }
    for (var i = 0; i < m; i++) {
      _cellList[_row + i] = recycled[i];
    }
  }
  void deleteLines(int n) {
    final m = math.min(n, rows - _row);
    if (m <= 0) return;
    final recycled = <List<TermCell>>[];
    for (var rr = _row; rr < _row + m; rr++) {
      recycled.add(_cellList[rr]);
    }
    for (var r in recycled) {
      for (var c in r) c.reset();
    }
    for (var rr = _row; rr < rows - m; rr++) {
      _cellList[rr] = _cellList[rr + m];
    }
    for (var i = 0; i < m; i++) {
      _cellList[rows - m + i] = recycled[i];
    }
  }
  void scrollUp() {
    final topRow = _cellList[0];
    List<TermCell>? recycledRow;
    
    if (_alt == null) {
      _history.add(topRow);
      if (_history.length > maxHistory) {
        recycledRow = _history.removeAt(0);
        for (var c in recycledRow) c.reset();
      }
    } else {
      recycledRow = topRow;
      for (var c in recycledRow) c.reset();
    }

    for (var r = 0; r < rows - 1; r++) {
      _cellList[r] = _cellList[r + 1];
    }
    _cellList[rows - 1] = recycledRow ?? _blankRow();
    if (_row > 0) _row--;
  }
  void scrollDown() {
    final bottomRow = _cellList[rows - 1];
    for (var r = rows - 1; r > 0; r--) {
      _cellList[r] = _cellList[r - 1];
    }
    for (var c in bottomRow) c.reset();
    _cellList[0] = bottomRow;
  }

  // pantalla alterna
  void enterAlt() {
    if (_alt != null) return;
    _saveR = _row;
    _saveC = _col;
    _alt = List.generate(rows, (_) => _blankRow());
    _row = 0;
    _col = 0;
  }
  void leaveAlt() {
    if (_alt == null) return;
    _alt = null;
    _row = _saveR;
    _col = _saveC;
  }

  // SGR
  void sgrReset() {
    _fg = 255;
    _bg = 256;
    _fgRgb = null;
    _bgRgb = null;
    _bold = _dim = _reverse = false;
  }
  void sgrFg(int v) => _fg = v;
  void sgrBg(int v) => _bg = v;
  void sgrFgRgb(int rgb) {
    _fgRgb = rgb;
    _fg = 255;
  }
  void sgrBgRgb(int rgb) {
    _bgRgb = rgb;
    _bg = 256;
  }
  void sgrBoldOn() {
    _bold = true;
    _dim = false;
  }
  void sgrDimOn() {
    _dim = true;
    _bold = false;
  }
  void sgrWeightOff() {
    _bold = false;
    _dim = false;
  }
  void sgrReverseOn() => _reverse = true;
  void sgrReverseOff() => _reverse = false;
}

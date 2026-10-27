part of 'ansi_terminal.dart';

/// Componente ANSI: conserva el protocolo y separa su representación.
class AnsiTerminal extends ChangeNotifier {
  final TermScreen screen;
  late final AnsiParser _parser;
  int rows, cols;
  String _title = '';
  String get title => _title;

  AnsiTerminal({this.rows = 24, this.cols = 80})
    : screen = TermScreen(rows: rows, cols: cols) {
    _parser = AnsiParser(screen);
    _parser.onTitle = (t) {
      _title = t;
      notifyListeners();
    };
  }

  /// Respuestas a queries (DA \x1b[c, DSR \x1b[6n) → el owner escribe al PTY.
  set onResponse(void Function(String data)? f) => _parser.onResponse = f;

  /// OSC 52 clipboard → el owner escribe al portapapeles.
  set onClipboard(void Function(String text)? f) => _parser.onClipboard = f;

  /// OSC 7 (cwd) → el owner sincroniza su línea de estado con el cwd real.
  set onCwd(void Function(String cwd)? f) => _parser.onCwd = f;

  /// Focus-event reporting (?1004) → el owner envía \x1b[I / \x1b[O.
  set onFocusChange(void Function({required bool focused})? f) =>
      _parser.onFocusChange = f;

  int get cursorRow => screen.cursorRow;
  int get cursorCol => screen.cursorCol;
  bool get inAltScreen => screen.inAltScreen;
  bool get cursorVisible => screen.cursorVisible;
  bool get mouseEnabled => screen.mouseEnabled;
  int get historyLength => screen.historyLength;
  TermCell getCell(int r, int c) => screen.getCell(r, c);
  List<TermCell> row(int r) => List.generate(cols, (c) => screen.getCell(r, c));
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
    for (var i = 0; i < text.length; i++) {
      _parser.consume(text.codeUnitAt(i));
    }
    notifyListeners();
  }

  /// Bytes UTF-8 incompletos al final del último chunk PTY: un carácter
  /// multibyte puede venir partido entre dos lecturas del socket.
  final List<int> _pendingBytes = [];

  void feedBytes(Uint8List data) {
    // Decodificar cada chunk aislado con utf8.decode producía U+FFFD y
    // basura visible cuando un carácter multibyte caía partido entre chunks.
    // Aquí se retienen los bytes finales incompletos y se decodifican
    // secuencias completas; los bytes de continuación sueltos se descartan.
    _pendingBytes.addAll(data);
    final buf = StringBuffer();
    var i = 0;
    var n = _pendingBytes.length;
    var runStart = 0; // inicio del run ASCII aún sin decodificar
    while (i < n) {
      final b = _pendingBytes[i];
      if (b < 0x80) {
        // TER-30: acumular run ASCII — decodificar por carácter costaba
        // ~4k allocs por chunk de 4KB (hasta ~160 chunks/s en polling).
        i++;
        continue;
      }
      // Byte no-ASCII: flush del run ASCII acumulado en una sola decode.
      if (i > runStart) {
        buf.write(
          utf8.decode(_pendingBytes.sublist(runStart, i), allowMalformed: true),
        );
      }
      int len;
      if ((b & 0xE0) == 0xC0) {
        len = 2;
      } else if ((b & 0xF0) == 0xE0) {
        len = 3;
      } else if ((b & 0xF8) == 0xF0) {
        len = 4;
      } else {
        // Byte de continuación suelto o secuencia inválida: descartar.
        _pendingBytes.removeAt(i);
        n = _pendingBytes.length;
        runStart = i; // el run flusheado terminó; el descarte corrió el resto
        continue;
      }
      if (i + len > n) break; // incompleto: esperar al siguiente chunk
      buf.write(
        utf8.decode(_pendingBytes.sublist(i, i + len), allowMalformed: true),
      );
      i += len;
      runStart = i;
    }
    if (i > runStart) {
      buf.write(
        utf8.decode(_pendingBytes.sublist(runStart, i), allowMalformed: true),
      );
    }
    if (i > 0) _pendingBytes.removeRange(0, i);
    if (buf.isNotEmpty) feed(buf.toString());
  }
}

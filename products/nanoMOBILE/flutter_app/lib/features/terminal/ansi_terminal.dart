import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'term_screen.dart';
import 'ansi_parser.dart';

// ============================================================================
// PALETA xterm 256 (16 base + 6x6x6 cube + 24 grises)
// ============================================================================
const List<int> _base16 = <int>[
  0x000000,
  0xCD0000,
  0x00CD00,
  0xCDCD00,
  0x0000EE,
  0xCD00CD,
  0x00CDCD,
  0xE5E5E5,
  0x7F7F7F,
  0xFF0000,
  0x00FF00,
  0xFFFF00,
  0x5C5CFF,
  0xFF00FF,
  0x00FFFF,
  0xFFFFFF,
];

final List<Color> _palette256 = _buildPalette();

List<Color> _buildPalette() {
  final out = <Color>[];
  for (var i = 0; i < 16; i++) {
    out.add(Color(_base16[i]));
  }
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
// MÉTRICAS DE CELDA REALES (medidas con TextPainter, no mágicos 7.6/20)
// ============================================================================
/// Ancho y alto reales de una celda del grid con el estilo mono del render.
/// Compartidas entre AnsiTerminalView (itemExtent, altura de fila) y
/// terminal_core (`_applyPtySize`, taps de mouse): el grid del buffer y el
/// render deben usar la MISMA celda o las cajas de htop/vim se descuadran
/// (el clásico "error de píxel" de terminales custom).
class AnsiMetrics {
  AnsiMetrics._(this.cellW, this.cellH);

  final double cellW;
  final double cellH;

  static AnsiMetrics? _cached;
  static String? _cachedKey;

  /// Mide una celda con el estilo dado y cachea por clave de estilo.
  ///
  /// El build del render llama esto con un `TextStyle` recién derivado
  /// (`copyWith`) en CADA rebuild. La versión previa solo cacheaba cuando
  /// style == null, así que el hot path hacía 2 TextPainter.layout() por
  /// frame (uno por cada rebuild de cada feed PTY). Ahora la clave compara
  /// solo los campos que afectan las métricas (familia, tamaño, altura,
  /// peso, espaciado) — el color/fondo no alteran cellW/cellH.
  static AnsiMetrics measure([TextStyle? style]) {
    final key = style == null ? '<default>' : _styleKey(style);
    final cached = _cached;
    if (cached != null && _cachedKey == key) return cached;
    final s =
        style ??
        const TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: ['monospace'],
          height: 1.15,
        );
    final w = TextPainter(
      text: TextSpan(text: 'M', style: s),
      textDirection: TextDirection.ltr,
    )..layout();
    final h = TextPainter(
      text: TextSpan(text: 'M\nM', style: s),
      textDirection: TextDirection.ltr,
    )..layout();
    final cellW = w.width > 0 ? w.width : 8.4;
    final cellH = h.height > 0 ? h.height / 2 : 20.0;
    final metric = AnsiMetrics._(cellW, cellH);
    _cached = metric;
    _cachedKey = key;
    return metric;
  }

  /// Clave estable de los campos que importan para medir una celda.
  static String _styleKey(TextStyle s) => [
    s.fontFamily,
    s.fontSize,
    s.height,
    s.fontWeight,
    s.letterSpacing,
    (s.fontFamilyFallback ?? const <String>[]).join(','),
  ].join('|');
}

// ============================================================================
// 3. FACADE — AnsiTerminal: screen + parser; API del consumidor + notificación.
// ============================================================================
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
    while (i < n) {
      final b = _pendingBytes[i];
      int len;
      if (b < 0x80) {
        len = 1;
      } else if ((b & 0xE0) == 0xC0) {
        len = 2;
      } else if ((b & 0xF0) == 0xE0) {
        len = 3;
      } else if ((b & 0xF8) == 0xF0) {
        len = 4;
      } else {
        // Byte de continuación suelto o secuencia inválida: descartar.
        _pendingBytes.removeAt(i);
        n = _pendingBytes.length;
        continue;
      }
      if (i + len > n) break; // incompleto: esperar al siguiente chunk
      buf.write(
        utf8.decode(_pendingBytes.sublist(i, i + len), allowMalformed: true),
      );
      i += len;
    }
    if (i > 0) _pendingBytes.removeRange(0, i);
    if (buf.isNotEmpty) feed(buf.toString());
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

class _TermLine extends StatelessWidget {
  final List<TermCell> cells;
  final TextStyle baseStyle;
  final Color defFg;
  final int? cursorCol;
  final double lineHeight;
  const _TermLine({
    required this.cells,
    required this.baseStyle,
    required this.defFg,
    required this.lineHeight,
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
      while (end < n && _same(ref, cells[end])) {
        end++;
      }

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
      height: lineHeight,
      child: Text.rich(
        TextSpan(children: spans),
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }

  void _pushSpan(
    List<InlineSpan> out,
    List<TermCell> cells,
    int a,
    int b,
    TextStyle base,
    Color defFg,
  ) {
    if (b <= a) return;
    final ref = cells[a];
    final run = StringBuffer();
    var lastWide = false;
    for (var i = a; i < b; i++) {
      final c = cells[i];
      if (c.ch == 0 && !c.wide && lastWide) {
        lastWide = false;
        continue;
      }
      lastWide = c.wide;
      run.writeCharCode(c.ch == 0 ? 0x20 : c.ch);
    }
    Color fg = ref.fgRgb != null
        ? Color(0xFF000000 | ref.fgRgb!)
        : _rfg(ref.fg, defFg);
    Color? bg = ref.bgRgb != null
        ? Color(0xFF000000 | ref.bgRgb!)
        : _rbg(ref.bg);
    final decos = <TextDecoration>[];
    if (ref.underline || ref.linkUrl != null) {
      decos.add(TextDecoration.underline);
    }
    if (ref.strikethrough) decos.add(TextDecoration.lineThrough);
    if (ref.overline) decos.add(TextDecoration.overline);
    final deco = decos.isEmpty
        ? TextDecoration.none
        : TextDecoration.combine(decos);
    var style = base.copyWith(
      color: ref.dim ? fg.withValues(alpha: 0.6) : fg,
      fontWeight: ref.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: ref.italic ? FontStyle.italic : FontStyle.normal,
      decoration: deco,
      decorationColor: fg,
    );
    if (ref.reverse) {
      style = style.copyWith(color: bg ?? defFg, backgroundColor: fg);
    } else if (bg != null) {
      style = style.copyWith(backgroundColor: bg);
    }
    out.add(TextSpan(text: run.toString(), style: style));
  }

  /// Block cursor: celda invertida (fondo = fg del terminal, texto oscuro).
  void _pushCursor(
    List<InlineSpan> out,
    TermCell cell,
    TextStyle base,
    Color defFg,
  ) {
    Color fg = _rfg(cell.fg, defFg);
    final textColor = _rbg(cell.bg) ?? const Color(0xFF020611);
    out.add(
      TextSpan(
        text: String.fromCharCode(cell.ch == 0 ? 0x20 : cell.ch),
        style: base.copyWith(
          color: textColor,
          backgroundColor: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _same(TermCell a, TermCell b) =>
      a.fg == b.fg &&
      a.bg == b.bg &&
      a.bold == b.bold &&
      a.dim == b.dim &&
      a.reverse == b.reverse &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.blink == b.blink &&
      a.strikethrough == b.strikethrough &&
      a.overline == b.overline &&
      a.linkUrl == b.linkUrl &&
      a.wide == b.wide &&
      a.fgRgb == b.fgRgb &&
      a.bgRgb == b.bgRgb;
}

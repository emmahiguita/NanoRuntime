part of 'ansi_terminal.dart';

/// Componente ANSI: conserva el protocolo y separa su representación.
class _TermLine extends StatelessWidget {
  final List<TermCell> cells;
  final TextStyle baseStyle;
  final Color defFg;
  final Color defaultBg;
  final int? cursorCol;
  final double lineHeight;
  const _TermLine({
    required this.cells,
    required this.baseStyle,
    required this.defFg,
    required this.defaultBg,
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
    if (bg == null && !ref.reverse) {
      fg = _readableAnsiForeground(fg, defaultBg, dim: ref.dim);
    }
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

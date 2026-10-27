part of 'ansi_terminal.dart';

/// Componente ANSI: conserva el protocolo y separa su representación.
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

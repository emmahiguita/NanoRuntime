/// Bounds en coordenadas absolutas de pantalla (px).
class NanoBounds {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const NanoBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  int get width => right - left;
  int get height => bottom - top;
  int get centerX => (left + right) ~/ 2;
  int get centerY => (top + bottom) ~/ 2;

  /// Gap en px entre este rect y [other]: 0 si se solapan en ambos ejes.
  /// Para el criterio "near" se mide por eje (ver [xOverlapRatio]).
  int distanceTo(NanoBounds other) {
    final xGap = (other.left > right)
        ? other.left - right
        : (left > other.right)
        ? left - other.right
        : 0;
    final yGap = (other.top > bottom)
        ? other.top - bottom
        : (top > other.bottom)
        ? top - other.bottom
        : 0;
    return xGap > yGap ? xGap : yGap;
  }

  /// Fracción de solapamiento en el eje X (0..1) respecto a [other].
  /// Patrón label→campo: el TextView y el EditText comparten casi todo el
  /// ancho de la fila.
  double xOverlapRatio(NanoBounds other) {
    final overlapStart = left > other.left ? left : other.left;
    final overlapEnd = right < other.right ? right : other.right;
    final overlap = overlapEnd - overlapStart;
    if (overlap <= 0) return 0;
    final mine = width;
    final theirs = other.width;
    final minWidth = mine < theirs ? mine : theirs;
    if (minWidth <= 0) return 0;
    return overlap / minWidth;
  }

  /// [l, t, r, b] — el formato que envía el canal nativo.
  factory NanoBounds.fromList(List<dynamic> l) {
    return NanoBounds(
      left: (l[0] as num).toInt(),
      top: (l[1] as num).toInt(),
      right: (l[2] as num).toInt(),
      bottom: (l[3] as num).toInt(),
    );
  }

  @override
  String toString() => '[$left,$top,$right,$bottom]';
}

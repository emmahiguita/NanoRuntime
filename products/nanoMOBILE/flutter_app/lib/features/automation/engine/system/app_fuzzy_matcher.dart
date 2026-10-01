/// AppFuzzyMatcher — matching fonético/aproximado para nombres de apps.
///
/// SRP: SOLO computa distancias y similitudes. No toca inventario ni catálogo.
///
/// Estrategia de dos capas:
///   1. Levenshtein normalizado: distancia de edición / max(len) ≤ umbral.
///      Cubre errores tipográficos ("spotfy", "telegrama", "crome").
///   2. Soundex español: clasifica consonantes según su sonoridad en español y
///      compara el código. Cubre variaciones fonéticas ("feisbuk"→"facebook",
///      "guasap"→"whatsapp"). NO usa el Soundex inglés (diseñado para inglés).
///
/// Umbrales calibrados para nombres de app cortos:
///   - Levenshtein: ≤ 0.35 (35% de edición sobre la longitud mayor).
///     Para strings cortos (len≤4) el umbral baja a ≤ 0.25 para evitar
///     falsos positivos ("fb" matching "f" sería distancia 0.5 → reject).
///   - Soundex: SOLO se aplica como fallback si Levenshtein no resuelve Y
///     ambas cadenas tienen ≥ 4 caracteres (un soundex de 1-2 chars es trivial).
library;

/// Resultado de un match fuzzy.
class FuzzyMatchScore implements Comparable<FuzzyMatchScore> {
  /// Similitud [0.0 – 1.0]; 1.0 = perfecta.
  final double similarity;

  /// Técnica usada.
  final FuzzyTechnique technique;

  const FuzzyMatchScore({required this.similarity, required this.technique});

  @override
  int compareTo(FuzzyMatchScore other) =>
      other.similarity.compareTo(similarity);

  @override
  String toString() =>
      'FuzzyMatchScore(${(similarity * 100).toStringAsFixed(1)}%, $technique)';
}

enum FuzzyTechnique { levenshtein, soundex }

/// Matcher sin estado (todas las operaciones son puras).
class AppFuzzyMatcher {
  const AppFuzzyMatcher({
    this.levenshteinThreshold = 0.35,
    this.shortLengthThreshold = 4,
    this.shortLevenshteinThreshold = 0.25,
    this.soundexMinLength = 4,
  });

  /// Umbral de similitud Levenshtein para strings normales.
  final double levenshteinThreshold;

  /// Longitud máxima para considerar un string "corto".
  final int shortLengthThreshold;

  /// Umbral más estricto para strings cortos.
  final double shortLevenshteinThreshold;

  /// Longitud mínima para aplicar Soundex como fallback.
  final int soundexMinLength;

  // ---------------------------------------------------------------------------
  // API pública
  // ---------------------------------------------------------------------------

  /// Calcula la mejor puntuación de similitud entre [query] y [candidate].
  /// Ambas cadenas deben estar ya normalizadas (lowercase, trim, sin tildes).
  /// Devuelve null si ninguna técnica supera el umbral configurado.
  FuzzyMatchScore? score(String query, String candidate) {
    if (query.isEmpty || candidate.isEmpty) return null;

    // Levenshtein
    final lev = _levenshteinSimilarity(query, candidate);
    final maxLen = query.length > candidate.length ? query.length : candidate.length;
    final threshold = maxLen <= shortLengthThreshold
        ? shortLevenshteinThreshold
        : levenshteinThreshold;

    if (lev >= (1.0 - threshold)) {
      return FuzzyMatchScore(
        similarity: lev,
        technique: FuzzyTechnique.levenshtein,
      );
    }

    // Soundex español (fallback)
    if (query.length >= soundexMinLength &&
        candidate.length >= soundexMinLength) {
      final sq = soundexEs(query);
      final sc = soundexEs(candidate);
      if (sq == sc && sq.length >= 2) {
        // Similitud sintética: Levenshtein real + boost fonético.
        final boostSimilarity = (lev + 1.0) / 2.0;
        return FuzzyMatchScore(
          similarity: boostSimilarity,
          technique: FuzzyTechnique.soundex,
        );
      }
    }

    return null;
  }

  /// True si [query] es un match fuzzy aceptable de [candidate].
  bool matches(String query, String candidate) => score(query, candidate) != null;

  // ---------------------------------------------------------------------------
  // Levenshtein
  // ---------------------------------------------------------------------------

  /// Similitud normalizada [0.0 – 1.0]:  1 - (editDistance / max(len)).
  double _levenshteinSimilarity(String a, String b) {
    final dist = _editDistance(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (dist / maxLen);
  }

  /// Distancia de edición mínima (Wagner-Fischer).
  int _editDistance(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    // Usamos dos filas para ahorrar memoria (O(n) en espacio).
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        curr[j] = _min3(
          curr[j - 1] + 1,     // inserción
          prev[j] + 1,          // eliminación
          prev[j - 1] + cost,   // sustitución
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  int _min3(int a, int b, int c) {
    if (a < b) return a < c ? a : c;
    return b < c ? b : c;
  }

  // ---------------------------------------------------------------------------
  // Soundex español
  // ---------------------------------------------------------------------------
  // Tabla de codificación adaptada al español:
  //   - B/V → mismo código (suenan igual).
  //   - LL/Y → mismo código (yeísmo).
  //   - GE/GI/J → mismo código.
  //   - CE/CI/S/Z → mismo código (seseo hispanoamericano).
  //   - QU/K → mismo código.
  //   - Vocales → 0 (se eliminan tras la primera letra).
  //   - H → silenciosa, se ignora.
  //   - Ñ → trato propio (código 5).
  // ---------------------------------------------------------------------------

  static const Map<String, String> _soundexTable = {
    'b': '1', 'v': '1',
    'f': '2', 'ph': '2',
    'c': '3', 'k': '3', 'q': '3', 'g': '3',
    'd': '4', 't': '4',
    'l': '5', 'll': '5', 'y': '5',
    'm': '6', 'n': '6', 'ñ': '7',
    'r': '8', 'rr': '8',
    's': '9', 'z': '9', 'x': '9',
    'p': 'A',
  };

  /// Genera un código Soundex español para [word] (ya normalizada, sin tildes).
  /// Longitud fija de 4 caracteres: primera letra + 3 dígitos (padded con 0).
  static String soundexEs(String word) {
    if (word.isEmpty) return '';

    final chars = word.toLowerCase().replaceAll(RegExp(r'[^a-zñ]'), '');
    if (chars.isEmpty) return '';

    final first = chars[0].toUpperCase();
    final coded = StringBuffer();
    String prevCode = _codeFor(chars[0]);

    for (var i = 1; i < chars.length && coded.length < 3; i++) {
      // Digrama (LL, RR, PH): intenta dos chars primero.
      if (i + 1 < chars.length) {
        final digram = chars.substring(i, i + 2);
        if (_soundexTable.containsKey(digram)) {
          final c = _soundexTable[digram]!;
          if (c != prevCode) {
            coded.write(c);
            prevCode = c;
          }
          i++; // salta el segundo carácter del digrama
          continue;
        }
      }
      final c = _codeFor(chars[i]);
      if (c.isNotEmpty && c != prevCode) {
        coded.write(c);
        prevCode = c;
      } else if (c.isEmpty) {
        // vocal: resetear el código previo para que la siguiente consonante
        // siempre se incluya (evitar colapsar ROBERT/RUPERT en R163).
        prevCode = '';
      }
    }

    final padded = coded.toString().padRight(3, '0');
    return '$first${padded.substring(0, 3)}';
  }

  static String _codeFor(String char) {
    // Vocales → ''
    if ('aeiouáéíóúü'.contains(char)) return '';
    if (char == 'h') return ''; // muda
    return _soundexTable[char] ?? '';
  }
}

/// Instancia singleton compartida con configuración por defecto.
const appFuzzyMatcher = AppFuzzyMatcher();

/// Evaluador aritmético para `expr`. Soporta + - * / y paréntesis.
///
/// Extraído de _TermState (SRP). Clase pura sin dependencias — recibe string,
/// devuelve int. Usa recursive-descent parser con estado interno por instancia.
class ExpressionEvaluator {
  int _pos = 0;
  String _exprSrc = '';

  /// Evalúa una expresión aritmética simple. Soporta números, +, -, *, /,
  /// paréntesis, y espacios.
  int eval(String expr) {
    final s = expr.replaceAll(' ', '');
    // Solo números y operadores básicos
    if (RegExp(r'^[\d\+\-\*/\(\)]+$').hasMatch(s)) {
      return _evalSimple(s);
    }
    // Fallback: sumar si es "X + Y"
    final add = RegExp(r'(\d+)\s*\+\s*(\d+)').firstMatch(expr);
    if (add != null) return int.parse(add.group(1)!) + int.parse(add.group(2)!);
    final sub = RegExp(r'(\d+)\s*\-\s*(\d+)').firstMatch(expr);
    if (sub != null) return int.parse(sub.group(1)!) - int.parse(sub.group(2)!);
    final mul = RegExp(r'(\d+)\s*\*\s*(\d+)').firstMatch(expr);
    if (mul != null) return int.parse(mul.group(1)!) * int.parse(mul.group(2)!);
    final div = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(expr);
    if (div != null) {
      return int.parse(div.group(1)!) ~/ int.parse(div.group(2)!);
    }
    return 0;
  }

  int _evalSimple(String s) {
    _pos = 0;
    _exprSrc = s;
    return _parseExpr();
  }

  int _parseExpr() {
    var v = _parseFactor();
    while (_pos < _exprSrc.length &&
        (_exprSrc[_pos] == '+' || _exprSrc[_pos] == '-')) {
      final op = _exprSrc[_pos];
      _pos++;
      final r = _parseFactor();
      v = op == '+' ? v + r : v - r;
    }
    return v;
  }

  int _parseFactor() {
    var v = _parseTerm();
    while (_pos < _exprSrc.length &&
        (_exprSrc[_pos] == '*' || _exprSrc[_pos] == '/')) {
      final op = _exprSrc[_pos];
      _pos++;
      final r = _parseTerm();
      v = op == '*' ? v * r : v ~/ r;
    }
    return v;
  }

  int _parseTerm() {
    if (_pos < _exprSrc.length && _exprSrc[_pos] == '(') {
      _pos++;
      final v = _parseExpr();
      _pos++;
      return v;
    }
    final start = _pos;
    while (_pos < _exprSrc.length &&
        RegExp(r'[0-9]').hasMatch(_exprSrc[_pos])) {
      _pos++;
    }
    return int.parse(_exprSrc.substring(start, _pos));
  }
}

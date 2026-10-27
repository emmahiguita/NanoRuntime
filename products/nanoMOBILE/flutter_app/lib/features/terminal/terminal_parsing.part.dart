part of 'terminal_core.dart';

/// Componente parsing: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalParsing on _TerminalStateBase {
  @override
  List<String> _tok(String c) {
    final t = <String>[], b = StringBuffer();
    bool sq = false, dq = false;
    for (int i = 0; i < c.length; i++) {
      final ch = c[i];
      if (ch == "'" && !dq) {
        sq = !sq;
        continue;
      }
      if (ch == '"' && !sq) {
        dq = !dq;
        continue;
      }
      if (ch == ' ' && !sq && !dq) {
        if (b.isNotEmpty) {
          t.add(b.toString());
          b.clear();
        }
        continue;
      }
      b.write(ch);
    }
    if (b.isNotEmpty) t.add(b.toString());
    return t;
  }

  /// Detecta operadores de shell (| > < >> && || ;) fuera de comillas. Si están presentes, el comando debe delegarse a bash -c.
  @override
  bool _hasShellOps(String cmd) {
    bool sq = false, dq = false;
    for (int i = 0; i < cmd.length; i++) {
      final ch = cmd[i];
      if (ch == "'" && !dq) {
        sq = !sq;
        continue;
      }
      if (ch == '"' && !sq) {
        dq = !dq;
        continue;
      }
      if (sq || dq) continue;
      if (ch == '|') return true;
      if (ch == '>' || ch == '<') return true;
      if (ch == '&' && i + 1 < cmd.length && cmd[i + 1] == '&') return true;
      if (ch == '|' && i + 1 < cmd.length && cmd[i + 1] == '|') return true;
      if (ch == ';') return true;
    }
    return false;
  }
}

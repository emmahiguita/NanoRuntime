import 'package:flutter/foundation.dart';
import 'terminal_types.dart';

class TerminalSessionController extends ChangeNotifier {
  final List<TL> _lines = [];
  bool _ptyActive = false;
  String _bashCwd = '/';

  List<TL> get lines => List.unmodifiable(_lines);
  bool get ptyActive => _ptyActive;
  String get bashCwd => _bashCwd;

  void out(String text, Ln type) {
    if (text.isEmpty && type == Ln.stdout) return;
    _lines.add(TL(text, type));
    if (_lines.length > 10000) {
      _lines.removeRange(0, _lines.length - 10000);
    }
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  void setPtyActive(bool active) {
    if (_ptyActive != active) {
      _ptyActive = active;
      notifyListeners();
    }
  }

  void setBashCwd(String cwd) {
    if (_bashCwd != cwd) {
      _bashCwd = cwd;
      notifyListeners();
    }
  }
}
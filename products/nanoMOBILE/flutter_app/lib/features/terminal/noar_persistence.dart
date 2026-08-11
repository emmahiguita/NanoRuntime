import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia de la librería Noar (historial de comandos con metadata).
///
/// Extraído de _TermState (SRP). Encapsula toda la lógica de guardado/carga
/// de comandos con timestamp y tag. Sin dependencia de Flutter widgets.
class NoarPersistence {
  static const _key = 'noar_library';

  final List<Map<String, dynamic>> entries = [];

  /// Carga la librería desde SharedPreferences.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final j = p.getString(_key);
      if (j != null) {
        final list = (jsonDecode(j) as List).cast<Map>();
        entries.addAll(list.map((m) => Map<String, dynamic>.from(m)));
      }
    } catch (_) {}
  }

  /// Guarda un comando al inicio de la librería con timestamp y tag.
  void save(String cmd, String tag) {
    entries.insert(0, {
      'cmd': cmd,
      'tag': tag,
      'ts': DateTime.now().toIso8601String(),
    });
    if (entries.length > 500) entries.removeRange(500, entries.length);
    _persist();
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(entries.take(500).toList()));
    } catch (_) {}
  }
}

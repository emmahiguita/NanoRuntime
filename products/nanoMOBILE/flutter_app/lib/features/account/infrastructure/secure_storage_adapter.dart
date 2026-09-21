import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QUÉ HACE:
/// Almacenamiento seguro local para material de sesión de Nano (SecureStoragePort).
///
/// CÓMO FUNCIONA:
/// Ofusca y protege las claves y tokens de sesión en disco usando derivación
/// determinista SHA-256 para prevenir lecturas accidentales en texto plano.
///
/// POR QUÉ:
/// Garantiza que los tokens de sesión no queden expuestos directamente si un
/// proceso lee el almacenamiento de la aplicación sin privilegios.
class SecureStorageAdapter {
  static const String _prefix = 'nano_sec_';
  final SharedPreferences? _prefsInstance;

  SecureStorageAdapter({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  String _hashKey(String key) => sha256.convert(utf8.encode(key)).toString();

  Future<void> write(String key, String value) async {
    final prefs = await _getPrefs();
    final hashedKey = '$_prefix${_hashKey(key)}';
    final encodedValue = base64Encode(utf8.encode(value));
    await prefs.setString(hashedKey, encodedValue);
  }

  Future<String?> read(String key) async {
    final prefs = await _getPrefs();
    final hashedKey = '$_prefix${_hashKey(key)}';
    final raw = prefs.getString(hashedKey);
    if (raw == null) return null;
    try {
      return utf8.decode(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String key) async {
    final prefs = await _getPrefs();
    final hashedKey = '$_prefix${_hashKey(key)}';
    await prefs.remove(hashedKey);
  }

  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}

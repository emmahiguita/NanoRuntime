import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/browser/domain/browser_credential_model.dart';

/// Bóveda de almacenamiento seguro y cifrado de credenciales para el Navegador Nano AI.
///
/// - ¿Qué hace?: Persiste y recupera contraseñas usando cifrado simétrico por flujo y HMAC.
/// - ¿Cómo funciona?: CTR stream cipher con clave derivada de 256 bits y verificación HMAC-SHA256.
/// - ¿Por qué?: Garantiza que ninguna credencial se almacene en texto plano en disco (SharedPreferences).
class BrowserCredentialVault {
  static const String _storageKey = '__nano_browser_vault_credentials_v1';
  static const String _saltKey = '__nano_browser_vault_master_salt_v1';

  final SharedPreferences _prefs;
  late final List<int> _derivedKey;

  BrowserCredentialVault(this._prefs) {
    _derivedKey = _initKey();
  }

  static Future<BrowserCredentialVault> create() async {
    final prefs = await SharedPreferences.getInstance();
    return BrowserCredentialVault(prefs);
  }

  List<int> _initKey() {
    var salt = _prefs.getString(_saltKey);
    if (salt == null || salt.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      salt = base64Url.encode(bytes);
      _prefs.setString(_saltKey, salt);
    }
    final hmac = Hmac(sha256, utf8.encode('NanoAI.BrowserSecurityVault.MasterKey.2026'));
    return hmac.convert(base64Url.decode(salt)).bytes;
  }

  String encryptPassword(String plain) {
    if (plain.isEmpty) return '';
    final rnd = Random.secure();
    final iv = List<int>.generate(16, (_) => rnd.nextInt(256));
    final plainBytes = utf8.encode(plain);

    final cipherBytes = <int>[];
    for (int i = 0; i < plainBytes.length; i++) {
      final streamBlock = sha256.convert([..._derivedKey, ...iv, i ~/ 32]).bytes;
      cipherBytes.add(plainBytes[i] ^ streamBlock[i % 32]);
    }

    final mac = Hmac(sha256, _derivedKey).convert([...iv, ...cipherBytes]).bytes;
    final payload = {'v': 1, 'iv': base64.encode(iv), 'c': base64.encode(cipherBytes), 'm': base64.encode(mac)};
    return base64.encode(utf8.encode(json.encode(payload)));
  }

  String decryptPassword(String encrypted) {
    if (encrypted.isEmpty) return '';
    try {
      final rawJson = utf8.decode(base64.decode(encrypted));
      final map = json.decode(rawJson) as Map<String, dynamic>;
      final iv = base64.decode(map['iv'] as String);
      final cipherBytes = base64.decode(map['c'] as String);
      final mac = base64.decode(map['m'] as String);

      final computedMac = Hmac(sha256, _derivedKey).convert([...iv, ...cipherBytes]).bytes;
      if (!_constantTimeEquals(mac, computedMac)) return '';

      final plainBytes = <int>[];
      for (int i = 0; i < cipherBytes.length; i++) {
        final streamBlock = sha256.convert([..._derivedKey, ...iv, i ~/ 32]).bytes;
        plainBytes.add(cipherBytes[i] ^ streamBlock[i % 32]);
      }
      return utf8.decode(plainBytes);
    } catch (_) {
      return '';
    }
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) { result |= a[i] ^ b[i]; }
    return result == 0;
  }

  Future<List<BrowserCredential>> getAllCredentials() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return BrowserCredential.fromMap({...map, 'password': decryptPassword(map['password'] as String? ?? '')});
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<BrowserCredential>> getCredentialsForDomain(String domain) async {
    final clean = _normalizeDomain(domain);
    final all = await getAllCredentials();
    return all.where((c) {
      final cd = _normalizeDomain(c.domain);
      return cd == clean || clean.endsWith('.$cd') || cd.endsWith('.$clean');
    }).toList();
  }

  Future<void> saveCredential(BrowserCredential credential) async {
    final all = await getAllCredentials();
    final cleanDomain = _normalizeDomain(credential.domain);
    final cleanUser = credential.username.trim();

    final index = all.indexWhere((c) => _normalizeDomain(c.domain) == cleanDomain && c.username.trim() == cleanUser);
    final updated = List<BrowserCredential>.from(all);
    final newCred = credential.copyWith(
      id: credential.id.isNotEmpty ? credential.id : DateTime.now().microsecondsSinceEpoch.toString(),
      domain: cleanDomain, username: cleanUser, lastUsedAt: DateTime.now(),
    );

    if (index >= 0) {
      updated[index] = newCred;
    } else {
      updated.add(newCred);
    }
    await _persistCredentials(updated);
  }

  Future<void> deleteCredential(String id) async {
    final all = await getAllCredentials();
    await _persistCredentials(all.where((c) => c.id != id).toList());
  }

  Future<void> updateLastUsed(String id) async {
    final all = await getAllCredentials();
    final index = all.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final updated = List<BrowserCredential>.from(all);
      updated[index] = updated[index].copyWith(lastUsedAt: DateTime.now());
      await _persistCredentials(updated);
    }
  }

  Future<void> clearAll() async => await _prefs.remove(_storageKey);

  Future<void> _persistCredentials(List<BrowserCredential> list) async {
    final serialized = list.map((c) {
      final map = c.toMap();
      map['password'] = encryptPassword(c.password);
      return map;
    }).toList();
    await _prefs.setString(_storageKey, json.encode(serialized));
  }

  String _normalizeDomain(String raw) {
    var domain = raw.trim().toLowerCase();
    if (domain.startsWith('https://')) domain = domain.substring(8);
    if (domain.startsWith('http://')) domain = domain.substring(7);
    final slash = domain.indexOf('/');
    if (slash != -1) domain = domain.substring(0, slash);
    final colon = domain.indexOf(':');
    if (colon != -1) domain = domain.substring(0, colon);
    if (domain.startsWith('www.')) domain = domain.substring(4);
    return domain;
  }
}


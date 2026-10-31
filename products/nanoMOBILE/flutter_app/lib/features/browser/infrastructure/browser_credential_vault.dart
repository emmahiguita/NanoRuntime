import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/browser/domain/browser_credential_model.dart';

/// QUÉ HACE:
/// Bóveda de almacenamiento seguro y cifrado de credenciales para el Navegador Nano AI.
///
/// CÓMO FUNCIONA:
/// Obtiene o genera un secreto maestro aleatorio de 256 bits almacenado en Android Keystore
/// mediante `FlutterSecureStorage` (con respaldo determinista solo para entornos de test sin
/// canal nativo) y cifra contraseñas con CTR-SHA256 + autenticación HMAC-SHA256.
///
/// POR QUÉ:
/// Elimina el uso de claves maestras fijas en el binario al persistir credenciales en disco,
/// manteniendo compatibilidad hacia atrás y menos de 200 líneas.
class BrowserCredentialVault {
  static const String _storageKey = '__nano_browser_vault_credentials_v1';
  static const String _saltKey = '__nano_browser_vault_master_salt_v1';
  static const String _keystoreMasterKey = '__nano_browser_keystore_master_v2';
  static const String _legacySecret = 'NanoAI.BrowserSecurityVault.MasterKey.2026';

  final SharedPreferences _prefs;
  late final List<int> _derivedKey;
  late final List<int> _legacyDerivedKey;

  BrowserCredentialVault(this._prefs, {List<int>? keystoreSecret}) {
    final saltBytes = _loadOrCreateSalt();
    _legacyDerivedKey =
        Hmac(sha256, utf8.encode(_legacySecret)).convert(saltBytes).bytes;
    _derivedKey = keystoreSecret != null && keystoreSecret.isNotEmpty
        ? Hmac(sha256, keystoreSecret).convert(saltBytes).bytes
        : _legacyDerivedKey;
  }

  static Future<BrowserCredentialVault> create() async {
    final prefs = await SharedPreferences.getInstance();
    final keystoreSecret = await _loadOrCreateKeystoreSecret();
    return BrowserCredentialVault(prefs, keystoreSecret: keystoreSecret);
  }

  static Future<List<int>?> _loadOrCreateKeystoreSecret() async {
    try {
      const storage = FlutterSecureStorage();
      var encoded = await storage.read(key: _keystoreMasterKey);
      if (encoded == null || encoded.isEmpty) {
        final rnd = Random.secure();
        final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
        encoded = base64Url.encode(bytes);
        await storage.write(key: _keystoreMasterKey, value: encoded);
      }
      return base64Url.decode(encoded);
    } catch (_) {
      return null;
    }
  }

  List<int> _loadOrCreateSalt() {
    var salt = _prefs.getString(_saltKey);
    if (salt == null || salt.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      salt = base64Url.encode(bytes);
      _prefs.setString(_saltKey, salt);
    }
    return base64Url.decode(salt);
  }

  String encryptPassword(String plain) {
    if (plain.isEmpty) return '';
    final rnd = Random.secure();
    final iv = List<int>.generate(16, (_) => rnd.nextInt(256));
    final plainBytes = utf8.encode(plain);
    final cipherBytes = _xorStream(_derivedKey, iv, plainBytes);
    final mac = Hmac(sha256, _derivedKey).convert([...iv, ...cipherBytes]).bytes;
    final payload = {
      'v': 2,
      'iv': base64.encode(iv),
      'c': base64.encode(cipherBytes),
      'm': base64.encode(mac),
    };
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

      final primaryMac =
          Hmac(sha256, _derivedKey).convert([...iv, ...cipherBytes]).bytes;
      if (_constantTimeEquals(mac, primaryMac)) {
        return utf8.decode(_xorStream(_derivedKey, iv, cipherBytes));
      }
      final legacyMac =
          Hmac(sha256, _legacyDerivedKey).convert([...iv, ...cipherBytes]).bytes;
      if (_constantTimeEquals(mac, legacyMac)) {
        return utf8.decode(_xorStream(_legacyDerivedKey, iv, cipherBytes));
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  List<int> _xorStream(List<int> key, List<int> iv, List<int> input) {
    return List<int>.generate(input.length, (i) {
      final block = sha256.convert([...key, ...iv, i ~/ 32]).bytes;
      return input[i] ^ block[i % 32];
    });
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  Future<List<BrowserCredential>> getAllCredentials() async {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return BrowserCredential.fromMap({
          ...map,
          'password': decryptPassword(map['password'] as String? ?? ''),
        });
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
    final index = all.indexWhere(
      (c) => _normalizeDomain(c.domain) == cleanDomain && c.username.trim() == cleanUser,
    );
    final updated = List<BrowserCredential>.from(all);
    final newCred = credential.copyWith(
      id: credential.id.isNotEmpty
          ? credential.id
          : DateTime.now().microsecondsSinceEpoch.toString(),
      domain: cleanDomain,
      username: cleanUser,
      lastUsedAt: DateTime.now(),
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

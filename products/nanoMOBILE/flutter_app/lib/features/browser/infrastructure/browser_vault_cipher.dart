// QUÉ: Motor criptográfico para el cifrado y descifrado de credenciales en Nano Browser.
// CÓMO: Implementa flujo CTR-SHA256 con IV aleatorio y autenticación HMAC-SHA256 en tiempo constante.
// POR QUÉ: Extraído de BrowserCredentialVault para aplicar SRP (SOLID) y límite < 200 líneas.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class BrowserVaultCipher {
  final List<int> derivedKey;
  final List<int> legacyDerivedKey;

  const BrowserVaultCipher({
    required this.derivedKey,
    required this.legacyDerivedKey,
  });

  String encryptPassword(String plain) {
    if (plain.isEmpty) return '';
    final rnd = Random.secure();
    final iv = List<int>.generate(16, (_) => rnd.nextInt(256));
    final plainBytes = utf8.encode(plain);
    final cipherBytes = _xorStream(derivedKey, iv, plainBytes);
    final mac =
        Hmac(sha256, derivedKey).convert([...iv, ...cipherBytes]).bytes;
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
          Hmac(sha256, derivedKey).convert([...iv, ...cipherBytes]).bytes;
      if (_constantTimeEquals(mac, primaryMac)) {
        return utf8.decode(_xorStream(derivedKey, iv, cipherBytes));
      }
      final legacyMac =
          Hmac(sha256, legacyDerivedKey).convert([...iv, ...cipherBytes]).bytes;
      if (_constantTimeEquals(mac, legacyMac)) {
        return utf8.decode(_xorStream(legacyDerivedKey, iv, cipherBytes));
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
}

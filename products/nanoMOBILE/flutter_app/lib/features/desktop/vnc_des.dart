import 'dart:typed_data';

/// DES puro en Dart para VNC Authentication (RFB Security Type 2).
///
/// Implementación ECB estándar (FIPS 46-3) con tablas clásicas. Solo se
/// necesita cifrar (challenge → response), nunca descifrar, así que solo
/// se expone [desEncryptBlock].
///
/// Nota de seguridad: DES es criptográficamente obsoleto (56 bits) — pero es
/// el protocolo VNC Authentication, no lo elegimos nosotros. El valor real
/// de la protección está en que la contraseña NUNCA viaja en claro y el
/// anti-brute-force de TigerVNC bloquea tras ~5 fallos.

// ── Permutación inicial (IP) y final (FP) ──────────────────────────────────
const List<int> _ip = [
  58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
  62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
  57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
  61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7,
];

const List<int> _fp = [
  40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
  38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
  36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
  34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25,
];

// ── Expansión E (32 → 48 bits) ─────────────────────────────────────────────
const List<int> _e = [
  32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9,
  8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17,
  16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25,
  24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1,
];

// ── Permutación P (32 bits) ────────────────────────────────────────────────
const List<int> _p = [
  16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10,
  2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25,
];

// ── PC-1 (64 → 56 bits) y PC-2 (56 → 48 bits) ──────────────────────────────
const List<int> _pc1 = [
  57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18,
  10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
  63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22,
  14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4,
];

const List<int> _pc2 = [
  14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10,
  23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2,
  41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48,
  44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32,
];

// ── S-boxes (8 × 64 entradas) ──────────────────────────────────────────────
const List<List<int>> _sboxes = [
  [
    14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
    0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
    4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
    15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13,
  ],
  [
    15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10,
    3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5,
    0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15,
    13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9,
  ],
  [
    10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8,
    13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
    13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7,
    1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12,
  ],
  [
    7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15,
    13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
    10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4,
    3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14,
  ],
  [
    2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9,
    14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
    4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14,
    11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3,
  ],
  [
    12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11,
    10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
    9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6,
    4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13,
  ],
  [
    4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1,
    13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
    1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2,
    6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12,
  ],
  [
    13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7,
    1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
    7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8,
    2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11,
  ],
];

// ── Desplazamientos del key schedule ───────────────────────────────────────
const List<int> _shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

/// Aplica una permutación de bits. [table] numera bits desde 1 (MSB) como
/// FIPS; [inputBits] es el ancho del bloque de entrada (64/56/32).
int _permute(int input, List<int> table, int inputBits) {
  var output = 0;
  for (var i = 0; i < table.length; i++) {
    final srcBit = table[i] - 1; // 0-based desde el MSB
    final bit = (input >> (inputBits - 1 - srcBit)) & 1;
    output = (output << 1) | bit;
  }
  return output;
}

int _rotl28(int v, int n) => ((v << n) | (v >> (28 - n))) & 0x0FFFFFFF;

/// Genera las 16 subclaves de ronda (48 bits cada una) desde una clave de
/// 64 bits (los bits de paridad se descartan vía PC-1).
List<int> _generateSubkeys(int key) {
  final pc1 = _permute(key, _pc1, 64); // 56 bits
  var c = (pc1 >> 28) & 0x0FFFFFFF;
  var d = pc1 & 0x0FFFFFFF;
  final subkeys = List<int>.filled(16, 0);
  for (var i = 0; i < 16; i++) {
    c = _rotl28(c, _shifts[i]);
    d = _rotl28(d, _shifts[i]);
    subkeys[i] = _permute((c << 28) | d, _pc2, 56); // 48 bits
  }
  return subkeys;
}

/// Función de ronda f(R, K): expansión E → XOR → S-boxes → P.
int _f(int r, int subkey) {
  final e = _permute(r, _e, 32); // 48 bits
  final x = e ^ subkey;
  var out = 0;
  for (var s = 0; s < 8; s++) {
    final bits = (x >> (42 - 6 * s)) & 0x3F;
    final row = ((bits >> 4) & 0x2) | (bits & 0x1);
    final col = (bits >> 1) & 0xF;
    out = (out << 4) | _sboxes[s][row * 16 + col];
  }
  return _permute(out, _p, 32);
}

/// Cifra un bloque de 64 bits (ECB, un solo bloque) con DES.
/// [key] son los 8 bytes de la clave, MSB-first (los bits de paridad se
/// ignoran internamente por PC-1, como manda el estándar).
int _desBlock(int block, List<int> subkeys) {
  final ip = _permute(block, _ip, 64);
  var left = (ip >> 32) & 0xFFFFFFFF;
  var right = ip & 0xFFFFFFFF;
  for (var round = 0; round < 16; round++) {
    final f = _f(right, subkeys[round]);
    final newLeft = right;
    final newRight = left ^ f;
    left = newLeft;
    right = newRight;
  }
  // 32-bit swap antes de la permutación final (L16/R16 → R16||L16).
  final preOutput = (right << 32) | (left & 0xFFFFFFFF);
  return _permute(preOutput, _fp, 64);
}

/// Cifra un bloque de 8 bytes con DES (ECB). Devuelve los 8 bytes cifrados.
Uint8List desEncryptBlock(Uint8List block, Uint8List key) {
  assert(block.length == 8, 'DES opera sobre bloques de 8 bytes');
  assert(key.length == 8, 'La clave DES son 8 bytes');
  var blockInt = 0;
  for (var i = 0; i < 8; i++) {
    blockInt = (blockInt << 8) | block[i];
  }
  var keyInt = 0;
  for (var i = 0; i < 8; i++) {
    keyInt = (keyInt << 8) | key[i];
  }
  var encrypted = _desBlock(blockInt, _generateSubkeys(keyInt));
  final out = Uint8List(8);
  for (var i = 7; i >= 0; i--) {
    out[i] = encrypted & 0xFF;
    encrypted >>>= 8;
  }
  return out;
}

/// Invierte el orden de los 8 bits de un byte (VNC usa esto para derivar la
/// clave DES: cada byte del password con bits al revés).
int reverseBits8(int b) {
  var r = 0;
  for (var i = 0; i < 8; i++) {
    r = (r << 1) | ((b >> i) & 1);
  }
  return r;
}

/// Deriva la clave DES de 8 bytes a partir del password VNC (RFC 6143 §7.1.2):
/// truncado/padded a 8 bytes + inversión de bits por byte.
Uint8List vncAuthKey(String password) {
  final key = Uint8List(8);
  final bytes = password.codeUnits; // ASCII/UTF-8 bytes esperados
  for (var i = 0; i < 8 && i < bytes.length; i++) {
    key[i] = reverseBits8(bytes[i] & 0xFF);
  }
  return key;
}

/// Responde al challenge de 16 bytes del servidor: 2 bloques DES/ECB con la
/// misma clave. Devuelve los 16 bytes de respuesta.
Uint8List vncAuthResponse(Uint8List challenge16, Uint8List key) {
  assert(challenge16.length == 16, 'VNC Auth challenge son 16 bytes');
  final response = Uint8List(16);
  final b1 = Uint8List.fromList(challenge16.sublist(0, 8));
  final b2 = Uint8List.fromList(challenge16.sublist(8, 16));
  response.setAll(0, desEncryptBlock(b1, key));
  response.setAll(8, desEncryptBlock(b2, key));
  return response;
}

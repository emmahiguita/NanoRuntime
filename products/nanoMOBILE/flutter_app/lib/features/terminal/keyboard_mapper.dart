import 'dart:convert';

import 'package:flutter/services.dart';

/// Traduce eventos de teclado (KeyEvent) a secuencias de bytes de terminal
/// (ANSI/VT100 escape codes) para el modo PTY interactivo.
///
/// Extraído de _TermState (SRP). Clase stateless — recibe LogicalKeyboardKey,
/// devuelve List<int>?. Sin dependencias de Flutter Widgets.
class KeyboardMapper {
  const KeyboardMapper();

  /// Traduce un KeyDownEvent a la secuencia de bytes de terminal (modo PTY).
  /// [ctrl] indica si la tecla Control está presionada al momento del evento.
  /// Devuelve null si la tecla no debe enviarse (modificadores sueltos, etc.).
  List<int>? keyToPtyBytes(LogicalKeyboardKey k, {bool ctrl = false}) {
    // Fila de función F1-F12
    if (k.keyId >= LogicalKeyboardKey.f1.keyId &&
        k.keyId <= LogicalKeyboardKey.f12.keyId) {
      final n = k.keyId - LogicalKeyboardKey.f1.keyId + 1;
      if (n == 1) return [0x1b, 0x4f, 0x50]; // F1
      if (n == 2) return [0x1b, 0x4f, 0x51]; // F2
      if (n == 3) return [0x1b, 0x4f, 0x52]; // F3
      if (n == 4) return [0x1b, 0x4f, 0x53]; // F4
      // F5-F12: ESC [15~ ... ESC [24~
      final fn = [15, 17, 18, 19, 20, 21, 23, 24][n - 5];
      final digits = '$fn'.codeUnits;
      return [0x1b, 0x5b, ...digits, 0x7e];
    }

    // Flechas
    if (k == LogicalKeyboardKey.arrowUp) return [0x1b, 0x5b, 0x41];
    if (k == LogicalKeyboardKey.arrowDown) return [0x1b, 0x5b, 0x42];
    if (k == LogicalKeyboardKey.arrowRight) return [0x1b, 0x5b, 0x43];
    if (k == LogicalKeyboardKey.arrowLeft) return [0x1b, 0x5b, 0x44];

    // Home/End/PageUp/PageDown
    if (k == LogicalKeyboardKey.home) return [0x1b, 0x5b, 0x48];
    if (k == LogicalKeyboardKey.end) return [0x1b, 0x5b, 0x46];
    if (k == LogicalKeyboardKey.pageUp) return [0x1b, 0x5b, 0x35, 0x7e];
    if (k == LogicalKeyboardKey.pageDown) return [0x1b, 0x5b, 0x36, 0x7e];

    // Insert/Del
    if (k == LogicalKeyboardKey.insert) return [0x1b, 0x5b, 0x32, 0x7e];
    if (k == LogicalKeyboardKey.delete) return [0x1b, 0x5b, 0x33, 0x7e];

    // Teclas de control
    if (k == LogicalKeyboardKey.enter) return [0x0d];
    if (k == LogicalKeyboardKey.tab) return [0x09];
    if (k == LogicalKeyboardKey.backspace) return [0x7f];
    if (k == LogicalKeyboardKey.escape) return [0x1b];
    if (k == LogicalKeyboardKey.space) return [0x20];

    // Modificadores solos: no envían nada
    if (k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight ||
        k == LogicalKeyboardKey.altLeft ||
        k == LogicalKeyboardKey.altRight ||
        k == LogicalKeyboardKey.metaLeft ||
        k == LogicalKeyboardKey.metaRight ||
        k == LogicalKeyboardKey.capsLock ||
        k == LogicalKeyboardKey.numLock) {
      return null;
    }

    // Ctrl+letra → byte de control (0x01-0x1a)
    if (ctrl) {
      final ch = logicalToChar(k);
      if (ch != null && ch >= 0x61 && ch <= 0x7a) return [ch - 0x60];
      if (ch != null && ch >= 0x41 && ch <= 0x5a) return [ch - 0x40];
      return null;
    }

    // Carácter imprimible (incluye mayúsculas con Shift).
    // P2: el codeUnit crudo >0x7F (teclado con símbolos locales) enviaba
    // un byte suelto inválido al PTY; hay que codificar UTF-8.
    final ch = logicalToChar(k);
    if (ch != null && ch >= 0x20) {
      if (ch <= 0x7F) return [ch];
      return utf8.encode(String.fromCharCode(ch));
    }
    return null;
  }

  /// Extrae el carácter simple de una tecla lógica (sin mods de control).
  int? logicalToChar(LogicalKeyboardKey k) {
    final kid = k.keyId;
    final chr = kid >= 0x20 && kid <= 0x7e ? kid : null;
    if (chr != null) return chr;
    // keyLabel como fallback (teclas con mayúsculas/símbolos locales)
    final label = k.keyLabel;
    if (label.isNotEmpty && label.length == 1) {
      final c = label.codeUnitAt(0);
      if (c >= 0x20) return c;
    }
    return null;
  }
}

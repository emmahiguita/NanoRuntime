import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'term_screen.dart';
import 'ansi_parser.dart';
part 'ansi_cell_metrics.part.dart';
part 'ansi_terminal_buffer.part.dart';
part 'ansi_terminal_view.part.dart';
part 'ansi_terminal_view_state.part.dart';
part 'ansi_terminal_line.part.dart';

// ============================================================================
// PALETA xterm 256 (16 base + 6x6x6 cube + 24 grises)
// ============================================================================
const List<int> _base16 = <int>[
  0x000000,
  0xCD0000,
  0x00CD00,
  0xCDCD00,
  0x0000EE,
  0xCD00CD,
  0x00CDCD,
  0xE5E5E5,
  0x7F7F7F,
  0xFF0000,
  0x00FF00,
  0xFFFF00,
  0x5C5CFF,
  0xFF00FF,
  0x00FFFF,
  0xFFFFFF,
];

final List<Color> _palette256 = _buildPalette();

List<Color> _buildPalette() {
  final out = <Color>[];
  for (var i = 0; i < 16; i++) {
    out.add(Color(0xff000000 | _base16[i]));
  }
  const levels = [0, 95, 135, 175, 215, 255];
  for (final r in levels) {
    for (final g in levels) {
      for (final b in levels) {
        out.add(Color.fromARGB(255, r, g, b));
      }
    }
  }
  for (var g = 0; g < 24; g++) {
    final v = 8 + g * 10;
    out.add(Color.fromARGB(255, v, v, v));
  }
  return out;
}

/// 255 = foreground por defecto (tema), 256 = fondo transparente.
Color _rfg(int idx, Color def) =>
    idx == 255 ? def : _palette256[idx >= 0 && idx < 256 ? idx : 255];
Color? _rbg(int idx) => idx == 256 ? null : _palette256[idx & 0xFF];

// ============================================================================
// MÉTRICAS DE CELDA REALES (medidas con TextPainter, no mágicos 7.6/20)
// ============================================================================

/// Eleva el contraste de colores ANSI sobre el fondo del tema, conservando su matiz.
/// Solo se aplica si el programa no eligió un fondo explícito ni vídeo inverso.
Color _readableAnsiForeground(
  Color source,
  Color background, {
  required bool dim,
}) {
  double ratio(Color color) {
    final effective = dim
        ? Color.alphaBlend(color.withValues(alpha: .6), background)
        : color;
    final a = effective.computeLuminance(), b = background.computeLuminance();
    return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
  }

  if (ratio(source) >= 4.5) return source;
  final target = ratio(Colors.black) > ratio(Colors.white)
      ? Colors.black
      : Colors.white;
  for (var step = 1; step <= 12; step++) {
    final candidate = Color.lerp(source, target, step / 12)!;
    if (ratio(candidate) >= 4.5) return candidate;
  }
  return target;
}

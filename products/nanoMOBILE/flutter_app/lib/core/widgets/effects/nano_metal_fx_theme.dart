// nano_metal_fx_theme.dart — Configuración y presets de refracción metálica líquida.
// QUÉ HACE: Define paletas de metales (titanium, chrome, gold, darkMetal) y factores de brillo para Metal FX.
// CÓMO FUNCIONA: Especifica listas de colores especulares y ángulos de luz.
// POR QUÉ: Permite dotar a botones y badges de la física de metal cepillado de Libraries.dev (< 80 líneas).
library;

import 'package:flutter/material.dart';

class NanoMetalFxPalette {
  final String name;
  final List<Color> surfaceColors;
  final Color highlightColor;
  final Color borderColor;

  const NanoMetalFxPalette({
    required this.name,
    required this.surfaceColors,
    required this.highlightColor,
    required this.borderColor,
  });

  /// Titanio espacial (Space Grey / Titanium de Nano AI).
  static const titanium = NanoMetalFxPalette(
    name: 'titanium',
    surfaceColors: [
      Color(0xFF1E2638),
      Color(0xFF2B354C),
      Color(0xFF161E2E),
      Color(0xFF334155),
    ],
    highlightColor: Color(0x6694A3B8),
    borderColor: Color(0xFF475569),
  );

  /// Cromo líquido reflectante.
  static const chrome = NanoMetalFxPalette(
    name: 'chrome',
    surfaceColors: [
      Color(0xFF3B4454),
      Color(0xFF64748B),
      Color(0xFF1E293B),
      Color(0xFF94A3B8),
    ],
    highlightColor: Color(0x88F8FAFC),
    borderColor: Color(0xFF94A3B8),
  );

  /// Oro cuántico pulido.
  static const gold = NanoMetalFxPalette(
    name: 'gold',
    surfaceColors: [
      Color(0xFF452E10),
      Color(0xFF785418),
      Color(0xFF3B2508),
      Color(0xFF926720),
    ],
    highlightColor: Color(0x88FDE047),
    borderColor: Color(0xFFD97706),
  );
}

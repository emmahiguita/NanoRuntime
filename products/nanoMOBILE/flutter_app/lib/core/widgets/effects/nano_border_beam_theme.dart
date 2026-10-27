// nano_border_beam_theme.dart — Paletas y presets para el efecto Border Beam de Libraries.dev.
// QUÉ HACE: Define variantes de color (colorful, ocean, sunset, mono), modos de animación (rotate, pulse) y física del haz.
// CÓMO FUNCIONA: Estructura inmutable desacoplada de la renderización en Canvas.
// POR QUÉ: Permite reutilizar el efecto Border Beam en tarjetas de modelos, ventanas flotantes y botones (< 100 líneas).
library;

import 'package:flutter/material.dart';

/// Modo de animación del haz lumínico perimetral.
enum NanoBorderBeamMode {
  /// Haz viajero perimetral con rotación continua en el borde exterior.
  rotate,

  /// Haz pulsante de respiración suave (pulse-inner).
  pulse,
}

/// Paleta cromática de alta fidelidad para el haz perimetral.
class NanoBorderBeamPalette {
  final String name;
  final List<Color> colors;
  final Color glowColor;

  const NanoBorderBeamPalette({
    required this.name,
    required this.colors,
    required this.glowColor,
  });

  /// Arcoíris dinámico espectral (Default en Libraries.dev / beam.jakubantalik.com).
  static const colorful = NanoBorderBeamPalette(
    name: 'colorful',
    colors: [
      Color(0xFF22D3EE), // Cyan
      Color(0xFF818CF8), // Indigo
      Color(0xFFEC4899), // Magenta / Rosa
      Color(0xFFF59E0B), // Ámbar
      Color(0xFF10B981), // Esmeralda
      Color(0xFF22D3EE), // Cierre de ciclo
    ],
    glowColor: Color(0x6622D3EE),
  );

  /// Gradiente oceánico cibernético (Nano AI).
  static const ocean = NanoBorderBeamPalette(
    name: 'ocean',
    colors: [
      Color(0xFF0284C7),
      Color(0xFF38BDF8),
      Color(0xFF6366F1),
      Color(0xFFA855F7),
      Color(0xFF0284C7),
    ],
    glowColor: Color(0x6638BDF8),
  );

  /// Puesta de sol cálida.
  static const sunset = NanoBorderBeamPalette(
    name: 'sunset',
    colors: [
      Color(0xFFF43F5E),
      Color(0xFFFB923C),
      Color(0xFFFBBF24),
      Color(0xFFE11D48),
      Color(0xFFF43F5E),
    ],
    glowColor: Color(0x66FB923C),
  );

  /// Metálico monocromo / Titanio.
  static const mono = NanoBorderBeamPalette(
    name: 'mono',
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFF94A3B8),
      Color(0xFF334155),
      Color(0xFF94A3B8),
      Color(0xFFF8FAFC),
    ],
    glowColor: Color(0x44CBD5E1),
  );
}

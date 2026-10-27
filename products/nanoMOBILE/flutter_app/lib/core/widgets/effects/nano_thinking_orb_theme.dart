// nano_thinking_orb_theme.dart — Estados y presets para Thinking Orbs de Libraries.dev.
// QUÉ HACE: Define los estados semánticos del agente AI (thinking, solving, searching, listening, composing, idle).
// CÓMO FUNCIONA: Asocia a cada estado un conjunto de velocidades orbitales, número de nodos y paleta luminosa.
// POR QUÉ: Permite feedback semántico rico en la interfaz en lugar de spinners genéricos (< 100 líneas).
library;

import 'package:flutter/material.dart';

/// Estados semánticos de Thinking Orbs según Libraries.dev.
enum NanoOrbState {
  idle,
  thinking,
  solving,
  searching,
  listening,
  composing,
}

class NanoOrbTheme {
  final NanoOrbState state;
  final List<Color> colors;
  final double speedMultiplier;
  final int dotCount;
  final double pulseIntensity;

  const NanoOrbTheme({
    required this.state,
    required this.colors,
    this.speedMultiplier = 1.0,
    this.dotCount = 7,
    this.pulseIntensity = 1.0,
  });

  /// Configuración calibrada según el estado del agente o modelo.
  static NanoOrbTheme forState(NanoOrbState state) {
    switch (state) {
      case NanoOrbState.idle:
        return const NanoOrbTheme(
          state: NanoOrbState.idle,
          colors: [Color(0xFF64748B), Color(0xFF94A3B8)],
          speedMultiplier: 0.6,
          dotCount: 5,
          pulseIntensity: 0.4,
        );
      case NanoOrbState.thinking:
        return const NanoOrbTheme(
          state: NanoOrbState.thinking,
          colors: [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFFA855F7)],
          speedMultiplier: 1.2,
          dotCount: 8,
          pulseIntensity: 1.1,
        );
      case NanoOrbState.solving:
        return const NanoOrbTheme(
          state: NanoOrbState.solving,
          colors: [Color(0xFF10B981), Color(0xFF06B6D4), Color(0xFF3B82F6)],
          speedMultiplier: 1.5,
          dotCount: 9,
          pulseIntensity: 1.3,
        );
      case NanoOrbState.searching:
        return const NanoOrbTheme(
          state: NanoOrbState.searching,
          colors: [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6)],
          speedMultiplier: 1.4,
          dotCount: 8,
          pulseIntensity: 1.0,
        );
      case NanoOrbState.listening:
        return const NanoOrbTheme(
          state: NanoOrbState.listening,
          colors: [Color(0xFF06B6D4), Color(0xFF22D3EE), Color(0xFFE0E7FF)],
          speedMultiplier: 1.0,
          dotCount: 6,
          pulseIntensity: 1.4,
        );
      case NanoOrbState.composing:
        return const NanoOrbTheme(
          state: NanoOrbState.composing,
          colors: [Color(0xFFA855F7), Color(0xFFEC4899), Color(0xFFFB7185)],
          speedMultiplier: 1.3,
          dotCount: 9,
          pulseIntensity: 1.2,
        );
    }
  }
}

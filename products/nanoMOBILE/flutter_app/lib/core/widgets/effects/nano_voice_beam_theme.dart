// nano_voice_beam_theme.dart — Paletas y configuración para el efecto VoiceBeam.
// QUÉ HACE: Define las paletas cromáticas, modos de geometría y envolvente física de audio.
// CÓMO FUNCIONA: Estructura inmutable con gradientes inspirados en iOS / Libraries.dev (Cyber, Sunset, Emerald).
// POR QUÉ: Permite desacoplar el renderizado del CustomPainter de los valores de diseño y temas (< 200 líneas).
library;

import 'package:flutter/material.dart';

/// Preset geométrico del efecto VoiceBeam.
enum NanoVoiceBeamType {
  /// Borde inferior para campos de texto / barras de chat (~350px).
  input,

  /// Cápsula compacta para grabación flotante o notas de voz (~160x44px).
  pill,

  /// Borde inferior de la pantalla completa (estilo Siri / Google Gemini Live).
  screenEdge,
}

/// Paleta de colores para el halo de voz y el haz de pensamiento.
class NanoVoiceBeamPalette {
  const NanoVoiceBeamPalette({
    required this.name,
    required this.colors,
    required this.glowColor,
    required this.beamColor,
  });

  final String name;
  final List<Color> colors;
  final Color glowColor;
  final Color beamColor;

  /// Paleta Cyber Cósmica (Identidad nativa de Nano AI: Cyan, Azul Eléctrico y Púrpura).
  static const cyber = NanoVoiceBeamPalette(
    name: 'cyber',
    colors: [
      Color(0xFF22D3EE), // Cyan
      Color(0xFF38BDF8), // Light Sky
      Color(0xFF3B82F6), // Electric Blue
      Color(0xFF818CF8), // Indigo
      Color(0xFFA855F7), // Purple
    ],
    glowColor: Color(0x6622D3EE),
    beamColor: Color(0xFF67E8F9),
  );

  /// Paleta Sunset (Magenta, Naranja cálido y Ámbar).
  static const sunset = NanoVoiceBeamPalette(
    name: 'sunset',
    colors: [
      Color(0xFFEC4899),
      Color(0xFFF43F5E),
      Color(0xFFF97316),
      Color(0xFFF59E0B),
    ],
    glowColor: Color(0x66EC4899),
    beamColor: Color(0xFFFDE047),
  );

  /// Paleta Esmeralda / Aurora (Verde Neón, Menta y Turquesa).
  static const emerald = NanoVoiceBeamPalette(
    name: 'emerald',
    colors: [
      Color(0xFF10B981),
      Color(0xFF34D399),
      Color(0xFF2DD4BF),
      Color(0xFF06B6D4),
    ],
    glowColor: Color(0x6610B981),
    beamColor: Color(0xFF6EE7B7),
  );
}

/// Configuración física de envolvente de audio para respuesta natural al habla.
class NanoVoiceBeamPhysics {
  const NanoVoiceBeamPhysics({
    this.gain = 1.4,
    this.noiseFloor = 0.04,
    this.maxBloomHeight = 32.0,
    this.beamThickness = 2.5,
  });

  /// Multiplicador de sensibilidad para detectar susurros o habla baja.
  final double gain;

  /// Umbral de ruido ambiente bajo el cual el halo permanece reposado.
  final double noiseFloor;

  /// Altura máxima del halo cuando el volumen RMS alcanza su punto máximo.
  final double maxBloomHeight;

  /// Grosor de la línea del haz de luz oscilante.
  final double beamThickness;
}

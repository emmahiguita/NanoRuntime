// nano_voice_wave.dart — Visualizador de onda de voz en tiempo real.
// QUÉ: 17 barras verticales animadas que responden al nivel RMS del micrófono.
// CÓMO: AnimationController de fase + ValueListenable de audioLevel → CustomPaint.
//       Listenable.merge combina ambas fuentes en un solo rebuild.
// POR QUÉ: CustomPainter es más eficiente que N widgets AnimatedContainer;
//          shouldRepaint evita redraws cuando los valores no cambian.
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NanoVoiceWave extends StatefulWidget {
  const NanoVoiceWave({super.key, required this.audioLevel});

  /// Nivel RMS normalizado entre 0.0 y 1.0 — proviene del micrófono real.
  final ValueListenable<double> audioLevel;

  @override
  State<NanoVoiceWave> createState() => _NanoVoiceWaveState();
}

class _NanoVoiceWaveState extends State<NanoVoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController phase;

  @override
  void initState() {
    super.initState();
    // Ciclo de 900ms → frecuencia de onda natural, sin parpadeo.
    phase = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Accesibilidad: sustituye animación por ícono estático.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const Icon(Icons.graphic_eq_rounded, color: Color(0xFF1675DB));
    }
    return RepaintBoundary(
      child: SizedBox(
        width: 86,
        height: 29,
        child: AnimatedBuilder(
          // Escucha fase + nivel para reconstruir solo cuando alguno cambia.
          animation: Listenable.merge([phase, widget.audioLevel]),
          builder: (context, _) => CustomPaint(
            painter: _WavePainter(phase.value, widget.audioLevel.value),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.phase, this.level);

  final double phase, level;

  @override
  void paint(Canvas canvas, Size size) {
    final volume = level.clamp(0.0, 1.0);
    final pen = Paint()
      ..color = const Color(0xFF187DFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const bars = 17;
    for (var i = 0; i < bars; i++) {
      final x = i * size.width / (bars - 1);
      // Envelope senoidal: barras del centro más altas que los extremos.
      final envelope = math.sin(math.pi * i / (bars - 1));
      // Onda de fase: cada barra se mueve en momento diferente.
      final wave = 0.55 + 0.45 * math.sin(phase * 2 * math.pi + i * 0.63).abs();
      // Altura mínima 3px; máximo cuando volume=1 y envelope=1.
      final h = 3 + volume * 23 * envelope * wave;
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.phase != phase || old.level != level;
}

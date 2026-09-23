// nano_voice_wave.dart — Onda de voz animada conectada al nivel real del micrófono.
// QUÉ: 17 barras verticales animadas por el RMS normalizado (0..1) del micrófono.
// CÓMO: AnimationController de fase (900ms) + ValueListenable<double> del audio.
//       CustomPainter redibuja solo cuando cambian fase o nivel (shouldRepaint).
// POR QUÉ: audioLevel debe venir del RMS real, no de valores falsos.
//          RepaintBoundary aisla el pintor continuo del árbol de widgets.
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// audioLevel debe provenir del RMS normalizado real (0..1) del micrófono.
class NanoVoiceWave extends StatefulWidget {
  const NanoVoiceWave({super.key, required this.audioLevel});
  final ValueListenable<double> audioLevel;
  @override
  State<NanoVoiceWave> createState() => _NanoVoiceWaveState();
}

class _NanoVoiceWaveState extends State<NanoVoiceWave>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController phase;
  bool _foreground = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    phase = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  /// Ocultar el pintor no detiene su ticker; pausarlo evita trabajo invisible.
  void _syncMotion() {
    if (_foreground && !_reduceMotion) {
      if (!phase.isAnimating) phase.repeat();
    } else {
      phase.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Accesibilidad: si animaciones reducidas, mostrar ícono estático.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const Icon(Icons.graphic_eq_rounded, color: Color(0xFF1675DB));
    }
    return RepaintBoundary(
      child: SizedBox(
        width: 86,
        height: 29,
        child: AnimatedBuilder(
          animation: Listenable.merge([phase, widget.audioLevel]),
          builder: (context, child) =>
              CustomPaint(painter: _WavePainter(phase.value, widget.audioLevel.value)),
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
      final envelope = math.sin(math.pi * i / (bars - 1));
      final phaseWave = .55 + .45 * math.sin(phase * 2 * math.pi + i * .63).abs();
      final h = 3 + volume * 23 * envelope * phaseWave;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), pen);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.phase != phase || old.level != level;
}

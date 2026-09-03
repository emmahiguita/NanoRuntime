// Generador de los WAVs armónicos del búho (TER-22).
//
// Sintetiza assets/sounds/owl_glide.wav (glissando ascendente al soltar)
// y assets/sounds/owl_land.wav (nota descendente al posarse).
//
// Uso: dart run tools/gen_owl_sounds.dart
//
// PCM 16-bit mono 44.1 kHz. Consonancia: fundamental + quinta (1.5x) +
// octava (2x) con amplitudes decrecientes. Envelope con fade in/out
// para cero clicks. Fase integrada por muestra (sin discontinuidades).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 44100;

/// Escala 0..1 de duración por easing.
double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
double _easeInCubic(double t) => math.pow(t, 3).toDouble();

/// Sintetiza una nota con barrido de frecuencia + armónicos consonantes.
List<int> _synth({
  required double durationMs,
  required double f0Start,
  required double f0End,
  required double Function(double) ease,
  required double peak,
  double attackMs = 50,
  double fadeOutMs = 160,
}) {
  final n = (durationMs / 1000 * _sampleRate).round();
  final samples = List<int>.filled(n, 0);

  var phase1 = 0.0; // fundamental
  var phase2 = 0.0; // quinta
  var phase3 = 0.0; // octava

  for (var i = 0; i < n; i++) {
    final t = i / math.max(1, n - 1);
    final f0 = f0Start + (f0End - f0Start) * ease(t);
    const dt = 1 / _sampleRate;

    // Envelope: attack suave + release en los últimos ms.
    var env = 1.0;
    if (i < attackMs / 1000 * _sampleRate) {
      env = i / (attackMs / 1000 * _sampleRate);
    }
    final remaining = (n - 1 - i) / _sampleRate * 1000;
    if (remaining < fadeOutMs) {
      env = math.min(env, remaining / fadeOutMs);
    }
    // Curva de percepción: env^1.4 suaviza la cola.
    env = math.pow(env, 1.4).toDouble();

    phase1 += 2 * math.pi * f0 * dt;
    phase2 += 2 * math.pi * f0 * 1.5 * dt;
    phase3 += 2 * math.pi * f0 * 2.0 * dt;

    final v =
        math.sin(phase1) + 0.5 * math.sin(phase2) + 0.28 * math.sin(phase3);
    final sample = (v * peak * env * 32767).round().clamp(-32768, 32767);
    samples[i] = sample;
  }
  return samples;
}

/// Escribe un WAV PCM 16-bit mono con header canónico de 44 bytes.
void _writeWav(String path, List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  final bytes = data.buffer.asUint8List();
  final file = File(path);
  final out = BytesBuilder(copy: false);

  void ascii(String s) => out.add(s.codeUnits);
  void u32(int v) => out.add([
    v & 0xFF,
    (v >> 8) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 24) & 0xFF,
  ]);
  void u16(int v) => out.add([v & 0xFF, (v >> 8) & 0xFF]);

  ascii('RIFF');
  u32(36 + bytes.length);
  ascii('WAVE');
  ascii('fmt ');
  u32(16); // tamaño fmt
  u16(1); // PCM
  u16(1); // mono
  u32(_sampleRate);
  u32(_sampleRate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits
  ascii('data');
  u32(bytes.length);
  out.add(bytes);

  file.writeAsBytesSync(out.toBytes());
}

void main() {
  final dir = Directory('assets/sounds');
  dir.createSync(recursive: true);

  // Glide: 620 ms, ascenso 320 -> 760 Hz. El despegue "respira" y sube.
  _writeWav(
    'assets/sounds/owl_glide.wav',
    _synth(
      durationMs: 620,
      f0Start: 320,
      f0End: 760,
      ease: _easeOutCubic,
      peak: 0.32,
    ),
  );

  // Pose: 360 ms, descenso 540 -> 360 Hz. Se posa y asienta.
  _writeWav(
    'assets/sounds/owl_land.wav',
    _synth(
      durationMs: 360,
      f0Start: 540,
      f0End: 360,
      ease: _easeInCubic,
      peak: 0.26,
      fadeOutMs: 150,
    ),
  );

  stdout.writeln('WAVs generados en assets/sounds/');
}

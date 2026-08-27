/// NanoVoiceOrb (A16) — indicador profesional del estado de voz (presentación
/// pura, sin acoplarse a un backend concreto).
///
/// Refleja [VoiceSessionState]:
/// - idle/wakeListening: estático con micrófono.
/// - listening: pulso (escala oscilante + halo).
/// - speaking: ondas (glow intenso).
/// - processing: anillo.
/// - error: color de peligro.
///
/// No ejecuta lógica de agente: el llamador provee [state] y [onTap].
library;

import 'package:flutter/material.dart';

import '../../engine/voice/voice_runtime.dart';
import '../../../../core/theme/design_tokens.dart';

class NanoVoiceOrb extends StatefulWidget {
  const NanoVoiceOrb({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 96,
  });

  final VoiceSessionState state;
  final VoidCallback onTap;
  final double size;

  @override
  State<NanoVoiceOrb> createState() => _NanoVoiceOrbState();
}

class _NanoVoiceOrbState extends State<NanoVoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final t = _controller.value; // 0..1 oscilante

    final (color, scale, showRing) = switch (widget.state) {
      VoiceSessionState.listening ||
      VoiceSessionState.wakeListening => (colors.accent, 1.0 + 0.18 * t, true),
      VoiceSessionState.speaking => (colors.accentCyan, 1.0 + 0.10 * t, true),
      VoiceSessionState.processing => (colors.info, 1.0, true),
      VoiceSessionState.error => (colors.danger, 1.0, false),
      _ => (colors.onSurfaceVariant, 1.0, false),
    };

    return Semantics(
      button: true,
      label: widget.state == VoiceSessionState.speaking
          ? 'Nano hablando'
          : 'Activar voz',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (showRing)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => Container(
                    width: widget.size * (1.0 + 0.25 * t),
                    height: widget.size * (1.0 + 0.25 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12 * (1 - t)),
                    ),
                  ),
                ),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size * 0.72,
                    height: widget.size * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [color, color.withValues(alpha: 0.65)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.55),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.state == VoiceSessionState.speaking
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: widget.size * 0.34,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

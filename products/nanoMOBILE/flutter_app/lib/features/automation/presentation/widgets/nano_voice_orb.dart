/// NanoVoiceOrb (A16) — indicador profesional del estado de voz.
///
/// Un orb animado que refleja la máquina de estados del [VoiceSessionManager]:
/// - idle/wakeListening: estático con micrófono (toca para hablar).
/// - listening: pulso (escala oscilante + glow).
/// - speaking: ondas (glow intenso).
/// - processing: anillo girando.
/// - error: color de peligro.
///
/// No ejecuta lógica de agente: solo escucha el stream y llama [onMicTap].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/voice/voice_runtime.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/nano_type.dart';

class NanoVoiceOrb extends StatefulWidget {
  const NanoVoiceOrb({
    super.key,
    required this.session,
    this.onMicTap,
    this.size = 96,
  });

  final VoiceSessionManager session;

  /// Callback al tocar el orb (típicamente inicia la escucha). null = usa
  /// [VoiceSessionManager.pushToTalk] y descarta el turno.
  final Future<void> Function()? onMicTap;
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

  StreamSubscription<VoiceSessionState>? _sub;
  VoiceSessionState _state = VoiceSessionState.idle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _state = widget.session.state;
    _sub = widget.session.states.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    _busy = true;
    try {
      if (widget.onMicTap != null) {
        await widget.onMicTap!();
      } else {
        await widget.session.pushToTalk();
      }
    } finally {
      if (mounted) _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final t = _controller.value; // 0..1 oscilante

    final (color, scale, showRing) = switch (_state) {
      VoiceSessionState.listening ||
      VoiceSessionState.wakeListening => (colors.accent, 1.0 + 0.18 * t, true),
      VoiceSessionState.speaking => (colors.accentCyan, 1.0 + 0.10 * t, true),
      VoiceSessionState.processing => (colors.info, 1.0, true),
      VoiceSessionState.error => (colors.danger, 1.0, false),
      _ => (colors.onSurfaceVariant, 1.0, false),
    };

    return Semantics(
      button: true,
      label: _state == VoiceSessionState.speaking
          ? 'Nano hablando'
          : 'Activar voz',
      child: GestureDetector(
        onTap: _handleTap,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo exterior (onda cuando activo).
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
              // Orb principal.
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
                      _state == VoiceSessionState.speaking
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

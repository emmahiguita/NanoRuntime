// nano_thinking_orb.dart — Widget autónomo de Thinking Orbs.
// QUÉ HACE: Muestra el indicador punteado de razonamiento de IA para estados de carga y procesamiento.
// CÓMO FUNCIONA: AnimationController cíclico, gestión de ciclo de vida en segundo plano y accesibilidad semántica.
// POR QUÉ: Reemplaza spinners mecánicos por el componente característico de AI Agent de Libraries.dev (< 110 líneas).
library;

import 'package:flutter/material.dart';
import 'nano_thinking_orb_painter.dart';
import 'nano_thinking_orb_theme.dart';

class NanoThinkingOrb extends StatefulWidget {
  final NanoOrbState state;
  final double size;
  final String? semanticLabel;

  const NanoThinkingOrb({
    super.key,
    this.state = NanoOrbState.thinking,
    this.size = 28.0,
    this.semanticLabel,
  });

  @override
  State<NanoThinkingOrb> createState() => _NanoThinkingOrbState();
}

class _NanoThinkingOrbState extends State<NanoThinkingOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final theme = NanoOrbTheme.forState(widget.state);

    return Semantics(
      label: widget.semanticLabel ?? 'AI Agent ${widget.state.name}',
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: disableAnim
              ? CustomPaint(
                  painter: NanoThinkingOrbPainter(animationValue: 0.5, theme: theme),
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: NanoThinkingOrbPainter(
                      animationValue: _controller.value,
                      theme: theme,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

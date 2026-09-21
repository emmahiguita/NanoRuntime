// nano_floating_assistant.dart — Widget flotante del búho dentro de la app.
// QUÉ: Stack posicionable con búho animado + panel expandible.
// CÓMO: LayoutBuilder para bounds reales; clampeo en drag Y en panEnd.
//       AnimatedSize para transición suave entre colapsado/expandido.
// BUG CORREGIDO: posición clampea durante onPanUpdate (no solo en onPanEnd)
//   → el búho nunca sale de la pantalla mientras se arrastra.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'nano_ai_controller.dart';
import 'nano_assistant_panel.dart';
import 'nano_glass.dart';
import 'nano_owl_alive.dart';

/// Insertar en un Stack raíz de la app; el overlay del sistema es aparte.
class NanoFloatingAssistant extends StatefulWidget {
  const NanoFloatingAssistant({
    super.key,
    required this.controller,
    required this.audioLevel,
    this.onVoice,
    this.initiallyExpanded = false,
  });

  final NanoAiController controller;
  final ValueListenable<double> audioLevel;
  final VoidCallback? onVoice;
  final bool initiallyExpanded;

  @override
  State<NanoFloatingAssistant> createState() => _NanoFloatingAssistantState();
}

class _NanoFloatingAssistantState extends State<NanoFloatingAssistant> {
  late final TextEditingController _input;
  late bool _expanded;
  Offset _position = const Offset(16, 110);

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _input = TextEditingController();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant NanoFloatingAssistant old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    // Si llega un prompt del overlay nativo, expandir y rellenar el campo.
    final prompt = widget.controller.takePendingPrompt();
    if (prompt != null) {
      _input.text = prompt;
      _expanded = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noAnim = MediaQuery.disableAnimationsOf(context);
    final window = MediaQuery.sizeOf(context);
    return LayoutBuilder(builder: (context, box) {
      final maxW = box.maxWidth.isFinite ? box.maxWidth : window.width;
      final maxH = box.maxHeight.isFinite ? box.maxHeight : window.height;
      final w = _expanded ? (maxW - 12).clamp(1.0, 380.0) : 78.0;
      final h = _expanded ? (maxH - 12).clamp(85.0, 550.0) : 85.0;

      // Clampeo de posición considerando el ancho/alto actual del widget.
      final l = _position.dx.clamp(4.0, (maxW - w - 4).clamp(4.0, maxW));
      final t = _position.dy.clamp(4.0, (maxH - h - 4).clamp(4.0, maxH));

      return Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: l,
          top: t,
          child: AnimatedSize(
            alignment: Alignment.topCenter,
            duration: noAnim ? Duration.zero : NanoMotionDurations.hero,
            curve: NanoMotionCurves.glassSpring,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                // Panel expandido (detrás del búho para que el owl quede encima).
                if (_expanded)
                  Positioned.fill(
                    top: 49,
                    child: SingleChildScrollView(
                      child: NanoAssistantPanel(
                        controller: widget.controller,
                        input: _input,
                        audioLevel: widget.audioLevel,
                        onVoice: widget.onVoice,
                        onCollapse: () => setState(() => _expanded = false),
                      ),
                    ),
                  ),
                // Fondo glass cuando colapsado.
                if (!_expanded)
                  const Positioned(
                    left: 5,
                    top: 9,
                    child: NanoGlass(
                      radius: 40,
                      child: SizedBox(width: 67, height: 67),
                    ),
                  ),
                // Búho — arrastrable y tappeable.
                Positioned(
                  left: _expanded ? (w - 112) / 2 : 6,
                  top: _expanded ? -5 : 6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _expanded = !_expanded);
                    },
                    onPanUpdate: (d) => setState(() {
                      // BUG CORREGIDO: clampear durante drag, no solo al soltar.
                      final nx = (_position.dx + d.delta.dx)
                          .clamp(4.0, (maxW - w - 4).clamp(4.0, maxW));
                      final ny = (_position.dy + d.delta.dy)
                          .clamp(4.0, (maxH - h - 4).clamp(4.0, maxH));
                      _position = Offset(nx, ny);
                    }),
                    onPanEnd: (_) => setState(() {
                      // Snap al borde más cercano (izquierda o derecha).
                      final cx = _position.dx + w / 2;
                      _position = Offset(
                        cx < maxW / 2
                            ? 6.0
                            : (maxW - w - 6).clamp(6.0, maxW),
                        _position.dy.clamp(4.0, (maxH - h - 4).clamp(4.0, maxH)),
                      );
                    }),
                    child: Semantics(
                      label: 'Nano: '
                          '${_expanded ? 'contraer' : 'abrir'}, '
                          'arrastrar para mover',
                      button: true,
                      child: NanoOwlAlive(
                        size: _expanded ? 112 : 66,
                        activity: widget.controller.activity,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]);
    });
  }
}

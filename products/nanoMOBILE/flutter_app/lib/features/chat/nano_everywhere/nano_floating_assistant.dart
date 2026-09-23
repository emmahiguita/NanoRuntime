// nano_floating_assistant.dart — Asistente flotante bajo demanda (no permanente).
// QUÉ HACE: Despliega al Búho Nano únicamente cuando el usuario lo invoca explícitamente.
// CÓMO FUNCIONA: Mantiene `isVisible = false` por defecto; al cerrarse se oculta por completo sin dejar orbes fijos.
// POR QUÉ: Erradica la presencia permanente e intrusiva del personaje sobre el contenido de la pantalla.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_ai_controller.dart';
import 'nano_assistant_panel.dart';
import 'nano_motion.dart';
import 'nano_owl_alive.dart';
import 'nano_owl_orbital_ring.dart';

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
  late final TextEditingController input;
  late bool expanded;
  bool isVisible = false;
  bool _dragging = false;
  Offset position = const Offset(12, 300);

  @override
  void initState() {
    super.initState();
    expanded = widget.initiallyExpanded;
    isVisible = widget.controller.isVisible;
    input = TextEditingController();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(covariant NanoFloatingAssistant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_sync);
    widget.controller.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    if (widget.controller.checkAndClearExpandRequest()) {
      expanded = true;
      isVisible = true;
    }
    if (widget.controller.isVisible != isVisible) {
      isVisible = widget.controller.isVisible;
    }
    final pending = widget.controller.takePendingPrompt();
    if (pending != null) {
      input.text = pending;
      expanded = true;
      isVisible = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    input.dispose();
    super.dispose();
  }

  void _dismissAssistant() {
    HapticFeedback.lightImpact();
    setState(() {
      expanded = false;
      isVisible = false;
    });
    widget.controller.hide();
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final window = MediaQuery.sizeOf(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (_, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : window.width;
        final h = box.maxHeight.isFinite ? box.maxHeight : window.height;
        final double width = expanded
            ? (w - 24).clamp(0.0, 390.0).toDouble()
            : 76.0;
        final double height = expanded
            ? (h - 24).clamp(0.0, 560.0).toDouble()
            : 76.0;
        final maxX = (w - width).clamp(0.0, w).toDouble();
        final maxY = (h - height - 12).clamp(0.0, h).toDouble();
        final x = position.dx.clamp(0.0, maxX).toDouble();
        final y = position.dy.clamp(0.0, maxY).toDouble();

        return Stack(
          children: [
            AnimatedPositioned(
              key: ValueKey(expanded),
              duration: reduce || _dragging ? Duration.zero : NanoMotion.morph,
              curve: NanoMotion.smooth,
              left: x,
              top: y,
              width: width,
              height: height,
              child: expanded
                  ? NanoAssistantPanel(
                      controller: widget.controller,
                      input: input,
                      audioLevel: widget.audioLevel,
                      onVoice: widget.onVoice,
                      onCollapse: _dismissAssistant,
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => expanded = true);
                          },
                          onPanStart: (_) => setState(() => _dragging = true),
                          onPanCancel: () => setState(() => _dragging = false),
                          onPanUpdate: (d) => setState(() {
                            position = Offset(
                              (x + d.delta.dx).clamp(0.0, maxX),
                              (y + d.delta.dy).clamp(0.0, maxY),
                            );
                          }),
                          onPanEnd: (_) => setState(() => _dragging = false),
                          child: NanoOwlOrbitalRing(
                            size: 76,
                            activity: widget.controller.activity,
                            child: NanoOwlAlive(
                              size: 64,
                              activity: widget.controller.activity,
                            ),
                          ),
                        ),
                        // Botón de cierre para despedir al Búho cuando está en orbe
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _dismissAssistant,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xEE090D16),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

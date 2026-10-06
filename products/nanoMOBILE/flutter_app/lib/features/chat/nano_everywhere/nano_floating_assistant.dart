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
import 'nano_floating_orb.dart';
import 'nano_motion.dart';

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

  // BUG-07 FIX: Detecta rotaciones para reanclar el orbe.
  // position = Offset(12, 300) en portrait queda fuera de pantalla en landscape
  // (height < 300). didChangeDependencies se llama en cada cambio de MediaQuery,
  // incluyendo rotaciones, sin necesitar listener externo.
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    expanded = widget.initiallyExpanded;
    isVisible = widget.controller.isVisible;
    input = TextEditingController();
    widget.controller.addListener(_sync);
  }

  // QUÉ: Reancla el orbe a una posición segura al cambiar orientación.
  // CÓMO: Compara la orientación actual con la última conocida; si cambió,
  //       reposiciona a (12, altura*0.35) que es seguro en portrait y landscape.
  // POR QUÉ: Sin esto, el orbe "salta" o queda invisible al rotar el dispositivo.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ori = MediaQuery.orientationOf(context);
    if (_lastOrientation != null && _lastOrientation != ori) {
      final size = MediaQuery.sizeOf(context);
      setState(() {
        position = Offset(12, size.height * 0.35);
      });
    }
    _lastOrientation = ori;
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
        // QUÉ HACE: Calcula dimensiones adaptativas para retrato y modo horizontal (landscape).
        // CÓMO FUNCIONA: Si el ancho supera el alto (`isLandscape`), reduce el tamaño del
        //   orbe (62px) y limita el panel expandido a una ventana compacta lateral (máx 310px alto).
        // POR QUÉ: Evita que el asistente flotante tape toda la pantalla o se solape con el dock en horizontal.
        final w = box.maxWidth.isFinite ? box.maxWidth : window.width;
        final h = box.maxHeight.isFinite ? box.maxHeight : window.height;
        final isLandscape = w > h;
        final orbSize = isLandscape ? 62.0 : 76.0;
        final double width = expanded
            ? (isLandscape ? (w * 0.48).clamp(280.0, 410.0) : (w - 24).clamp(0.0, 390.0)).toDouble()
            : orbSize;
        final double height = expanded
            ? (isLandscape ? (h - 20).clamp(190.0, 310.0) : (h - 24).clamp(0.0, 560.0)).toDouble()
            : orbSize;
        final maxX = (w - width - 8).clamp(0.0, w).toDouble();
        final maxY = (h - height - 12).clamp(0.0, h).toDouble();
        final x = position.dx.clamp(8.0, maxX > 8.0 ? maxX : 8.0).toDouble();
        final y = position.dy.clamp(8.0, maxY > 8.0 ? maxY : 8.0).toDouble();

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
                  : NanoFloatingOrb(
                      activity: widget.controller.activity,
                      onTap: () => setState(() => expanded = true),
                      onDismiss: _dismissAssistant,
                      onPanStart: (_) => setState(() => _dragging = true),
                      onPanCancel: () => setState(() => _dragging = false),
                      onPanUpdate: (d) => setState(() {
                        position = Offset(
                          (x + d.delta.dx).clamp(0.0, maxX),
                          (y + d.delta.dy).clamp(0.0, maxY),
                        );
                      }),
                      onPanEnd: (_) => setState(() => _dragging = false),
                    ),
            ),
          ],
        );
      },
    );
  }
}

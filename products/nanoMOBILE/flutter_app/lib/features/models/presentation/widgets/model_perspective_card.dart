// model_perspective_card.dart — Tarjeta con perspectiva 3D, flip interactivo y Hero.
// QUÉ HACE: Renderiza la tarjeta con portada 3D a la izquierda, textos sueltos a la derecha y Hero.
// CÓMO FUNCIONA: Aplica rotación tridimensional en el eje Y (Matrix4 m44), flip anverso/reverso y vuelo Hero.
// POR QUÉ: conserva las transiciones existentes; el anverso se mantiene en una parte breve.
library;

import 'dart:math' as math;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'model_3d_flip_flight.dart';
import 'model_3d_logo_box.dart';
import 'model_card_action_button.dart';
import 'model_catalog_types.dart';
import 'model_download_progress.dart';
import 'model_perspective_back.dart';

part 'model_perspective_front.part.dart';

class ModelPerspectiveCard extends StatefulWidget {
  final UnifiedModelItem item;
  final bool isActive, isLoading;
  final ModelUiStatus status;
  final VoidCallback onTapDetails;
  final VoidCallback? onUse, onDownload, onCancel, onUnload, onDelete;

  const ModelPerspectiveCard({
    super.key,
    required this.item,
    required this.isActive,
    required this.isLoading,
    required this.status,
    required this.onTapDetails,
    this.onUse,
    this.onDownload,
    this.onCancel,
    this.onUnload,
    this.onDelete,
  });

  @override
  State<ModelPerspectiveCard> createState() => _ModelPerspectiveCardState();
}

class _ModelPerspectiveCardState extends State<ModelPerspectiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_showBack) {
      _flipController.reverse();
      setState(() => _showBack = false);
    } else {
      _flipController.forward();
      setState(() => _showBack = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Hero(
        tag: 'model-card-${widget.item.name}',
        createRectTween: (begin, end) =>
            MaterialRectCenterArcTween(begin: begin, end: end),
        flightShuttleBuilder: model3DCardFlipFlight,
        child: Material(
          color: Colors.transparent,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, _) {
                final angle = _flipAnimation.value;
                final isFlipped = angle >= (math.pi / 2);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, -0.0011)
                    ..rotateY(angle),
                  child: isFlipped
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: ModelPerspectiveBack(
                            item: widget.item,
                            onFlipBack: _toggleFlip,
                          ),
                        )
                      : _buildFront(colors),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

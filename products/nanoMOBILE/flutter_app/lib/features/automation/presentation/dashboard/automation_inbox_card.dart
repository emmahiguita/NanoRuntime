// automation_inbox_card.dart — Banner interactivo oficial del Centro de Mensajería.
// QUÉ HACE: Presenta la ilustración original 16:9 de mensajería con acabado iOS Liquid Glass.
// CÓMO FUNCIONA: Aplica recorte de radio 18, borde hairline, sombra ambiental y respuesta táctil.
// POR QUÉ: Conserva el arte oficial íntegro sin giros 3D distractores ni distorsión de píxeles.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/nano_motion_tokens.dart';
import '../automation_visual_theme.dart';

class AutomationInboxCard extends StatefulWidget {
  final VoidCallback onTap;

  const AutomationInboxCard({super.key, required this.onTap});

  @override
  State<AutomationInboxCard> createState() => _AutomationInboxCardState();
}

class _AutomationInboxCardState extends State<AutomationInboxCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final reduceMotion = NanoMotionTokens.reduceMotion(context);

    return Semantics(
      button: true,
      label: 'Abrir Centro de Mensajería',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: reduceMotion
              ? Duration.zero
              : NanoMotionTokens.touchResponse,
          curve: NanoMotionTokens.touchPress,
          child: AspectRatio(
            aspectRatio: isLandscape ? 2.3 : (16 / 9),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: visual.cardBorder.withValues(alpha: 0.75),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: visual.shadow,
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.asset(
                  'assets/promo/card_messaging_crystal.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../automation_visual_theme.dart';

/// Encabezado adaptable del perfil. El estado corresponde a la regla guardada,
/// no promete permisos del sistema ni entrega de mensajes comprobada.
class NanoPersonalHeader extends StatelessWidget {
  const NanoPersonalHeader({
    super.key,
    this.isActive = false,
    this.activeChannels = const [],
    this.compact = false,
  });
  final bool isActive, compact;
  final List<String> activeChannels;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 0 : 4, 20, compact ? 6 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nano Personal',
            style: TextStyle(
              color: visual.text,
              fontSize: compact ? 20 : 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 5),
            Text(
              'Tu identidad, agenda y forma de responder.',
              style: TextStyle(color: visual.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              isActive
                  ? 'WhatsApp · regla habilitada'
                  : 'WhatsApp · regla desactivada',
              style: TextStyle(color: visual.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

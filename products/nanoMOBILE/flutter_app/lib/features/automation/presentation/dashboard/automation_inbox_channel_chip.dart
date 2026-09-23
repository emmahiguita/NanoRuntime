// automation_inbox_channel_chip.dart — Píldoras de canales de mensajería (M3 Expressive).
// QUÉ HACE: Renderiza la insignia compacta de cada canal conectado (WhatsApp, Telegram, Shizuku).
// CÓMO FUNCIONA: Muestra un punto de estado de color y la etiqueta del canal con borde sutil.
// POR QUÉ: Extraído para mantener el tamaño de archivo < 200 líneas respetando Clean Architecture.
library;

import 'package:flutter/material.dart';

class AutomationInboxChannelChip extends StatelessWidget {
  final String label;
  final Color dotColor;
  const AutomationInboxChannelChip({super.key, required this.label, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

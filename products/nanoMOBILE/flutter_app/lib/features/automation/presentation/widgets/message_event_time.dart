import 'package:flutter/material.dart';

/// Presenta el instante registrado; no inventa una fecha cuando el origen la omite.
class MessageEventTime extends StatelessWidget {
  final int? timestampMs;
  final Color color;
  const MessageEventTime({
    super.key,
    required this.timestampMs,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final value = timestampMs;
    if (value == null || value <= 0) return const SizedBox.shrink();
    final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    // La fecha completa evita confundir mensajes antiguos con mensajes de hoy.
    final label =
        '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}

import 'package:flutter/material.dart';

/// Presenta el instante registrado con formato compacto y limpio estilo iOS (< 50 líneas).
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
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    String two(int n) => n.toString().padLeft(2, '0');
    final timeStr = '${two(date.hour)}:${two(date.minute)}';
    final label = isToday ? timeStr : '${date.day}/${date.month} $timeStr';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.70),
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

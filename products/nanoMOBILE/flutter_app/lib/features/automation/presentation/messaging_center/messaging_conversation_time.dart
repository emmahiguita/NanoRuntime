/// Formatea una marca temporal real para la lista compacta de conversaciones.
String formatMessagingTimestamp(int milliseconds) {
  if (milliseconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour < 12 ? 'a. m.' : 'p. m.'}';
  }
  if (now.difference(date).inDays < 2) return 'Ayer';
  return '${date.day}/${date.month}';
}

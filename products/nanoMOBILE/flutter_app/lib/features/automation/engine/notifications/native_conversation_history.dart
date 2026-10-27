import '../messaging/conversation_memory_models.dart';

/// Conserva intervenciones reales con su estado de evidencia. Un despacho
/// aceptado permite recordar qué redactó Nano, pero no prueba entrega ni lectura.
List<Map<String, String>> nativeConversationHistory(
  Iterable<ConversationMemoryEntry> entries, {
  int maxMessages = 12,
  int maxChars = 6000,
}) {
  var chars = 0;
  final recent = <Map<String, String>>[];
  for (final entry in entries.toList().reversed) {
    if (entry.kind == ConversationMemoryEntryKind.effectUnknown) continue;
    final remaining = maxChars - chars;
    if (recent.length >= maxMessages || remaining < 40) break;
    final text = entry.text.trim();
    if (text.isEmpty) continue;
    final prefix = entry.kind == ConversationMemoryEntryKind.outboundDispatched
        ? '[Mensaje despachado por Nano; entrega no verificada]\n'
        : '';
    final full = '$prefix$text';
    // El marcador de estado no puede truncarse hasta parecer una confirmación.
    if (remaining < prefix.length + 40) break;
    final content = full.length <= remaining
        ? full
        : '${full.substring(0, remaining - 30)} [historial parcial]';
    recent.add({
      'role': entry.kind == ConversationMemoryEntryKind.inbound
          ? 'user'
          : 'assistant',
      'content': content,
    });
    chars += content.length;
  }
  return recent.reversed.toList();
}

import '../../../../core/services/conversation_reply_quality.dart';
import 'conversation_memory_models.dart';

/// QUÉ: omite salidas defectuosas de la ventana del modelo, no del registro.
/// CÓMO: una pasada cronológica; contrasta cada salida con el último entrante.
/// POR QUÉ: no reenseñar ecos y bucles como ejemplos válidos del asistente.
abstract final class PromptHistoryQuality {
  static List<ConversationMemoryEntry> filter(
    Iterable<ConversationMemoryEntry> source,
  ) {
    final result = <ConversationMemoryEntry>[];
    var incoming = '';
    for (final entry in source) {
      if (entry.kind == ConversationMemoryEntryKind.inbound) {
        incoming = entry.text;
      } else if (ConversationReplyQuality.rejectionReason(
            input: incoming,
            reply: entry.text,
          ) !=
          null) {
        // El mensaje real permanece en SQLite y el panel: no se borra evidencia.
        continue;
      }
      result.add(entry);
    }
    return result;
  }
}

import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/conversation_hub_providers.dart';

/// [ConversationHistoryResolver]
///
/// QUÉ HACE:
/// Unifica, deduplica y ordena cronológicamente el historial de mensajes de una conversación,
/// combinando tanto los mensajes en vivo recibidos desde la barra de notificaciones del sistema
/// como el historial persistente guardado en la base de datos SQLite (FTS4 / ConversationMemoryStore).
///
/// CÓMO FUNCIONA:
/// 1. Incorpora primero los mensajes extraídos en tiempo real de la notificación activa de Android.
/// 2. Consulta y anexa el historial almacenado en SQLite por ID canónico directo.
/// 3. Busca coincidencias por huella conversacional (huellas de atajo o ID sin prefijos como "shortcut:", "conv:").
/// 4. Cruza por coincidencia de nombre real de contacto contra los remitentes en SQLite.
/// 5. Deduplica de forma estricta mediante llave única `${atMs}_${kind}_${text}` y ordena por timestamp ascendente.
///
/// POR QUÉ:
/// Corrige el bug crítico donde una conversación activa en la barra de estado ocultaba todo
/// el historial pasado de SQLite (`if (allEntries.isEmpty)`). Permite al usuario ver la conversación
/// completa y real sin alucinaciones ni pérdidas de contexto.
class ConversationHistoryResolver {
  const ConversationHistoryResolver();

  static List<ConversationMemoryEntry> resolve({
    required ConversationSummaryItem item,
    required ConversationMemoryStore store,
    List<ConversationMemoryEntry> liveEntries = const [],
  }) {
    final allEntries = <ConversationMemoryEntry>[];
    void addEntries(List<ConversationMemoryEntry>? list) {
      if (list == null) return;
      for (final entry in list) {
        if (!allEntries.any((saved) => _sameObservedMessage(saved, entry))) {
          allEntries.add(entry);
        }
      }
    }

    // 1. Mensajes vivos recibidos en tiempo real vía notificación de WhatsApp
    if (liveEntries.isNotEmpty) {
      addEntries(liveEntries);
    }

    // 2. ID limpio y directo en SQLite
    final directIds = <String>{item.conversationId, ...item.conversationAliases};
    for (final rawId in directIds) {
      var id = rawId.trim();
      if (id.startsWith('live:')) id = id.substring(5).trim();
      if (id.isNotEmpty) addEntries(store.memoryFor(id)?.entries);
    }

    var cleanConvId = item.conversationId.trim();
    if (cleanConvId.startsWith('live:')) {
      cleanConvId = cleanConvId.substring(5).trim();
    }

    // 3. Huella digital conversacional (JID, atajo o número directo)
    final fingerprint = cleanConvId.contains('/-/') ? cleanConvId.split('/-/').last : cleanConvId;
    final cleanFingerprint = fingerprint
        .replaceFirst('shortcut:', '')
        .replaceFirst('person:', '')
        .replaceFirst('conv:', '')
        .trim();

    if (cleanFingerprint.isNotEmpty) {
      for (final id in store.knownConversationIds()) {
        if (id == cleanConvId || id == item.conversationId) continue;
        final idFp = id.contains('/-/') ? id.split('/-/').last : id;
        final cleanIdFp = idFp
            .replaceFirst('shortcut:', '')
            .replaceFirst('person:', '')
            .replaceFirst('conv:', '')
            .trim();

        if (cleanFingerprint == cleanIdFp) {
          addEntries(store.memoryFor(id)?.entries);
        }
      }
    }

    // 4. Búsqueda por nombre de contacto en SQLite (sin condicionar a allEntries.isEmpty)
    final targetName = item.displayName.trim().toLowerCase();
    final isGeneric =
        targetName.isEmpty ||
        targetName.startsWith('contacto whatsapp') ||
        targetName.startsWith('chat de whatsapp') ||
        targetName.length < 3;

    if (!isGeneric) {
      for (final id in store.knownConversationIds()) {
        final mem = store.memoryFor(id);
        if (mem != null && mem.entries.any((e) => e.sender.trim().toLowerCase() == targetName)) {
          addEntries(mem.entries);
        }
      }
    }

    // 5. Fallback si no hay ningún registro: mensaje de item si es válido
    if (allEntries.isEmpty) {
      final lastMsg = item.lastMessage.trim();
      final isPhone = RegExp(r'^\+?[0-9\s\-]+$').hasMatch(lastMsg);
      if (lastMsg.isNotEmpty && !isPhone) {
        allEntries.add(
          ConversationMemoryEntry(
            kind: ConversationMemoryEntryKind.inbound,
            text: lastMsg,
            sender: item.displayName,
            atMs: item.lastAtMs,
          ),
        );
      }
    }

    // Ordenar cronológicamente
    allEntries.sort((a, b) => a.atMs.compareTo(b.atMs));
    return allEntries;
  }

  /// Android y SQLite pueden registrar el mismo evento con una diferencia
  /// mínima entre `messageTimestamp` y `postTime`; se compara esa tolerancia
  /// además del eventId para que una burbuja real aparezca una sola vez.
  static bool _sameObservedMessage(
    ConversationMemoryEntry a,
    ConversationMemoryEntry b,
  ) {
    if (a.eventId.isNotEmpty && b.eventId.isNotEmpty) {
      return a.eventId == b.eventId;
    }
    final sameDirection =
        (a.kind == ConversationMemoryEntryKind.inbound) ==
        (b.kind == ConversationMemoryEntryKind.inbound);
    return sameDirection &&
        (a.atMs - b.atMs).abs() <= 2000 &&
        a.text.trim().toLowerCase() == b.text.trim().toLowerCase();
  }
}

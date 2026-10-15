/// Resuelve teléfonos desde identidad técnica o agenda verificada no ambigua.
/// Nunca interpreta números del mensaje, facturas o recuerdos como destinatarios.
library;

import '../../domain/whatsapp_contact.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/messaging/conversation_key.dart';
import '../../personal_agent/application/persona_context.dart';

abstract final class ConversationPhoneResolver {
  /// Conserva argumentos anteriores por compatibilidad; texto/historial/persona
  /// no prueban pertenencia del teléfono y por eso no deciden dónde enviar.
  static String? resolve({
    required String conversationId,
    required String displayName,
    required String lastMessage,
    required ConversationMemoryStore store,
    required PersonaContext personaContext,
    List<WhatsAppContact>? deviceContacts,
    List<ConversationMemoryEntry>? cachedEntries,
  }) {
    final id = canonicalConversationId(conversationId);
    final parts = id.split('/');
    final evidence = parts.length >= 4 ? parts.sublist(3).join('/') : id;
    final peer = RegExp(
      r'(?:^|jid:|conv:|shortcut:|person:)([1-9]\d{7,14})@(s\.whatsapp\.net|c\.us)$',
    ).firstMatch(evidence);
    if (peer != null) return peer.group(1);
    // Solo una etiqueta explícitamente telefónica, no IDs numéricos de shortcut.
    final direct = _phone(id.startsWith('phone:') ? id.substring(6) : id);
    if (direct != null) return direct;
    final labelledPhone = _phone(displayName);
    if (labelledPhone != null) return labelledPhone;

    final name = displayName.trim().toLowerCase();
    if (name.isEmpty || deviceContacts == null) return null;
    final package = parts.length >= 4 ? parts[1] : null;
    final phones = <String>{};
    for (final contact in deviceContacts) {
      if (!contact.isWhatsAppVerified ||
          contact.isGroup ||
          contact.name.trim().toLowerCase() != name ||
          (package != null && contact.packageName != package)) {
        continue;
      }
      final phone = _phone(contact.number);
      if (phone == null) {
        return null; // Una coincidencia sin número sigue siendo ambigua.
      }
      phones.add(phone);
    }
    // No se elige "el mejor" homónimo ni se deduce otro número por aproximación.
    return phones.length == 1 ? phones.single : null;
  }

  /// Exige el número completo; no recorta JIDs, hashes, nombres ni IDs extensos.
  static String? _phone(String raw) {
    final clean = raw.trim();
    if (!RegExp(r'^\+?[\d\s()\-]+$').hasMatch(clean)) return null;
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^[1-9]\d{7,14}$').hasMatch(digits) ? digits : null;
  }
}

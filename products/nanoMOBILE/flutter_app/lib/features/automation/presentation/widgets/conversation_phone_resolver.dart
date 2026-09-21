/// CONVERSATION-PHONE-RESOLVER — Resolución fidedigna de teléfonos para WhatsApp.
///
/// **QUÉ HACE:**
/// Resuelve el número de teléfono internacional de un contacto o conversación
/// consultando el ID, mensajes previos, la agenda real de WhatsApp y el grafo relacional.
///
/// **CÓMO FUNCIONA:**
/// 1. Extrae dígitos directos (>= 7 dígitos) de conversationId o lastMessage.
/// 2. Consulta los contactos reales de WhatsApp mediante [ContactMatcher.findBest].
/// 3. Busca números de teléfono en el historial de mensajes persistidos.
/// 4. Consulta metadatos de relación en [PersonaContext].
///
/// **POR QUÉ:**
/// Permite hablar con cualquier contacto de WhatsApp sin requerir que la notificación
/// esté activa en la barra de Android. Archivo < 200 líneas (SOLID).
library;

import '../../domain/whatsapp_contact.dart';
import '../../engine/messaging/conversation_memory.dart';
import '../../engine/planning/contact_matcher.dart';
import '../../personal_agent/application/persona_context.dart';

abstract final class ConversationPhoneResolver {
  /// Resuelve el número telefónico objetivo combinando todas las fuentes disponibles
  static String? resolve({
    required String conversationId,
    required String displayName,
    required String lastMessage,
    required ConversationMemoryStore store,
    required PersonaContext personaContext,
    List<WhatsAppContact>? deviceContacts,
    List<ConversationMemoryEntry>? cachedEntries,
  }) {
    // 1. Dígitos directos en conversationId (JID o número directo)
    final idDigits = _extractValidDigits(conversationId);
    if (idDigits != null) return idDigits;

    // 2. Dígitos en lastMessage (cuando se abre desde WhatsAppContactCard)
    final msgDigits = _extractValidDigits(lastMessage);
    if (msgDigits != null) return msgDigits;

    // 3. Dígitos en displayName (si el usuario tiene el número como nombre)
    final nameDigits = _extractValidDigits(displayName);
    if (nameDigits != null) return nameDigits;

    // 4. Búsqueda inteligente en la agenda real de WhatsApp del teléfono
    if (deviceContacts != null && deviceContacts.isNotEmpty && displayName.trim().isNotEmpty) {
      final best = ContactMatcher.findBest(displayName, deviceContacts);
      if (best != null && best.number.isNotEmpty) {
        final digits = _extractValidDigits(best.number);
        if (digits != null) return digits;
      }
    }

    // 5. Búsqueda en el historial persistido de SQLite
    final entries = cachedEntries ?? store.memoryFor(conversationId)?.entries ?? const [];
    for (final e in entries) {
      final match = RegExp(r'\+?(\d{10,15})').firstMatch(e.text.replaceAll(' ', ''));
      if (match != null) {
        return match.group(1);
      }
    }

    // 6. Búsqueda en el contexto relacional de la persona
    final rel = personaContext.relationshipFor(
      displayName,
      conversationId: conversationId,
    );
    final relPhone = rel?.facts['phone'] ?? rel?.facts['telefono'];
    if (relPhone != null && relPhone.isNotEmpty) {
      final digits = _extractValidDigits(relPhone);
      if (digits != null) return digits;
    }

    return null;
  }

  /// Extrae y valida secuencias de 7 a 15 dígitos excluyendo identificadores sintéticos
  static String? _extractValidDigits(String raw) {
    if (raw.isEmpty) return null;
    final clean = raw.trim();
    // Excluir claves de atajos sintéticos de Android
    if (clean.startsWith('shortcut:24314') || clean.startsWith('243142846')) {
      return null;
    }
    final match = RegExp(r'\d{7,15}').firstMatch(clean);
    final digits = match?.group(0);
    if (digits != null && digits.length >= 7) {
      return digits;
    }
    return null;
  }
}

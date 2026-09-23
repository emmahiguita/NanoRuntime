/// Identidad canónica usada para deduplicar conversaciones reales sin repeticiones ni duplicados.
///
/// **QUÉ HACE:**
/// Determina si dos elementos de conversación representan el mismo hilo de chat real.
///
/// **CÓMO FUNCIONA:**
/// Compara canal/paquete, identificadores JID (@g.us, @s.whatsapp.net), números telefónicos,
/// títulos de grupo normalizados ("THE BOYS") y nombres normalizados.
///
/// **POR QUÉ:**
/// Erradica conversaciones duplicadas y fragmentadas, manteniendo el código < 200 líneas.
library;

import '../../engine/messaging/conversation_group_resolver.dart';
import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';

abstract final class MessagingConversationIdentity {
  static String? extractPhoneDigits(String raw) => RegExp(r'\d{7,18}').firstMatch(raw)?.group(0);

  static String normalizeName(String raw) {
    var lower = ConversationGroupResolver.cleanTitle(raw).toLowerCase();
    if (lower.contains(':') && lower.split(':').first.contains('.')) {
      lower = lower.split(':').last;
    }
    lower = lower.trim();
    if (lower.isEmpty ||
        lower.startsWith('contacto whatsapp') ||
        lower.startsWith('chat de whatsapp') ||
        lower.startsWith('grupo de whatsapp') ||
        lower == 'grupo' ||
        lower == 'whatsapp' ||
        lower.length < 2) {
      return '';
    }
    return lower;
  }

  /// Distingue nombres humanos de IDs que Android expone como título.
  static bool isTechnicalName(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return true;
    return value.contains('@lid') ||
        value.contains('@g.us') ||
        value.contains('@s.whatsapp.net') ||
        RegExp(r'^\+?[\d\s\-]{7,}$').hasMatch(value) ||
        RegExp(r'^\d{7,18}$').hasMatch(value);
  }

  static String _evidence(String raw) {
    final canonical = canonicalConversationId(raw).toLowerCase();
    if (canonical.isEmpty) return '';
    var evidence = canonical.contains('/') ? canonical.split('/').last : canonical;
    if (evidence.contains(':') && evidence.split(':').first.contains('.')) {
      evidence = evidence.split(':').last;
    }
    for (final prefix in const ['locus:', 'shortcut:', 'person:', 'conv:', 'group:', 'title:', 'jid:']) {
      if (evidence.startsWith(prefix)) {
        evidence = evidence.substring(prefix.length);
        break;
      }
    }
    return evidence.trim();
  }

  static bool _isStrong(String raw) {
    final canonical = canonicalConversationId(raw).toLowerCase();
    final evidence = _evidence(raw);
    if (evidence.isEmpty) return false;
    return const [
          'locus:',
          'shortcut:',
          'person:',
          'conv:',
          'jid:',
        ].any((prefix) => canonical.startsWith(prefix) || canonical.contains('/$prefix')) ||
        evidence.contains('@g.us') ||
        evidence.contains('@s.whatsapp.net') ||
        extractPhoneDigits(evidence) != null;
  }

  static bool areSame(ConversationSummaryItem a, ConversationSummaryItem b) {
    if (a.packageName.toLowerCase() != b.packageName.toLowerCase()) {
      return false;
    }
    final idA = canonicalConversationId(a.conversationId);
    final idB = canonicalConversationId(b.conversationId);
    if (idA.isNotEmpty && idA == idB) return true;

    // La misma notificación o el mismo evento observado por SQLite y Android
    // son evidencia fuerte aunque una fuente tenga nombre y la otra un @lid.
    final notificationA = a.notificationKey?.trim() ?? '';
    final notificationB = b.notificationKey?.trim() ?? '';
    if (notificationA.isNotEmpty && notificationA == notificationB) {
      return true;
    }
    if (_sameObservedEvent(a, b)) return true;

    final evidenceA = _evidence(idA);
    final evidenceB = _evidence(idB);
    if (evidenceA.isNotEmpty && evidenceA == evidenceB) return true;

    // 1. Fusión de JID WhatsApp (@g.us para grupos, @s.whatsapp.net para individuales)
    final jidRegex = RegExp(r'[\w\.\-]+@(g\.us|s\.whatsapp\.net)');
    final jidA = jidRegex.firstMatch(idA)?.group(0) ?? jidRegex.firstMatch(a.notificationKey ?? '')?.group(0);
    final jidB = jidRegex.firstMatch(idB)?.group(0) ?? jidRegex.firstMatch(b.notificationKey ?? '')?.group(0);
    if (jidA != null && jidB != null && jidA.toLowerCase() == jidB.toLowerCase()) {
      return true;
    }

    // 2. Fusión precisa de grupos por título real (ej: "THE BOYS")
    if (a.isGroup || b.isGroup) {
      final titleA = ConversationGroupResolver.cleanTitle(a.groupTitle ?? a.displayName);
      final titleB = ConversationGroupResolver.cleanTitle(b.groupTitle ?? b.displayName);
      if (titleA.isNotEmpty &&
          titleB.isNotEmpty &&
          !ConversationGroupResolver.isGenericTitle(titleA) &&
          !ConversationGroupResolver.isGenericTitle(titleB) &&
          titleA.toLowerCase() == titleB.toLowerCase()) {
        return true;
      }
    }

    // 3. Fusión por dígitos telefónicos o numéricos del JID
    final digitsA = extractPhoneDigits(idA) ?? extractPhoneDigits(a.displayName);
    final digitsB = extractPhoneDigits(idB) ?? extractPhoneDigits(b.displayName);
    if (digitsA != null &&
        digitsB != null &&
        (digitsA == digitsB || digitsA.endsWith(digitsB) || digitsB.endsWith(digitsA))) {
      return true;
    }

    // 4. Fusión por nombre de contacto normalizado
    final nameA = normalizeName(a.displayName);
    final nameB = normalizeName(b.displayName);
    if (nameA.isEmpty || nameA != nameB) return false;

    // Una notificación activa enlaza de forma factual el nombre visible con
    // el shortcut/JID técnico. Esto une "Jaiber" y "...@lid" sin fusionar
    // dos chats históricos solo porque casualmente compartan el mismo nombre.
    final hasLiveBridge =
        a.conversationId.startsWith('live:') ||
        b.conversationId.startsWith('live:') ||
        (a.notificationKey?.trim().isNotEmpty ?? false) ||
        (b.notificationKey?.trim().isNotEmpty ?? false);
    return hasLiveBridge || !_isStrong(idA) || !_isStrong(idB);
  }

  static bool _sameObservedEvent(ConversationSummaryItem a, ConversationSummaryItem b) {
    if (!a.conversationId.startsWith('live:') && !b.conversationId.startsWith('live:')) {
      return false;
    }
    if (a.lastAtMs <= 0 || b.lastAtMs <= 0) return false;
    if ((a.lastAtMs - b.lastAtMs).abs() > 2000) return false;
    final messageA = a.lastMessage.trim().toLowerCase();
    final messageB = b.lastMessage.trim().toLowerCase();
    return messageA.isNotEmpty && messageA == messageB;
  }
}

/// Identidad canónica usada para deduplicar conversaciones reales sin repeticiones ni duplicados.
///
/// **QUÉ HACE:**
/// Determina si dos elementos de conversación representan el mismo hilo de chat real.
///
/// **CÓMO FUNCIONA:**
/// Compara canal/paquete e identificadores técnicos observados. El nombre sólo
/// actúa como puente acotado entre una notificación viva y su fila persistida.
///
/// **POR QUÉ:**
/// Erradica conversaciones duplicadas y fragmentadas, manteniendo el código < 200 líneas.
library;

import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';

abstract final class MessagingConversationIdentity {
  static String? extractPhoneDigits(String raw) =>
      RegExp(r'\d{7,18}').firstMatch(raw)?.group(0);

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

  static bool areSame(ConversationSummaryItem a, ConversationSummaryItem b) {
    if (a.packageName.toLowerCase() != b.packageName.toLowerCase()) {
      return false;
    }
    final idA = canonicalConversationId(a.conversationId);
    final idB = canonicalConversationId(b.conversationId);
    if (idA.isNotEmpty && idA == idB && _strongIdentity(idA) != null) {
      return true;
    }

    // Android puede entregar el mismo JID o teléfono dentro de envoltorios
    // distintos (`live:` frente a la dirección canónica persistida).
    final jidA = _jidFrom(a.conversationId);
    final jidB = _jidFrom(b.conversationId);
    if (jidA != null && jidA == jidB) return true;
    final phoneA = extractPhoneDigits(a.conversationId);
    final phoneB = extractPhoneDigits(b.conversationId);
    if (phoneA != null && phoneA == phoneB) return true;

    // La misma notificación o el mismo evento observado por SQLite y Android
    // son evidencia fuerte aunque una fuente tenga nombre y la otra un @lid.
    final notificationA = a.notificationKey?.trim() ?? '';
    final notificationB = b.notificationKey?.trim() ?? '';
    if (notificationA.isNotEmpty && notificationA == notificationB) {
      return true;
    }
    // Los aliases nacen únicamente de una unión ya probada (misma clave de
    // notificación o mismo ID). Su intersección permite conservar continuidad
    // sin inferir identidad por nombre, título o sufijos telefónicos.
    final identitiesA = _strongIdentities(a);
    final identitiesB = _strongIdentities(b);
    if (identitiesA.any(identitiesB.contains)) return true;

    // Último puente permitido: misma etiqueta humana no técnica y exactamente
    // una fuente viva. Nunca fusiona dos filas persistidas sólo por nombre.
    final aLive = a.conversationId.toLowerCase().startsWith('live:');
    final bLive = b.conversationId.toLowerCase().startsWith('live:');
    final nameA = a.displayName.trim().toLowerCase();
    final nameB = b.displayName.trim().toLowerCase();
    return aLive != bLive &&
        nameA.isNotEmpty &&
        nameA == nameB &&
        !isTechnicalName(nameA) &&
        !isTechnicalName(nameB);
  }

  static String? _jidFrom(String raw) => RegExp(
    r'[\w\.\-]+@(g\.us|s\.whatsapp\.net)',
    caseSensitive: false,
  ).firstMatch(raw)?.group(0)?.toLowerCase();

  static Set<String> _strongIdentities(ConversationSummaryItem item) {
    final result = <String>{};
    for (final raw in [item.conversationId, ...item.conversationAliases]) {
      final identity = _strongIdentity(raw);
      if (identity != null) result.add(identity);
    }
    return result;
  }

  /// Produce una clave con paquete+cuenta. Solo acepta IDs estructurados para
  /// impedir que un alias legado sin procedencia mezcle plataformas o cuentas.
  static String? _strongIdentity(String raw) {
    final canonical = canonicalConversationId(raw).toLowerCase();
    final parts = canonical.split('/');
    if (parts.length < 4) return null;
    final scope = '${parts[1]}/${parts[2]}';
    final evidence = parts.sublist(3).join('/');
    final jid = RegExp(
      r'[\w\.\-]+@(g\.us|s\.whatsapp\.net)',
    ).firstMatch(evidence)?.group(0);
    if (jid != null) return '$scope/jid:$jid';
    final strongPrefix = const [
      'locus:',
      'shortcut:',
      'person:',
      'conv:',
      'notification:',
      'jid:',
    ].any(evidence.startsWith);
    return strongPrefix ? '$scope/$evidence' : null;
  }
}

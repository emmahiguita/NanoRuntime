/// Compara evidencia técnica dentro de la misma aplicación y cuenta.
/// Los títulos solo son etiquetas; no fusionan ni autorizan conversaciones.
library;

import '../../engine/messaging/conversation_hub_providers.dart';
import '../../engine/messaging/conversation_key.dart';

abstract final class MessagingConversationIdentity {
  /// Extrae solo teléfonos completos o JIDs directos; nunca dígitos de un nombre.
  static String? extractPhoneDigits(String raw) {
    var clean = raw.trim();
    if (clean.contains('/')) clean = clean.split('/').last.trim();
    for (final p in const ['phone:', 'jid:', 'person:', 'shortcut:']) {
      if (clean.toLowerCase().startsWith(p)) clean = clean.substring(p.length);
    }
    final jid = RegExp(
      r'^([1-9]\d{7,14})@(s\.whatsapp\.net|c\.us)$',
    ).firstMatch(clean.toLowerCase());
    if (jid != null) return jid.group(1);
    if (!RegExp(r'^\+?[\d\s()\-]+$').hasMatch(clean)) return null;
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^[1-9]\d{7,14}$').hasMatch(digits) ? digits : null;
  }

  /// Distingue etiquetas técnicas de nombres para presentar títulos legibles.
  static bool isTechnicalName(String raw) {
    final v = raw.trim().toLowerCase();
    return v.isEmpty ||
        _jidFrom(v) != null ||
        v.startsWith('waweb:') ||
        v.startsWith('live:') ||
        v.startsWith('history:') ||
        extractPhoneDigits(v) != null;
  }

  /// Se usa para presentación, nunca como evidencia de equivalencia.
  static String normalizeTitle(String raw) {
    var s = raw.trim().replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E\uFE0F]'),
      '',
    );
    for (final p in const [
      'waweb:',
      'live:',
      'history:',
      'notification-history:',
      'title:',
      'group:',
      'conv:',
      'shortcut:',
      'person:',
      'jid:',
    ]) {
      if (s.toLowerCase().startsWith(p)) s = s.substring(p.length).trim();
    }
    if (s.contains(' @ ')) s = s.split(' @ ').last.trim();
    s = s.replaceAll(RegExp(r'\s*\(\d+[^)]*\)'), '');
    s = s.replaceAll(RegExp(r'@(g\.us|s\.whatsapp\.net|lid).*'), '');
    return s.toLowerCase().replaceAll(RegExp(r'[\s\-_\.]+'), ' ').trim();
  }

  static bool isTransientId(String id) {
    final lower = id.toLowerCase().trim();
    return const [
      'waweb:',
      'live:',
      'history:',
      'notification-history:',
    ].any(lower.startsWith);
  }

  /// La cuenta desconocida no se interpreta como cualquiera de las conocidas.
  static bool areSame(ConversationSummaryItem a, ConversationSummaryItem b) {
    if (a.packageName.trim().toLowerCase() !=
            b.packageName.trim().toLowerCase() ||
        a.isGroup != b.isGroup) {
      return false;
    }
    final accountsA = _accounts(a), accountsB = _accounts(b);
    if (accountsA.length > 1 || accountsB.length > 1) return false;
    if (accountsA.isNotEmpty || accountsB.isNotEmpty) {
      if (accountsA.length != 1 ||
          accountsB.length != 1 ||
          accountsA.single != accountsB.single) {
        return false;
      }
    }
    final peersA = _peers(a), peersB = _peers(b);
    // Alias antiguos contradictorios no deben propagar una fusión insegura.
    if (peersA.length > 1 || peersB.length > 1) return false;
    if (peersA.isNotEmpty && peersB.isNotEmpty) {
      return peersA.single == peersB.single;
    }
    final strongA = _strongIdentities(a), strongB = _strongIdentities(b);
    if (strongA.isNotEmpty && strongB.isNotEmpty) {
      return strongA.any(strongB.contains);
    }
    final key = a.notificationKey?.trim() ?? '';
    return key.isNotEmpty && key == b.notificationKey?.trim();
  }

  /// Recupera el scope canónico emitido por el resolver de Android.
  static Set<String> _accounts(ConversationSummaryItem item) {
    final result = <String>{
      if (item.accountFingerprint.trim().isNotEmpty)
        item.accountFingerprint.trim(),
    };
    for (final raw in [item.conversationId, ...item.conversationAliases]) {
      final parts = canonicalConversationId(raw).split('/');
      if (parts.length >= 4 &&
          parts[1] == item.packageName &&
          parts[2].isNotEmpty &&
          parts[2] != '-') {
        result.add(parts[2]);
      }
    }
    return result;
  }

  /// Compara interlocutores publicados; c.us y s.whatsapp.net son JIDs directos.
  static Set<String> _peers(ConversationSummaryItem item) {
    final result = <String>{};
    for (final raw in [item.conversationId, ...item.conversationAliases]) {
      // El ID Web derivado del título es débil, aunque esté aislado por cuenta.
      if (raw.toLowerCase().startsWith('waweb:')) continue;
      final jid = _jidFrom(raw);
      if (jid != null) {
        result.add(
          jid.endsWith('@c.us')
              ? jid.replaceFirst('@c.us', '@s.whatsapp.net')
              : jid,
        );
      } else if (!item.isGroup) {
        final phone = extractPhoneDigits(raw);
        if (phone != null) result.add('$phone@s.whatsapp.net');
      }
    }
    return result;
  }

  static String? _jidFrom(String raw) => RegExp(
    r'[\w.\-]+@(g\.us|s\.whatsapp\.net|c\.us|lid)',
    caseSensitive: false,
  ).firstMatch(raw)?.group(0)?.toLowerCase();

  static Set<String> _strongIdentities(ConversationSummaryItem item) {
    final result = <String>{};
    for (final raw in [item.conversationId, ...item.conversationAliases]) {
      final canonical = canonicalConversationId(raw);
      final parts = canonical.split('/');
      if (parts.length < 4 || parts[1] != item.packageName) continue;
      final evidence = parts.sublist(3).join('/');
      if (const [
        'locus:',
        'shortcut:',
        'person:',
        'conv:',
        'notification:',
        'jid:',
      ].any(evidence.startsWith)) {
        result.add(canonical);
      }
    }
    return result;
  }
}

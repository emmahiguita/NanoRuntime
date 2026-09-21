part of 'conversation_detail_sheet.dart';

/// [ConversationDetailNotifications]
///
/// QUÉ HACE:
/// Administra la detección y matching de notificaciones del sistema Android en tiempo real
/// para asociarlas fielmente con la conversación activa en pantalla.
///
/// CÓMO FUNCIONA:
/// 1. Consulta la lista de notificaciones activas capturadas por el `NotificationListenerService`.
/// 2. Evalúa coincidencias por:
///    - `notificationKey` exacta de Android.
///    - Identidad canónica unificada (`ConversationIdentity`).
///    - Atajos del sistema (`shortcutId`, `senderKey`, `conversationId`).
///    - Dígitos telefónicos extraídos (mínimo 7 dígitos para evitar falsos positivos).
///    - Nombre exacto de contacto (no genérico).
/// 3. Extrae mensajes enriquecidos (`MessagingStyle`) con marca de tiempo y autor.
///
/// POR QUÉ:
/// Garantiza que cuando un contacto envía un mensaje en WhatsApp, la conversación se enlace
/// de inmediato con la notificación nativa para permitir respuestas en segundo plano sin abrir
/// WhatsApp y sin alucinaciones de remitentes.
extension ConversationDetailNotifications on _ConversationDetailSheetState {
  String get _cleanConvId {
    var id = widget.item.conversationId.trim();
    return id.startsWith('live:') ? id.substring(5).trim() : id;
  }

  String _cleanName(String raw) {
    if (raw.contains('|')) raw = raw.split('|').last;
    if (raw.contains('shortcut:') || raw.contains('@g.us') || raw.startsWith('whatsapp/')) {
      final digits = RegExp(r'\d{8,15}').firstMatch(raw)?.group(0);
      return digits != null ? 'Contacto WhatsApp ($digits)' : 'Chat de WhatsApp';
    }
    return raw;
  }

  Future<void> _loadLiveHistoryAndCapabilities() async {
    try {
      final executor = ref.read(notificationExecutorProvider);
      final list = await executor.list(limit: 50);
      final matches = _findAllMatchingNotifications(list);
      if (matches.isNotEmpty && mounted) {
        final replyable = matches.where((n) => n.canReply).firstOrNull ?? matches.first;
        final entries = <ConversationMemoryEntry>[];
        final seen = <String>{};

        for (final matched in matches) {
          // 1. Mensajes estructurados (MessagingStyle de WhatsApp)
          for (final m in matched.rawMessages) {
            final text = (m['messageText'] ?? m['text'] ?? '').toString().trim();
            if (text.isEmpty) continue;
            final isSelf = m['isSelf'] == true;
            final sender = (m['sender'] ?? (isSelf ? 'Tú' : widget.item.displayName)).toString();
            final atMs = (m['messageTimestamp'] is num)
                ? (m['messageTimestamp'] as num).toInt()
                : matched.postedAt.millisecondsSinceEpoch;
            final dedupeKey = '${atMs}_$text';
            if (seen.add(dedupeKey)) {
              entries.add(
                ConversationMemoryEntry(
                  kind: isSelf
                      ? ConversationMemoryEntryKind.outboundObservedManual
                      : ConversationMemoryEntryKind.inbound,
                  text: text,
                  sender: sender,
                  atMs: atMs,
                ),
              );
            }
          }

          // 2. Mensaje principal si rawMessages no lo cubrió
          final mainText = (matched.messageText.isNotEmpty ? matched.messageText : matched.text).trim();
          if (mainText.isNotEmpty) {
            final atMs = matched.messageTimestamp > 0
                ? matched.messageTimestamp
                : matched.postedAt.millisecondsSinceEpoch;
            final dedupeKey = '${atMs}_$mainText';
            if (seen.add(dedupeKey)) {
              entries.add(
                ConversationMemoryEntry(
                  kind: ConversationMemoryEntryKind.inbound,
                  text: mainText,
                  sender: matched.sender.isNotEmpty ? matched.sender : widget.item.displayName,
                  atMs: atMs,
                ),
              );
            }
          }
        }

        // 3. Fallback con el último mensaje conocido de widget.item si no es teléfono
        final itemLastMsg = widget.item.lastMessage.trim();
        final isPhone = RegExp(r'^\+?[0-9\s\-]+$').hasMatch(itemLastMsg);
        if (itemLastMsg.isNotEmpty && !isPhone) {
          final dedupeKey = '${widget.item.lastAtMs}_$itemLastMsg';
          if (seen.add(dedupeKey)) {
            entries.add(
              ConversationMemoryEntry(
                kind: ConversationMemoryEntryKind.inbound,
                text: itemLastMsg,
                sender: widget.item.displayName,
                atMs: widget.item.lastAtMs,
              ),
            );
          }
        }

        entries.sort((a, b) => a.atMs.compareTo(b.atMs));

        setState(() {
          _activeNotification = replyable;
          if (entries.isNotEmpty) {
            _liveEntries = entries;
          }
        });
      }
    } catch (_) {}
  }

  bool _notificationMatches(DeviceNotification n, {bool requireCanReply = false}) {
    if (requireCanReply && !n.canReply) return false;

    final convId = _cleanConvId;
    final displayName = widget.item.displayName.trim().toLowerCase();
    final notifKey = widget.item.notificationKey?.trim();

    if (notifKey != null && notifKey.isNotEmpty && n.key == notifKey) return true;

    if (convId.isNotEmpty) {
      final nIdentity = resolveConversationIdentity(n.toNotificationObject());
      if (nIdentity.key.id.isNotEmpty &&
          (nIdentity.key.id == convId ||
              nIdentity.key.id.endsWith(convId) ||
              convId.endsWith(nIdentity.key.id))) {
        return true;
      }
      if (n.shortcutId.isNotEmpty &&
          (convId == n.shortcutId || convId.contains(n.shortcutId) || n.shortcutId.contains(convId))) {
        return true;
      }
      if (n.senderKey.isNotEmpty &&
          (convId == n.senderKey || convId.contains(n.senderKey) || n.senderKey.contains(convId))) {
        return true;
      }
      if (n.conversationId.isNotEmpty &&
          (convId == n.conversationId || convId.contains(n.conversationId) || n.conversationId.contains(convId))) {
        return true;
      }
    }

    final targetDigits = RegExp(r'\d{7,15}').firstMatch(convId)?.group(0) ??
        RegExp(r'\d{7,15}').firstMatch(displayName)?.group(0);

    if (targetDigits != null && targetDigits.length >= 7) {
      for (final candidate in [n.conversationId, n.senderKey, n.shortcutId, n.title]) {
        final nDigits = RegExp(r'\d{7,15}').firstMatch(candidate)?.group(0);
        if (nDigits != null && nDigits.length >= 7) {
          if (targetDigits == nDigits || targetDigits.endsWith(nDigits) || nDigits.endsWith(targetDigits)) {
            return true;
          }
        }
      }
    }

    final isGeneric = displayName.isEmpty ||
        displayName.startsWith('contacto whatsapp') ||
        displayName.startsWith('chat de whatsapp') ||
        displayName == 'whatsapp' ||
        displayName.length < 3;

    if (!isGeneric) {
      final nTitle = n.title.trim().toLowerCase();
      final nSender = n.sender.trim().toLowerCase();
      final nConvTitle = n.conversationTitle.trim().toLowerCase();
      if (nTitle == displayName || (nSender.isNotEmpty && nSender == displayName) || (nConvTitle.isNotEmpty && nConvTitle == displayName)) {
        return true;
      }
    }

    return false;
  }

  DeviceNotification? _findMatchingNotification(List<DeviceNotification> list, {bool requireCanReply = false}) {
    for (final n in list) {
      if (_notificationMatches(n, requireCanReply: requireCanReply)) return n;
    }
    return null;
  }

  List<DeviceNotification> _findAllMatchingNotifications(List<DeviceNotification> list) {
    return list.where((n) => _notificationMatches(n, requireCanReply: false)).toList();
  }
}

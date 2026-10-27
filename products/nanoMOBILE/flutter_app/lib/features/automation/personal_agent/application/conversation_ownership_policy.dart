/// Política única para decidir quién controla una conversación.
///
/// QUÉ HACE:
/// Convierte el modo de destinatarios y el ownership persistido en una
/// respuesta inequívoca: `true` significa que Nano no puede enviar.
///
/// CÓMO FUNCIONA:
/// En modo `selected`, solo una selección explícita del bot habilita el chat.
/// En modo global, se respeta una pausa humana persistente.
///
/// POR QUÉ:
/// La interfaz y el pipeline deben aplicar la misma regla; de lo contrario la
/// pantalla puede mostrar «IA activa» mientras el motor bloquea el mensaje.
library;

import '../domain/conversation_owner.dart';
import 'conversation_ownership_store.dart';
import '../../engine/messaging/messaging_package.dart';
import '../../engine/messaging/conversation_identity_resolver.dart';
import '../../engine/notifications/notification_object.dart';

abstract final class ConversationOwnershipPolicy {
  static final _whatsAppJidPattern = RegExp(
    r'[\w.\-]+@s\.whatsapp\.net',
    caseSensitive: false,
  );
  static final _phoneLikePattern = RegExp(r'^\+?[0-9][0-9 .()\-]{5,18}$');

  /// Resuelve el ownership usando primero la clave canónica del chat y luego
  /// identificadores técnicos que Android publica para el contacto de WhatsApp.
  /// Nunca utiliza nombres visibles para autorizar o bloquear un chat.
  static ConversationOwnership? ownershipForNotification({
    required ConversationOwnershipStore store,
    required String conversationId,
    required NotificationObject notification,
    bool? isGroup,
  }) {
    // El alias de notificación enlaza historial legacy con el evento actual.
    // Una pausa gana frente a un alias Bot; no se usan nombres para autorizar.
    return _fromKeys(store, {
      conversationId,
      conversationIdentityFor(
        packageName: notification.packageName,
        accountHint: notification.accountHint,
        notificationKey: notification.key,
      ).key.id,
      if (_isWhatsApp(notification.packageName) &&
          !(isGroup ?? notification.isGroup))
        ..._notificationContactKeys(notification),
    });
  }

  /// Resuelve los mismos aliases para filas históricas del Centro de mensajes,
  /// donde ya solo se conserva la identidad de conversación.
  static ConversationOwnership? ownershipForConversation({
    required ConversationOwnershipStore store,
    required String conversationId,
    required String packageName,
    bool isGroup = false,
    Iterable<String> aliases = const [],
  }) {
    return _fromKeys(store, {
      conversationId,
      ...aliases,
      if (_isWhatsApp(packageName) && !isGroup)
        ..._conversationContactKeys(conversationId),
    });
  }

  /// Aplica el estado más restrictivo de aliases técnicos equivalentes.
  static ConversationOwnership? _fromKeys(
    ConversationOwnershipStore store,
    Iterable<String> keys,
  ) {
    ConversationOwnership? selected;
    for (final key in keys) {
      final current = store.ownershipFor(key);
      if (current?.humanOwns == true) return current;
      selected ??= current;
    }
    return selected;
  }

  static bool humanOwns({
    required String targetContactsMode,
    required ConversationOwnership? ownership,
  }) {
    if (targetContactsMode == 'selected') {
      return ownership?.owner != ConversationOwner.bot;
    }
    return ownership?.humanOwns ?? false;
  }

  static bool _isWhatsApp(String packageName) =>
      packageName == MessagingPackage.whatsapp ||
      packageName == MessagingPackage.whatsappBusiness;

  static Iterable<String> _notificationContactKeys(
    NotificationObject notification,
  ) sync* {
    final keys = <String>{};
    final technicalValues = [
      notification.senderKey,
      notification.senderUri,
      notification.conversationId,
      notification.shortcutId,
      notification.locusId,
      notification.key,
    ];
    for (final value in technicalValues) {
      _addJidKeys(keys, value);
    }

    // Person.uri is Android's explicit contact URI. Person.key and shortcut /
    // conversation ids are also technical identifiers, so allow a strict phone
    // number there; display names, titles and message text are never inspected.
    _addTelUri(keys, notification.senderUri);
    _addPhoneLike(keys, notification.senderKey);
    _addPhoneLike(keys, notification.conversationId);
    _addPhoneLike(keys, notification.shortcutId);
    yield* keys;
  }

  static Iterable<String> _conversationContactKeys(
    String conversationId,
  ) sync* {
    final keys = <String>{};
    _addJidKeys(keys, conversationId);

    final fingerprint = conversationId.trim().split('/').last;
    if (fingerprint.startsWith('person:') || fingerprint.startsWith('conv:')) {
      _addPhoneLike(keys, fingerprint.substring(fingerprint.indexOf(':') + 1));
    }
    yield* keys;
  }

  static void _addJidKeys(Set<String> keys, String value) {
    for (final match in _whatsAppJidPattern.allMatches(value)) {
      final jid = match.group(0)?.toLowerCase();
      if (jid == null) continue;
      keys.add(jid);
      keys.add(jid.substring(0, jid.indexOf('@')));
    }
  }

  static void _addTelUri(Set<String> keys, String value) {
    final trimmed = value.trim();
    if (!trimmed.toLowerCase().startsWith('tel:')) return;
    final number = trimmed.substring(4).split(RegExp(r'[;?]')).first;
    _addPhoneLike(keys, number);
  }

  static void _addPhoneLike(Set<String> keys, String value) {
    final trimmed = value.trim();
    if (!_phoneLikePattern.hasMatch(trimmed)) return;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 7 && digits.length <= 15) keys.add(digits);
  }
}

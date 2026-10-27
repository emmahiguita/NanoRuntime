import 'dart:convert';
import '../../engine/messaging/conversation_identity_resolver.dart';
import '../../engine/messaging/conversation_identity_model.dart';

/// Reconstruye el scope con el mismo resolver que el pipeline, no por nombre visible.
ConversationIdentity notificationHistoryIdentity(Map<String, dynamic> row) {
  Map<String, dynamic> metadata = const {};
  try {
    final raw = jsonDecode('${row['identityJson'] ?? ''}');
    if (raw is Map) metadata = Map<String, dynamic>.from(raw);
  } on FormatException {
    // Legacy sin metadata: conserva solamente la key técnica realmente guardada.
  }
  String value(String key) => '${metadata[key] ?? ''}';
  return conversationIdentityFor(
    packageName: '${row['packageName'] ?? ''}',
    notificationKey: '${row['notificationKey'] ?? ''}',
    accountHint: value('accountHint'),
    locusId: value('locusId'),
    shortcutId: value('shortcutId'),
    senderKey: value('senderKey'),
    conversationId: value('conversationId'),
    isGroup: row['isGroup'] == true,
  );
}

/// Conserva el alias de evento para que una pausa siga siendo válida al cambiar el shortcut.
String notificationHistoryEventAlias(Map<String, dynamic> row) =>
    conversationIdentityFor(
      packageName: '${row['packageName'] ?? ''}',
      notificationKey: '${row['notificationKey'] ?? ''}',
      accountHint: notificationHistoryIdentity(row).key.accountFingerprint,
    ).key.id;

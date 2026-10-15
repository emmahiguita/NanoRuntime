import '../../engine/messaging/conversation_hub_providers.dart';

/// Evita que avisos antiguos del agente reaparezcan al unir las fuentes del panel.
abstract final class SocialMessagingPanelFilter {
  static const _packages = {
    'com.instagram.android',
    'com.facebook.katana',
    'com.facebook.lite',
    'com.facebook.orca',
    'com.facebook.mlite',
  };

  /// Acota esta política a Facebook, Instagram y sus clientes de mensajes.
  static bool appliesTo(String packageName) => _packages.contains(packageName);

  /// Exige evidencia explícita; una fila legacy no se verifica por su prefijo.
  static bool allows(ConversationSummaryItem item) {
    if (!appliesTo(item.packageName)) return true;
    if (item.messageVerified) return true;
    // Conserva DMs antiguos de Instagram con el tag técnico observado, no por su texto.
    final key = item.notificationKey ?? '';
    return item.packageName == 'com.instagram.android' &&
        key.contains('|direct|') &&
        key.contains('thread_id:');
  }
}

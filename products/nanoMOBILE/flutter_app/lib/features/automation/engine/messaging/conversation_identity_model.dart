/// Modelo inmutable de identidad conversacional y su nivel de confianza.
///
/// Se separa del resolver para que el dominio no dependa de notificaciones ni
/// de reglas de extracción de una plataforma concreta.
library;

/// El prefijo `live:` pertenece a presentación, no a memoria ni despacho.
String canonicalConversationId(String raw) {
  var id = raw.trim();
  while (id.toLowerCase().startsWith('live:')) {
    id = id.substring(5).trim();
  }
  return id;
}

/// Clave estable derivada solo de evidencia publicada por la plataforma.
final class ConversationKey {
  /// Canal lógico; WhatsApp y WhatsApp Business usan canales distintos.
  final String channel;
  final String appPackage;

  /// Cuenta/dispositivo. Vacío significa que Android no lo expuso.
  final String accountFingerprint;

  /// Mejor evidencia: locus, shortcut, Person, conversation o notificación.
  final String conversationFingerprint;

  const ConversationKey({
    required this.channel,
    required this.appPackage,
    required this.accountFingerprint,
    required this.conversationFingerprint,
  });

  String get id => conversationFingerprint.isEmpty
      ? ''
      : '$channel/$appPackage/'
            '${accountFingerprint.isEmpty ? '-' : accountFingerprint}/'
            '$conversationFingerprint';

  @override
  bool operator ==(Object other) =>
      other is ConversationKey &&
      other.channel == channel &&
      other.appPackage == appPackage &&
      other.accountFingerprint == accountFingerprint &&
      other.conversationFingerprint == conversationFingerprint;

  @override
  int get hashCode => Object.hash(
    channel,
    appPackage,
    accountFingerprint,
    conversationFingerprint,
  );

  @override
  String toString() => 'ConversationKey($id)';
}

/// Clave resuelta, confianza 0..1 y evidencia realmente observada.
final class ConversationIdentity {
  final ConversationKey key;
  final double confidence;
  final Set<String> evidenceUsed;

  const ConversationIdentity({
    required this.key,
    required this.confidence,
    required this.evidenceUsed,
  });

  /// Autoriza escritura solo con identidad técnica, nunca por título/nombre.
  static const double safeToWriteThreshold = 0.60;

  bool get safeToWrite => confidence >= safeToWriteThreshold;
}

/// WA-ID-02 — ConversationKey: identidad lógica de una conversación de
/// mensajería, derivada EXCLUSIVAMENTE de evidencia factual publicada por la
/// plataforma (locusId, shortcutId, Person.key, conversationId, título). Es
/// universal: no hay tipos "WhatsApp" aquí; cada app de mensajería aporta la
/// misma evidencia y produce la misma clave.
///
/// Reglas duras:
/// - com.whatsapp y com.whatsapp.w4b JAMÁS comparten identidad (canales
///   distintos).
/// - El título solo se usa como último recurso y con confianza baja: dos
///   contactos con el mismo nombre visible no pueden colapsar en una clave.
/// - Campos vacíos = evidencia ausente (honesto), no se fabrican.
library;

import '../notifications/notification_object.dart';
import 'messaging_package.dart';

/// Clave estable de conversación. Igualdad por valor: dos eventos de la
/// misma conversación lógica producen la misma clave.
final class ConversationKey {
  /// Canal lógico de mensajería: 'whatsapp', 'whatsapp.business', o el
  /// packageName tal cual para apps sin canal conocido. NUNCA se fusionan
  /// dos paquetes distintos en un mismo canal.
  final String channel;

  /// Paquete real del que vino la evidencia (p. ej. com.whatsapp).
  final String appPackage;

  /// Fingerprint de la cuenta/dispositivo (accountHint/subText), '' si la
  /// app no lo expuso.
  final String accountFingerprint;

  /// Fingerprint de la conversación: la evidencia más fuerte disponible
  /// (locus > shortcut > person.key > conversationId > título+contexto).
  final String conversationFingerprint;

  const ConversationKey({
    required this.channel,
    required this.appPackage,
    required this.accountFingerprint,
    required this.conversationFingerprint,
  });

  /// Clave legible y única para logs/almacenamiento.
  String get id => conversationFingerprint.isEmpty
      ? ''
      : '$channel/$appPackage/${accountFingerprint.isEmpty ? '-' : accountFingerprint}/$conversationFingerprint';

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

/// Resultado de resolver la identidad de una notificación: la clave más
/// fuerte posible + la confianza en esa identidad + qué evidencia se usó.
/// La confianza es explícita y el llamador decide el umbral de escritura.
final class ConversationIdentity {
  final ConversationKey key;

  /// 0..1. Nunca 1.0 salvo evidencia estable de plataforma (locusId real).
  final double confidence;

  /// Piezas de evidencia realmente usadas (locusId, shortcutId, senderKey,
  /// conversationId, conversationTitle, title). Vacío = sin evidencia útil.
  final Set<String> evidenceUsed;

  const ConversationIdentity({
    required this.key,
    required this.confidence,
    required this.evidenceUsed,
  });

  /// AUTO-CONSOLIDATE-01 — umbral conservador para autorizar una ESCRITURA
  /// (reply). ÚNICA fuente: la usa este getter Y el ConversationDecisionEngine
  /// (antes el 0.95 estaba duplicado inline). Un título como única evidencia
  /// no lo alcanza: dos homónimos no pueden distinguirse por título.
  static const double safeToWriteThreshold = 0.95;

  bool get safeToWrite => confidence >= safeToWriteThreshold;
}

/// Resuelve la identidad de una notificación siguiendo el orden de
/// preferencia de evidencia fuerte a débil:
///  1. locusId          — conversación estable (API 29)          → 1.0
///  2. shortcutId       — shortcut de conversación               → 0.95
///  3. senderKey        — Person.key del remitente               → 0.90
///  4. conversationId   — android.conversationId                 → 0.85
///  5. título + sender  — contexto conversacional                → 0.60
///  6. título a secas   — último recurso, BAJA confianza         → 0.35
/// Sin ninguna evidencia: clave con fingerprint vacío y confianza 0.
ConversationIdentity resolveConversationIdentity(NotificationObject n) =>
    conversationIdentityFor(
      packageName: n.packageName,
      accountHint: n.accountHint,
      locusId: n.locusId,
      shortcutId: n.shortcutId,
      senderKey: n.senderKey,
      conversationId: n.conversationId,
      conversationTitle: n.conversationTitle,
      sender: n.sender,
      isGroup: n.isGroup,
      notificationKey: n.key,
    );

/// PERSONA-TOOLS-10 — identidad por CAMPOS (misma evidencia, mismo orden):
/// la usan el pipeline ([resolveConversationIdentity]) y la pantalla de
/// Mensajes (vista de notificaciones ACTIVAS). Con la misma evidencia de
/// Android ambas derivan la MISMA clave — el ownership marcado desde la UI
/// matchea la conversación que ve el pipeline. Puro, sin LLM.
ConversationIdentity conversationIdentityFor({
  required String packageName,
  String accountHint = '',
  String locusId = '',
  String shortcutId = '',
  String senderKey = '',
  String conversationId = '',
  String conversationTitle = '',
  String sender = '',
  bool isGroup = false,
  String notificationKey = '',
}) {
  final channel = channelForPackage(packageName);
  final account = accountHint.trim();

  ConversationKey key(String fingerprint) => ConversationKey(
    channel: channel,
    appPackage: packageName,
    accountFingerprint: account,
    conversationFingerprint: fingerprint,
  );

  if (locusId.isNotEmpty) {
    return ConversationIdentity(
      key: key('locus:$locusId'),
      confidence: 1.0,
      evidenceUsed: const {'locusId'},
    );
  }
  if (shortcutId.isNotEmpty) {
    return ConversationIdentity(
      key: key('shortcut:$shortcutId'),
      confidence: 0.95,
      evidenceUsed: const {'shortcutId'},
    );
  }
  if (!isGroup && senderKey.isNotEmpty) {
    return ConversationIdentity(
      key: key('person:$senderKey'),
      confidence: 0.9,
      evidenceUsed: const {'senderKey'},
    );
  }
  if (conversationId.isNotEmpty) {
    return ConversationIdentity(
      key: key('conv:$conversationId'),
      confidence: 0.85,
      evidenceUsed: const {'conversationId'},
    );
  }

  final title = conversationTitle.trim();
  final cleanSender = sender.trim();
  if (title.isNotEmpty) {
    // Contexto completo (título + remitente) distingue mejor dos contactos
    // con nombre visible idéntico dentro de la MISMA app... pero sigue sin
    // ser evidencia estable de plataforma.
    final context = [
      title,
      if (!isGroup && cleanSender.isNotEmpty) cleanSender,
      if (notificationKey.isNotEmpty) notificationKey,
    ].join('|');
    return ConversationIdentity(
      key: key('title:$context'),
      confidence: cleanSender.isNotEmpty ? 0.6 : 0.35,
      evidenceUsed: {'conversationTitle', if (cleanSender.isNotEmpty) 'sender'},
    );
  }

  return ConversationIdentity(
    key: key(''),
    confidence: 0,
    evidenceUsed: const {},
  );
}

/// Canal lógico por paquete (ChannelAdapter). WhatsApp y WhatsApp Business
/// son canales DISTINTOS: jamás se fusionan en una misma identidad de
/// conversación. Única autoridad de este mapeo; los paquetes anclan en
/// [MessagingPackage].
String channelForPackage(String packageName) => switch (packageName) {
  MessagingPackage.whatsapp => 'whatsapp',
  MessagingPackage.whatsappBusiness => 'whatsapp.business',
  MessagingPackage.telegram => 'telegram',
  MessagingPackage.telegramOrg => 'telegram',
  _ => packageName,
};

/// Identidad estable de los dos agentes conversacionales de Nano.
///
/// Un agente no es un tono temporal: posee objetivo, reglas y memoria propios.
/// La infraestructura puede compartirse, pero el [AgentConversationScope]
/// impide que Personal y Negocios lean la misma historia por accidente.
library;

import 'dart:convert';

import 'conversation_key.dart';
import 'messaging_package.dart';

enum ConversationAgentId {
  personal,
  business;

  String get displayName => switch (this) {
    personal => 'Personal',
    business => 'Negocios',
  };

  static ConversationAgentId fromName(String value) => switch (value) {
    'business' => business,
    _ => personal,
  };

  static ConversationAgentId defaultFor({
    required String channel,
    required String appPackage,
  }) {
    if (channel == 'whatsapp.business' ||
        appPackage == MessagingPackage.whatsappBusiness) {
      return business;
    }
    return personal;
  }
}

/// Identidad de una conversación independiente del agente que la atiende.
///
/// El mínimo obligatorio es dueño + cuenta de canal + conversación. El canal
/// y el paquete se conservan explícitos para que dos cuentas o apps nunca
/// colisionen aunque publiquen el mismo id externo.
final class ConversationAddress {
  static const localOwnerId = 'local-owner';

  final String ownerId;
  final String channel;
  final String appPackage;
  final String channelAccountId;
  final String conversationId;

  const ConversationAddress({
    required this.ownerId,
    required this.channel,
    required this.appPackage,
    required this.channelAccountId,
    required this.conversationId,
  });

  factory ConversationAddress.fromKey(
    ConversationKey key, {
    String ownerId = localOwnerId,
  }) => ConversationAddress(
    ownerId: ownerId,
    channel: key.channel,
    appPackage: key.appPackage,
    channelAccountId: key.accountFingerprint.isEmpty
        ? '${key.appPackage}:default'
        : '${key.appPackage}:${key.accountFingerprint}',
    conversationId: key.id,
  );

  /// Compatibilidad para datos v1, donde solo se persistía [ConversationKey.id].
  factory ConversationAddress.fromConversationId(
    String conversationId, {
    String ownerId = localOwnerId,
  }) {
    final parts = conversationId.split('/');
    final channel = parts.isNotEmpty ? parts.first : '';
    final appPackage = parts.length > 1 ? parts[1] : channel;
    final account = parts.length > 2 ? parts[2] : '-';
    return ConversationAddress(
      ownerId: ownerId,
      channel: channel,
      appPackage: appPackage,
      channelAccountId: account == '-' || account.isEmpty
          ? '$appPackage:default'
          : '$appPackage:$account',
      conversationId: conversationId,
    );
  }

  String get addressKey =>
      'addr:v1:${_encoded(<String>[ownerId, channel, appPackage, channelAccountId, conversationId])}';

  bool get isValid =>
      ownerId.isNotEmpty &&
      channel.isNotEmpty &&
      appPackage.isNotEmpty &&
      channelAccountId.isNotEmpty &&
      conversationId.isNotEmpty;
}

/// Scope de datos de un agente. Transferir una conversación crea/activa otro
/// scope; no renombra ni fusiona la memoria anterior.
final class AgentConversationScope {
  final ConversationAddress address;
  final ConversationAgentId agentId;

  const AgentConversationScope({required this.address, required this.agentId});

  String get id =>
      'scope:v1:${_encoded(<String>[address.ownerId, agentId.name, address.channel, address.appPackage, address.channelAccountId, address.conversationId])}';
}

String _encoded(List<String> parts) =>
    base64Url.encode(utf8.encode(jsonEncode(parts))).replaceAll('=', '');

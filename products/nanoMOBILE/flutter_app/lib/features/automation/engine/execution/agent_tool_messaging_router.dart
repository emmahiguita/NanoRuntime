part of 'agent_tool_dispatcher.dart';

/// Enruta mensajes hacia sus adaptadores existentes, conservando las confirmaciones.
extension _AgentMessagingRouter on AgentToolDispatcher {
  /// Texto y archivos WhatsApp reciben el mismo token del coordinador; no
  /// se crea otro token ni se cancela trabajo de una ejecución diferente.
  Future<String> _executeMessagingTool(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) async {
    switch (call.tool) {
      case 'whatsapp.open_chat' || 'whatsapp_open':
        return _whatsAppHandler.openChat(call);
      case 'whatsapp.send_message' || 'whatsapp_send':
        return _whatsAppHandler.sendMessage(call, cancellation: cancellation);
      case 'whatsapp.share_file' || 'whatsapp.send_file' || 'whatsapp_share':
        return _whatsAppHandler.shareFile(call, cancellation: cancellation);
      case 'whatsapp.contacts' || 'whatsapp_contacts':
        return _whatsAppHandler.listContacts(call);
      case 'telegram.open_chat' || 'telegram_open' || 'tg_open':
        return _universalMessagingHandler.openChat(
          call,
          defaultPackage: 'org.telegram.messenger',
          appName: 'Telegram',
        );
      case 'telegram.send_message' || 'telegram_send' || 'tg_send':
        return _universalMessagingHandler.sendMessage(
          call,
          defaultPackage: 'org.telegram.messenger',
          appName: 'Telegram',
        );
      case 'telegram.share_file' || 'telegram_share' || 'tg_share':
        return _universalMessagingHandler.shareFile(
          call,
          defaultPackage: 'org.telegram.messenger',
          appName: 'Telegram',
        );
      case 'telegram.contacts' || 'telegram_contacts' || 'tg_contacts':
        return _universalMessagingHandler.listContacts(call);
      case 'messenger.open_chat' ||
          'messenger_open' ||
          'fb_open' ||
          'facebook_open':
        return _universalMessagingHandler.openChat(
          call,
          defaultPackage: 'com.facebook.orca',
          appName: 'Messenger',
        );
      case 'messenger.send_message' ||
          'messenger_send' ||
          'fb_send' ||
          'facebook_send':
        return _universalMessagingHandler.sendMessage(
          call,
          defaultPackage: 'com.facebook.orca',
          appName: 'Messenger',
        );
      case 'messenger.share_file' ||
          'messenger_share' ||
          'fb_share' ||
          'facebook_share':
        return _universalMessagingHandler.shareFile(
          call,
          defaultPackage: 'com.facebook.orca',
          appName: 'Messenger',
        );
      case 'device.set_alarm' || 'set_alarm' || 'alarma' || 'alarm':
        return _alarmHandler.execute(call);
      default:
        return '[toolUnknown] Canal de mensajería desconocido.';
    }
  }
}

/// Alias existentes: se evalúan juntos para no perder alternativas durante la separación.
const _agentMessagingAliases = {
  'whatsapp.open_chat',
  'whatsapp_open',
  'whatsapp.send_message',
  'whatsapp_send',
  'whatsapp.share_file',
  'whatsapp.send_file',
  'whatsapp_share',
  'whatsapp.contacts',
  'whatsapp_contacts',
  'telegram.open_chat',
  'telegram_open',
  'tg_open',
  'telegram.send_message',
  'telegram_send',
  'tg_send',
  'telegram.share_file',
  'telegram_share',
  'tg_share',
  'telegram.contacts',
  'telegram_contacts',
  'tg_contacts',
  'messenger.open_chat',
  'messenger_open',
  'fb_open',
  'facebook_open',
  'messenger.send_message',
  'messenger_send',
  'fb_send',
  'facebook_send',
  'messenger.share_file',
  'messenger_share',
  'fb_share',
  'facebook_share',
  'device.set_alarm',
  'set_alarm',
  'alarma',
  'alarm',
};

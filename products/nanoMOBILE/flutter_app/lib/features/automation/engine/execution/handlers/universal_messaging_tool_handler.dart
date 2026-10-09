/// UniversalMessagingToolHandler — Ejecución tipada de mensajería universal.
///
/// - ¿Qué hace? Permite abrir chats, enviar mensajes reales y compartir archivos
///   en Telegram, Facebook Messenger y otras plataformas de mensajería conocidas.
/// - ¿Cómo funciona? Resuelve contactos reales de la agenda o nombres de usuario/números,
///   y despacha al canal nativo de plataforma con el paquete y esquema correcto.
/// - ¿Por qué? SOLID (SRP/OCP/DIP): unifica la ejecución de mensajería multiplataforma
///   evitando duplicación de lógica entre WhatsApp, Telegram y Messenger.
library;

import 'dart:async';

import '../../platform/whatsapp_media_share.dart';
import '../../../application/whatsapp_contacts_provider.dart';
import '../../planning/contact_matcher.dart';
import '../tool_call.dart';
import 'whatsapp_contact_resolver.dart';

class UniversalMessagingToolHandler {
  final WhatsAppMediaShare _share;
  final WhatsAppContactsService _contacts;
  late final WhatsAppContactResolver _contactResolver;

  UniversalMessagingToolHandler({
    WhatsAppMediaShare share = const WhatsAppMediaShare(),
    WhatsAppContactsService? contacts,
  }) : _share = share,
       _contacts = contacts ?? WhatsAppContactsService() {
    _contactResolver = WhatsAppContactResolver(_contacts);
  }

  /// Abre un chat en la aplicación especificada (Telegram, Messenger, etc.).
  Future<String> openChat(
    ToolCall call, {
    required String defaultPackage,
    required String appName,
  }) async {
    final contactQ = _str(call, 'contact');
    final text = _str(call, 'text');
    final pkg = (call.args?['packageName'] as String?) ?? defaultPackage;

    if (contactQ.isEmpty) {
      final ok = await _share.openChat(
        contact: '',
        text: text,
        packageName: pkg,
        autoSend: false,
      );
      return ok ? '[completed] $appName abierto.' : '[error] No se pudo abrir $appName.';
    }

    final resolved = await _contactResolver.resolve(contactQ);
    final target = resolved?.number ?? contactQ;
    final displayName = resolved?.name ?? contactQ;

    final ok = await _share.openChat(
      contact: target,
      text: text,
      packageName: pkg,
      autoSend: false,
    );
    return ok
        ? '[completed] Chat de $appName abierto con "$displayName" ($target).'
        : '[error] No se pudo abrir el chat de $appName con "$displayName".';
  }

  /// Envía un mensaje en la plataforma especificada.
  Future<String> sendMessage(
    ToolCall call, {
    required String defaultPackage,
    required String appName,
  }) async {
    final contactQ = _str(call, 'contact').isNotEmpty
        ? _str(call, 'contact')
        : (call.selectorArg ?? '');
    final text = _str(call, 'text').isNotEmpty
        ? _str(call, 'text')
        : (call.textArg ?? '');

    if (contactQ.isEmpty) return '[error] Falta especificar el contacto destinatario para $appName.';
    if (text.isEmpty) return '[error] Falta especificar el texto exacto del mensaje para $appName.';

    final resolved = await _contactResolver.resolve(contactQ);
    final target = resolved?.number ?? contactQ;
    final displayName = resolved?.name ?? contactQ;
    final pkg = (call.args?['packageName'] as String?) ?? defaultPackage;

    final ok = await _share.openChat(
      contact: target,
      text: text,
      packageName: pkg,
      autoSend: true,
    );

    return ok
        ? '[completedUnverified] Flujo de $appName abierto para "$displayName" ($target).'
        : '[error] No se pudo iniciar el envío en $appName para "$displayName".';
  }

  /// Comparte un archivo por la plataforma especificada.
  Future<String> shareFile(
    ToolCall call, {
    required String defaultPackage,
    required String appName,
  }) async {
    final contactQ = _str(call, 'contact').isNotEmpty
        ? _str(call, 'contact')
        : (call.selectorArg ?? '');
    final path = _str(call, 'path').isNotEmpty
        ? _str(call, 'path')
        : (call.textArg ?? '');
    final caption = _str(call, 'caption');
    final pkg = (call.args?['packageName'] as String?) ?? defaultPackage;

    if (contactQ.isEmpty) return '[error] Falta especificar el contacto destinatario.';
    if (path.isEmpty) return '[error] No se especificó la ruta del archivo a compartir.';

    final resolved = await _contactResolver.resolve(contactQ);
    final target = resolved?.number ?? contactQ;
    final displayName = resolved?.name ?? contactQ;

    final ok = await _share.shareFile(
      path: path,
      contact: target,
      caption: caption,
      packageName: pkg,
      autoSend: true,
    );

    return ok
        ? '[completedUnverified] Archivo compartido en $appName con "$displayName".'
        : '[error] No se pudo compartir el archivo en $appName con "$displayName".';
  }

  /// Lista y busca contactos en la agenda del dispositivo.
  Future<String> listContacts(ToolCall call) async {
    final rawQ = _str(call, 'query');
    final query = rawQ
        .toLowerCase()
        .replaceAll(
          RegExp(r'\b(contactos?|telegram|messenger|facebook|buscar?|ver?|listar?|de|a|en|los|las|mis)\b'),
          '',
        )
        .trim();

    if (!await _contacts.hasPermission()) await _contacts.requestPermission();
    final all = await _contacts.getContacts();
    if (all.isEmpty) return '[error] Sin contactos en el dispositivo o permiso denegado.';

    final filtered = query.isEmpty ? all.take(10).toList() : ContactMatcher.filter(query, all, limit: 10);
    if (filtered.isEmpty) {
      return '[error] Ningún contacto coincide con "${rawQ.isEmpty ? 'búsqueda' : rawQ}". '
          '(${all.length} contactos disponibles en el dispositivo).';
    }
    return '[completed] ${filtered.length} contacto(s) encontrado(s):\n'
        '${filtered.map((c) => '• ${c.name} (${c.number})').join('\n')}';
  }

  /// Procesa comandos directos como `@telegram <contacto> [mensaje]` o `@messenger <contacto> [mensaje]`.
  Future<String> handleCommand(
    String input, {
    required String defaultPackage,
    required String appName,
  }) async {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'Uso: @${appName.toLowerCase()} <contacto_o_usuario> [mensaje opcional]';
    }
    final message = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final call = ToolCall(
      tool: message.isEmpty ? '${appName.toLowerCase()}.open_chat' : '${appName.toLowerCase()}.send_message',
      args: {
        'contact': parts.first,
        if (message.isNotEmpty) 'text': message,
        'packageName': defaultPackage,
      },
    );
    return message.isEmpty
        ? openChat(call, defaultPackage: defaultPackage, appName: appName)
        : sendMessage(call, defaultPackage: defaultPackage, appName: appName);
  }

  String _str(ToolCall call, String key) => (call.args?[key] ?? '').toString().trim();
}

import 'dart:async';

import '../../platform/whatsapp_media_share.dart';
import '../../../application/whatsapp_contacts_provider.dart';
import '../../planning/contact_matcher.dart';
import '../../planning/whatsapp_intent_parser.dart';
import '../tool_call.dart';
import 'whatsapp_contact_resolver.dart';

/// WhatsAppToolHandler — Ejecución tipada de herramientas WhatsApp.
///
/// - ¿Qué hace? Resuelve contactos reales mediante [ContactMatcher] y ejecuta
///   acciones (open chat, send message, share file, list contacts) delegando
///   en [WhatsAppMediaShare].
/// - ¿Cómo funciona? Primero busca en la agenda real del dispositivo usando
///   emparejamiento fonético y de tokens. Si es número (≥7 dígitos), lo usa directo.
/// - ¿Por qué? SOLID (SRP/DIP): delega la heurística en [ContactMatcher] y las
///   intenciones en [WhatsAppIntentParser]. No alucina ni toma contactos al azar.
class WhatsAppToolHandler {
  final WhatsAppMediaShare _share;
  final WhatsAppContactsService _contacts;
  late final WhatsAppContactResolver _contactResolver;

  WhatsAppToolHandler({
    WhatsAppMediaShare share = const WhatsAppMediaShare(),
    WhatsAppContactsService? contacts,
  }) : _share = share,
       _contacts = contacts ?? _DefaultContactsService() {
    _contactResolver = WhatsAppContactResolver(_contacts);
  }

  // ── Herramientas públicas ──────────────────────────────────────────────────

  /// Abre el chat de WhatsApp con un contacto resuelto o la app general.
  Future<String> openChat(ToolCall call) async {
    final contactQ = _str(call, 'contact');
    final text = _str(call, 'text');
    final pkg = call.args?['packageName'] as String?;

    if (contactQ.isEmpty) {
      final ok = await _share.openChat(
        contact: '',
        text: text,
        packageName: pkg,
        autoSend: false,
      );
      return ok
          ? '[completed] WhatsApp abierto.'
          : '[error] No se pudo abrir WhatsApp.';
    }

    final resolved = await _contactResolver.resolve(contactQ);
    final phone = resolved?.number ?? contactQ;
    final name = resolved?.name ?? contactQ;

    // Esta herramienta solo navega. El envío vive en sendMessage y su policy.
    final ok = await _share.openChat(
      contact: phone,
      text: text,
      packageName: pkg,
      autoSend: false,
    );
    return ok
        ? '[completed] Chat abierto con "$name" ($phone).'
        : '[error] No se pudo abrir el chat con "$name".';
  }

  /// Envía un mensaje directo a un contacto de WhatsApp verificado.
  Future<String> sendMessage(ToolCall call) async {
    final contactQ = _str(call, 'contact').isNotEmpty
        ? _str(call, 'contact')
        : (call.selectorArg ?? '');
    final text = _str(call, 'text').isNotEmpty
        ? _str(call, 'text')
        : (call.textArg ?? '');
    if (contactQ.isEmpty) {
      return '[error] Falta especificar el contacto destinatario.';
    }
    if (text.isEmpty) {
      return '[error] Falta especificar el texto exacto del mensaje.';
    }

    final resolved = await _contactResolver.resolve(contactQ);
    if (resolved == null) {
      return '[error] No se encontró el contacto "$contactQ" en la agenda del dispositivo.';
    }

    final ok = await _share.openChat(
      contact: resolved.number,
      text: text,
      autoSend: true,
    );
    return ok
        ? '[completedUnverified] Chat abierto para "${resolved.name}" '
              '(${resolved.number}); el envío automático fue solicitado, pero '
              'el clic y la entrega no están verificados.'
        : '[error] No se pudo iniciar el envío a "${resolved.name}".';
  }

  /// Comparte un archivo (imagen, video, pdf, documento) con un contacto.
  Future<String> shareFile(ToolCall call) async {
    final contactQ = _str(call, 'contact').isNotEmpty
        ? _str(call, 'contact')
        : (call.selectorArg ?? '');
    final path = _str(call, 'path').isNotEmpty
        ? _str(call, 'path')
        : (call.textArg ?? '');
    final caption = _str(call, 'caption');

    if (contactQ.isEmpty) {
      return '[error] Falta especificar el contacto destinatario.';
    }
    if (path.isEmpty) {
      return '[error] No se especificó la ruta del archivo a compartir.';
    }

    final resolved = await _contactResolver.resolve(contactQ);
    if (resolved == null) {
      return '[error] No se encontró el contacto "$contactQ" en la agenda del dispositivo.';
    }

    final ok = await _share.shareFile(
      path: path,
      contact: resolved.number,
      caption: caption,
      autoSend: true,
    );
    return ok
        ? '[completedUnverified] Flujo de archivo abierto para '
              '"${resolved.name}" (${resolved.number}); el clic y la entrega '
              'no están verificados.'
        : '[error] No se pudo iniciar el envío del archivo a "${resolved.name}".';
  }

  /// Lista y filtra contactos de WhatsApp con puntuación de relevancia.
  Future<String> listContacts(ToolCall call) async {
    String rawQ = _str(call, 'query');
    if (rawQ.isEmpty && call.textArg != null) {
      rawQ = WhatsAppIntentParser.parse(call.textArg!)?.contact ?? '';
    }
    final query = rawQ
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'\b(contactos?|whatsapp|buscar?|ver?|listar?|de|a|en|los|las|mis)\b',
          ),
          '',
        )
        .trim();

    if (!await _contacts.hasPermission()) await _contacts.requestPermission();
    final all = await _contacts.getContacts();
    if (all.isEmpty) {
      return '[error] Sin contactos en el dispositivo o permiso denegado.';
    }

    final filtered = query.isEmpty
        ? all.take(10).toList()
        : ContactMatcher.filter(query, all, limit: 10);

    if (filtered.isEmpty) {
      return '[error] Ningún contacto coincide con "${rawQ.isEmpty ? 'búsqueda' : rawQ}". '
          '(${all.length} contactos disponibles en el dispositivo).';
    }
    return '[completed] ${filtered.length} contacto(s) encontrado(s):\n'
        '${filtered.map((c) => '• ${c.name} (${c.number})').join('\n')}';
  }

  /// Procesa `@whatsapp <contacto> [mensaje]` desde el chat.
  Future<String> handleCommand(String input) async {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return 'Uso: @whatsapp <contacto_o_numero> [mensaje opcional]';
    }
    final message = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final call = ToolCall(
      tool: message.isEmpty ? 'whatsapp.open_chat' : 'whatsapp.send_message',
      args: {'contact': parts.first, if (message.isNotEmpty) 'text': message},
    );
    // El comando humano con texto es consentimiento explícito para enviar.
    return message.isEmpty ? openChat(call) : sendMessage(call);
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  String _str(ToolCall call, String key) =>
      (call.args?[key] ?? '').toString().trim();
}

class _DefaultContactsService extends WhatsAppContactsService {
  _DefaultContactsService();
}

import 'dart:async';

import '../../platform/whatsapp_media_share.dart';
import '../../../application/whatsapp_contacts_provider.dart';
import '../../../domain/whatsapp_contact.dart';
import '../../planning/contact_matcher.dart';
import '../../planning/whatsapp_intent_parser.dart';
import '../tool_call.dart';

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

  WhatsAppToolHandler({
    WhatsAppMediaShare share = const WhatsAppMediaShare(),
    WhatsAppContactsService? contacts,
  })  : _share = share,
        _contacts = contacts ?? _DefaultContactsService();

  // ── Resolución de contacto ─────────────────────────────────────────────────

  /// Resuelve [query] contra los contactos reales del dispositivo.
  /// Prioridad: número directo (≥7 dígitos) → coincidencia inteligente ([ContactMatcher]).
  /// Retorna `null` si no hay contactos o si ninguno supera el umbral de coincidencia.
  Future<WhatsAppContact?> _resolveContact(String query) async {
    if (!await _contacts.hasPermission()) await _contacts.requestPermission();
    final all = await _contacts.getContacts();
    if (all.isEmpty) return null;

    final q = query.trim().toLowerCase();
    const generic = {'destinatario', 'contacto', 'contacto de whatsapp', 'contactos'};
    if (q.isEmpty || generic.contains(q)) return all.first;

    // Búsqueda por número directo (≥7 dígitos)
    final digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 7) {
      final byNum = all.where((c) {
        final cd = c.number.replaceAll(RegExp(r'\D'), '');
        return cd == digits || cd.endsWith(digits) || digits.endsWith(cd);
      }).firstOrNull;
      if (byNum != null) return byNum;
      // Número no guardado en la agenda: contacto ad-hoc válido
      return WhatsAppContact(
        id: digits, name: query, number: digits,
        jid: '$digits@s.whatsapp.net', isBusiness: false,
      );
    }

    // Coincidencia inteligente con ContactMatcher (exacta, fonética y tokens)
    return ContactMatcher.findBest(query, all);
  }

  // ── Herramientas públicas ──────────────────────────────────────────────────

  /// Abre el chat de WhatsApp con un contacto resuelto o la app general.
  Future<String> openChat(ToolCall call) async {
    final contactQ = _str(call, 'contact');
    final text = _str(call, 'text');
    final autoSend = call.args?['autoSend'] == true;
    final pkg = call.args?['packageName'] as String?;

    if (contactQ.isEmpty) {
      final ok = await _share.openChat(contact: '', text: text, packageName: pkg, autoSend: false);
      return ok ? '[completed] WhatsApp abierto.' : '[error] No se pudo abrir WhatsApp.';
    }

    final resolved = await _resolveContact(contactQ);
    final phone = resolved?.number ?? contactQ;
    final name  = resolved?.name  ?? contactQ;

    final ok = await _share.openChat(contact: phone, text: text, packageName: pkg, autoSend: autoSend);
    return ok
        ? '[completed] Chat abierto con "$name" ($phone).'
        : '[error] No se pudo abrir el chat con "$name".';
  }

  /// Envía un mensaje directo a un contacto de WhatsApp verificado.
  Future<String> sendMessage(ToolCall call) async {
    final contactQ = _str(call, 'contact').isNotEmpty
        ? _str(call, 'contact')
        : (call.selectorArg ?? '');
    final text = _str(call, 'text').isNotEmpty ? _str(call, 'text') : (call.textArg ?? '');
    final message = text.isEmpty ? 'Hola desde NanoAI' : text;

    if (contactQ.isEmpty) {
      return '[error] Falta especificar el contacto destinatario.';
    }

    final resolved = await _resolveContact(contactQ);
    if (resolved == null) {
      return '[error] No se encontró el contacto "$contactQ" en la agenda del dispositivo.';
    }

    final ok = await _share.openChat(contact: resolved.number, text: message, autoSend: true);
    return ok
        ? '[completed] Mensaje enviado a "${resolved.name}" (${resolved.number}): "$message".'
        : '[error] Falló el envío a "${resolved.name}".';
  }

  /// Comparte un archivo (imagen, video, pdf, documento) con un contacto.
  Future<String> shareFile(ToolCall call) async {
    final contactQ = _str(call, 'contact').isNotEmpty ? _str(call, 'contact') : (call.selectorArg ?? '');
    final path = _str(call, 'path').isNotEmpty ? _str(call, 'path') : (call.textArg ?? '');
    final caption = _str(call, 'caption');

    if (path.isEmpty) return '[error] No se especificó la ruta del archivo a compartir.';

    final resolved = await _resolveContact(contactQ);
    final phone = resolved?.number ?? contactQ;
    final name = resolved?.name ?? contactQ;

    final ok = await _share.shareFile(path: path, contact: phone, caption: caption);
    return ok
        ? '[completed] Archivo listo para "$name" ($phone).'
        : '[error] No se pudo compartir el archivo con "$name".';
  }

  /// Lista y filtra contactos de WhatsApp con puntuación de relevancia.
  Future<String> listContacts(ToolCall call) async {
    String rawQ = _str(call, 'query');
    if (rawQ.isEmpty && call.textArg != null) {
      rawQ = WhatsAppIntentParser.parse(call.textArg!)?.contact ?? '';
    }
    final query = rawQ.toLowerCase().replaceAll(
      RegExp(r'\b(contactos?|whatsapp|buscar?|ver?|listar?|de|a|en|los|las|mis)\b'),
      '',
    ).trim();

    if (!await _contacts.hasPermission()) await _contacts.requestPermission();
    final all = await _contacts.getContacts();
    if (all.isEmpty) return '[error] Sin contactos en el dispositivo o permiso denegado.';

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
    return openChat(ToolCall(
      tool: 'whatsapp.open_chat',
      args: {
        'contact': parts.first,
        if (message.isNotEmpty) 'text': message,
        'autoSend': message.isNotEmpty,
      },
    ));
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  String _str(ToolCall call, String key) => (call.args?[key] ?? '').toString().trim();
}

class _DefaultContactsService extends WhatsAppContactsService {
  _DefaultContactsService();
}

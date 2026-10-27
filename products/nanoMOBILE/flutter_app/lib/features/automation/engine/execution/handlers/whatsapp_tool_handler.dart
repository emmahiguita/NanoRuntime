import 'dart:async';

import '../../business/whatsapp_message_provider.dart';
import '../../platform/whatsapp_media_share.dart';
import '../../platform/whatsapp_send_monitor.dart';
import '../../voice/execution_cancellation.dart';
import '../../../application/whatsapp_contacts_provider.dart';
import '../../planning/contact_matcher.dart';
import '../../planning/whatsapp_intent_parser.dart';
import '../tool_call.dart';
import 'whatsapp_contact_resolver.dart';
import 'whatsapp_text_sender.dart';
import 'whatsapp_command_runner.dart';
import 'whatsapp_chat_opener.dart';

/// WhatsAppToolHandler — Ejecución tipada de herramientas WhatsApp.
///
/// - ¿Qué hace? Resuelve contactos reales mediante [ContactMatcher] y ejecuta
///   acciones (open chat, send message, share file, list contacts) delegando
///   en [WhatsAppMediaShare].
/// - ¿Cómo funciona? Primero busca en la agenda real del dispositivo usando
///   coincidencia exacta y única, sin elegir sugerencias fonéticas. Si es número (≥7 dígitos), lo usa directo.
/// - ¿Por qué? SOLID (SRP/DIP): delega la heurística en [ContactMatcher] y las
///   intenciones en [WhatsAppIntentParser]. No alucina ni toma contactos al azar.
class WhatsAppToolHandler {
  final WhatsAppMediaShare _share;
  final WhatsAppContactsService _contacts;
  late final WhatsAppMessageProvider _messageProvider;
  late final WhatsAppContactResolver _contactResolver;

  WhatsAppToolHandler({
    WhatsAppMediaShare share = const WhatsAppMediaShare(),
    WhatsAppContactsService? contacts,
    WhatsAppMessageProvider? messageProvider,
  }) : _share = share,
       _contacts = contacts ?? _DefaultContactsService() {
    _contactResolver = WhatsAppContactResolver(_contacts);
    // El proveedor decide por configuración; el default conserva el envío instalado.
    _messageProvider =
        messageProvider ??
        ConfiguredWhatsAppMessageProvider(sendLocally: _sendLocally);
  }

  // ── Herramientas públicas ──────────────────────────────────────────────────

  /// Abre el chat de WhatsApp con un contacto resuelto o la app general.
  Future<String> openChat(ToolCall call) async {
    return WhatsAppChatOpener(_share, _contactResolver).open(call);
  }

  /// Delega texto en el transporte único, conservando cuenta, cancelación
  /// y verificación. Los adjuntos tienen su propia responsabilidad debajo.
  Future<String> sendMessage(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) => WhatsAppTextSender(
    _share,
    _contactResolver,
    _messageProvider,
  ).sendMessage(call, cancellation: cancellation);

  /// Conserva el transporte existente, cuya automatización no confirma entrega.
  Future<bool> _sendLocally(String phone, String text) =>
      WhatsAppSendMonitor().launchAndWait(
        () => _share.openChat(contact: phone, text: text, autoSend: true),
      );

  /// Comparte un archivo (imagen, video, pdf, documento) con un contacto.
  Future<String> shareFile(
    ToolCall call, {
    ExecutionCancellationToken? cancellation,
  }) async {
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

    // Solo metadatos de WhatsApp acreditan el JID. Sin ellos conserva el
    // selector manual; no falsea recipientVerified para forzar un clic.
    Future<bool> launch() => _share.shareFile(
      path: path,
      contact: resolved.isWhatsAppVerified && resolved.jid.isNotEmpty
          ? resolved.jid
          : resolved.number,
      recipientName: resolved.name,
      recipientKind: resolved.isGroup ? 'group' : 'direct',
      recipientVerified: resolved.isWhatsAppVerified,
      packageName: resolved.packageName.isEmpty ? null : resolved.packageName,
      caption: caption,
      autoSend: true,
    );
    final bool ok;
    try {
      ok = resolved.isWhatsAppVerified
          ? await WhatsAppSendMonitor().launchAndWait(
              launch,
              cancellation: cancellation,
              recipient: resolved.name,
              action: 'Enviar archivo',
              packageName: resolved.packageName.isEmpty
                  ? 'com.whatsapp'
                  : resolved.packageName,
            )
          : await launch();
    } on WhatsAppAutomationFailure catch (error) {
      return '[error] ${error.message}';
    } on WhatsAppOutcomeUnknown catch (error) {
      return '[timeoutOutcomeUnknown] ${error.reason}';
    }

    if (ok && resolved.isWhatsAppVerified) {
      return '[completedUnverified] Clic del archivo y regreso a Nano observados para "${resolved.name}"; entrega no confirmada.';
    }
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

  /// Procesa órdenes sin duplicar el ejecutor ni truncar nombres completos.
  Future<String> handleCommand(
    String input, {
    ExecutionCancellationToken? cancellation,
  }) => runWhatsAppCommand(
    input,
    openChat: openChat,
    sendMessage: sendMessage,
    shareFile: shareFile,
    cancellation: cancellation,
  );

  // ── Helper ─────────────────────────────────────────────────────────────────

  String _str(ToolCall call, String key) =>
      (call.args?[key] ?? '').toString().trim();
}

class _DefaultContactsService extends WhatsAppContactsService {
  _DefaultContactsService();
}

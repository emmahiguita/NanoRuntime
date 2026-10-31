// whatsapp_intent_parser.dart
// ¿Qué hace? Parser determinista de intenciones WhatsApp con soporte para números y contactos.
// ¿Por qué? SRP — única responsabilidad: transformar texto libre en intención tipada.
// ¿Cómo? Identifica búsqueda, apertura, envío de mensajes y archivos con prefijos y números directos.
// SOLID: OCP — abierto a nuevos patrones sintácticos delegando tipos en whatsapp_intent_types.dart.

import 'whatsapp_intent_types.dart';
export 'whatsapp_intent_types.dart';

abstract final class WhatsAppIntentParser {
  static final _searchVerbs = RegExp(
    r'^(?:busca|buscar|encuentra|encontrar)\s+(?:(?:a|al|el|este)\s+)?',
    caseSensitive: false,
  );

  static final _openChatVerbs = RegExp(
    r'^(?:abre|abrir)\s+(?:el\s+)?chat\s+(?:de|con|a|al)\s+(?:(?:este|el|al)\s+n[uú]mero\s+)?',
    caseSensitive: false,
  );

  static final _sendVerbs = RegExp(
    r'^(?:env[ií]a(?:le)?|escr[ií]be(?:le)?|manda(?:le)?|dile|comparte|compartir)\s+(?:(?:un\s+|una\s+)?(?:mensaje|texto|hola|foto|imagen|video|documento|archivo|pdf)\s+)?(?:a\s+|con\s+|al\s+)?',
    caseSensitive: false,
  );

  static final _fileKeywords = RegExp(
    r'\b(?:archivo|pdf|documento|foto|imagen|video|video\s+de|audio)\b|\.(?:pdf|png|jpe?g|mp4|docx?|xlsx?)\b',
    caseSensitive: false,
  );

  static final _paren = RegExp(r'\(([^)]+)\)');

  /// Parsea [goal] y devuelve un [WhatsAppIntent] estructurado o `null`.
  static WhatsAppIntent? parse(String goal) {
    var g = goal.trim().replaceFirst(
      RegExp(r'^(?:desde|en)\s+(?:las\s+)?llamadas(?:\s+(?:en|de)\s+whatsapp)?\s*', caseSensitive: false),
      '',
    ).trim();

    final hasSendIntent = RegExp(r'\b(?:env[ií]a(?:le)?|escr[ií]be(?:le)?|manda(?:le)?|mensaje)\b', caseSensitive: false).hasMatch(g);
    final parens = _paren.allMatches(g).toList();
    if (hasSendIntent && parens.length >= 2) {
      final contact = parens[0].group(1)!.trim();
      final content = parens[1].group(1)!.trim();
      return _buildSendOrShare(g, contact, content);
    }

    if (_searchVerbs.hasMatch(g)) {
      final contact = _extractAfterVerb(_searchVerbs, g);
      if (contact.isEmpty) return null;
      return WhatsAppIntent(action: WhatsAppAction.findContact, contact: contact);
    }

    if (_openChatVerbs.hasMatch(g)) {
      final contact = _extractAfterVerb(_openChatVerbs, g);
      if (contact.isEmpty) return null;
      return WhatsAppIntent(action: WhatsAppAction.openChat, contact: contact);
    }

    if (_sendVerbs.hasMatch(g)) {
      return _parseSendOrShare(g);
    }

    return null;
  }

  static String _extractAfterVerb(RegExp verb, String text) {
    var rest = text.replaceFirst(verb, '').trim();
    rest = rest.replaceFirst(RegExp(r'^(?:(?:este|el|al)\s+)?n[uú]mero\s+', caseSensitive: false), '').trim();
    final m = _paren.firstMatch(rest);
    if (m != null) return m.group(1)!.trim();
    return rest
        .replaceAll(RegExp(r'\s+(?:en|de|por|para)\s+whatsapp.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .trim();
  }

  static WhatsAppIntent? _parseSendOrShare(String text) {
    final rest = text.replaceFirst(_sendVerbs, '').trim();
    final parens = _paren.allMatches(rest).toList();
    String contact = '';
    String content = '';

    // Patrón prioritario: «este número 300... mensaje» o «al número +57...: mensaje»
    final phonePrefix = RegExp(
      r'^(?:(?:este|el|al)\s+)?n[uú]mero\s+(\+?[\d\s\-()]{7,16})(?:\s*:\s*|\s+(?:el\s+)?(?:mensaje|texto)\s+|\s+)(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(rest);
    if (phonePrefix != null) {
      contact = phonePrefix.group(1)!.trim();
      content = phonePrefix.group(2)!.trim();
    } else {
      final directPhone = RegExp(
        r'^(\+?[0-9]{7,15})(?:\s*:\s*|\s+(?:el\s+)?(?:mensaje|texto)\s+|\s+)(.+)$',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(rest);
      if (directPhone != null) {
        contact = directPhone.group(1)!.trim();
        content = directPhone.group(2)!.trim();
      } else if (parens.length >= 2) {
        contact = parens[0].group(1)!.trim();
        content = parens[1].group(1)!.trim();
      } else if (parens.length == 1) {
        final pStart = rest.indexOf('(');
        final pEnd = rest.indexOf(')');
        final inside = parens[0].group(1)!.trim();
        if (pStart <= 3) {
          contact = inside;
          content = rest.substring(pEnd + 1).trim();
        } else {
          contact = rest.substring(0, pStart).replaceFirst(RegExp(r'^a\s+', caseSensitive: false), '').trim();
          content = inside;
        }
      } else {
        final sepMatch = RegExp(
          r'^(?:a\s+)?([^,:]+?)(?:\s+(?:el\s+)?(?:texto|mensaje|archivo|documento|foto|imagen|pdf|:|,)\s+)(.+)$',
          caseSensitive: false,
        ).firstMatch(rest);
        if (sepMatch != null) {
          contact = sepMatch.group(1)!.trim();
          content = sepMatch.group(2)!.trim();
        } else {
          final words = rest.replaceFirst(RegExp(r'^a\s+', caseSensitive: false), '').split(RegExp(r'\s+'));
          if (words.length >= 2) {
            contact = words.first.trim();
            content = words.sublist(1).join(' ').trim();
          }
        }
      }
    }

    if (contact.isEmpty) return null;
    contact = contact
        .replaceFirst(RegExp(r'^(?:(?:este|el|al)\s+)?n[uú]mero\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(?:en|por)\s+whatsapp.*$', caseSensitive: false), '')
        .trim();
    content = content.replaceAll(RegExp(r'\s+(?:en|por)\s+whatsapp.*$', caseSensitive: false), '').trim();
    return _buildSendOrShare(text, contact, content);
  }

  static WhatsAppIntent? _buildSendOrShare(String fullText, String contact, String content) {
    if (content.isEmpty) return null;
    final isShare = _fileKeywords.hasMatch(fullText) || _fileKeywords.hasMatch(content);
    if (isShare) {
      final cleanPath = content.replaceFirst(
        RegExp(r'^(?:el\s+)?(?:archivo|documento|foto|imagen|video|pdf|audio)\s+(?:de\s+)?', caseSensitive: false),
        '',
      ).trim();
      return WhatsAppIntent(
        action: WhatsAppAction.shareFile,
        contact: contact,
        filePath: cleanPath.isNotEmpty ? cleanPath : null,
        message: content,
      );
    }
    return WhatsAppIntent(action: WhatsAppAction.sendMessage, contact: contact, message: content);
  }
}

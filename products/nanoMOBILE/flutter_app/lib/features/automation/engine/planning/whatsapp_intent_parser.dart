// whatsapp_intent_parser.dart
// ¿Qué hace? Parser determinista de intenciones WhatsApp con lenguaje natural.
// ¿Por qué? SRP — única responsabilidad: transformar texto libre en intención tipada.
// ¿Cómo? Soporta sintaxis con/sin paréntesis, envío de mensajes y archivos (pdf/img/video/doc).
// SOLID: OCP — extensible a nuevos comandos sin alterar handlers de ejecución.

import 'package:flutter/foundation.dart';

// ── Tipos de intención ────────────────────────────────────────────────────────

/// Tipos de acción reconocidos para WhatsApp.
enum WhatsAppAction { findContact, openChat, sendMessage, shareFile }

/// Representación tipada de una intención de WhatsApp.
@immutable
class WhatsAppIntent {
  final WhatsAppAction action;
  final String contact;   // Nombre o número del destinatario
  final String? message;  // Texto del mensaje (si aplica)
  final String? filePath; // Ruta del archivo a compartir (si aplica)

  const WhatsAppIntent({
    required this.action,
    required this.contact,
    this.message,
    this.filePath,
  });
}

// ── Parser ────────────────────────────────────────────────────────────────────

abstract final class WhatsAppIntentParser {
  static final _searchVerbs = RegExp(
    r'^(?:busca|buscar|encuentra|encontrar)\s+a\s+',
    caseSensitive: false,
  );

  static final _openChatVerbs = RegExp(
    r'^(?:abre|abrir)\s+(?:el\s+)?chat\s+(?:de|con|a)\s+',
    caseSensitive: false,
  );

  static final _sendVerbs = RegExp(
    r'^(?:env[ií]a(?:le)?|escr[ií]be(?:le)?|manda(?:le)?|dile|comparte|compartir)\s+(?:(?:un\s+|una\s+)?(?:mensaje|texto|hola|foto|imagen|video|documento|archivo|pdf)\s+)?(?:a\s+|con\s+)?',
    caseSensitive: false,
  );


  static final _fileKeywords = RegExp(
    r'\b(?:archivo|pdf|documento|foto|imagen|video|video\s+de|audio)\b|\.(?:pdf|png|jpe?g|mp4|docx?|xlsx?)\b',
    caseSensitive: false,
  );

  static final _paren = RegExp(r'\(([^)]+)\)');

  /// Parsea [goal] y devuelve un [WhatsAppIntent] estructurado o `null`.
  static WhatsAppIntent? parse(String goal) {
    var g = goal.trim();

    // Normalizar prefijos contextuales como "desde llamadas (en whatsapp)..."
    g = g.replaceFirst(
      RegExp(
        r'^(?:desde|en)\s+(?:las\s+)?llamadas(?:\s+(?:en|de)\s+whatsapp)?\s*',
        caseSensitive: false,
      ),
      '',
    ).trim();

    // Intención combinada de buscar contacto y enviar mensaje/archivo (2 paréntesis: contacto y contenido)
    final hasSendIntent = RegExp(
      r'\b(?:env[ií]a(?:le)?|escr[ií]be(?:le)?|manda(?:le)?|mensaje)\b',
      caseSensitive: false,
    ).hasMatch(g);
    final parens = _paren.allMatches(g).toList();
    if (hasSendIntent && parens.length >= 2) {
      final contact = parens[0].group(1)!.trim();
      final content = parens[1].group(1)!.trim();
      final isShare = _fileKeywords.hasMatch(content);
      if (isShare) {
        return WhatsAppIntent(
          action: WhatsAppAction.shareFile,
          contact: contact,
          filePath: content,
          message: content,
        );
      }
      return WhatsAppIntent(
        action: WhatsAppAction.sendMessage,
        contact: contact,
        message: content,
      );
    }

    // 1. Búsqueda de contacto: 'busca a (Poke Suela)' / 'buscar a Luis Higuita'
    if (_searchVerbs.hasMatch(g)) {
      final contact = _extractAfterVerb(_searchVerbs, g);
      if (contact.isEmpty) return null;
      return WhatsAppIntent(action: WhatsAppAction.findContact, contact: contact);
    }

    // 2. Abrir chat: 'abre el chat de (Poke Suela)' / 'abrir chat de Carlos'
    if (_openChatVerbs.hasMatch(g)) {
      final contact = _extractAfterVerb(_openChatVerbs, g);
      if (contact.isEmpty) return null;
      return WhatsAppIntent(action: WhatsAppAction.openChat, contact: contact);
    }

    // 3. Envío de mensaje o archivo: 'envíale a (Poke Suela) (mensaje/archivo)'
    if (_sendVerbs.hasMatch(g)) {
      return _parseSendOrShare(g);
    }

    return null;
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  static String _extractAfterVerb(RegExp verb, String text) {
    final rest = text.replaceFirst(verb, '').trim();
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

    // Caso A: Dos paréntesis -> (Contacto) (Mensaje/Archivo)
    if (parens.length >= 2) {
      contact = parens[0].group(1)!.trim();
      content = parens[1].group(1)!.trim();
    }
    // Caso B: Un paréntesis
    else if (parens.length == 1) {
      final pStart = rest.indexOf('(');
      final pEnd = rest.indexOf(')');
      final insideParen = parens[0].group(1)!.trim();

      // Si el paréntesis está al inicio tras 'a' -> envíale a (Contacto) Mensaje
      if (pStart <= 3) {
        contact = insideParen;
        content = rest.substring(pEnd + 1).trim();
      } else {
        // Contacto antes de paréntesis -> envíale a Contacto (Mensaje)
        contact = rest.substring(0, pStart).replaceFirst(RegExp(r'^a\s+', caseSensitive: false), '').trim();
        content = insideParen;
      }
    }
    // Caso C: Sin paréntesis -> envíale a Contacto: Mensaje / el texto Mensaje
    else {
      final sepMatch = RegExp(
        r'^(?:a\s+)?([^,:]+?)(?:\s+(?:el\s+)?(?:texto|mensaje|archivo|documento|foto|imagen|pdf|:|,)\s+)(.+)$',
        caseSensitive: false,
      ).firstMatch(rest);

      if (sepMatch != null) {
        contact = sepMatch.group(1)!.trim();
        content = sepMatch.group(2)!.trim();
      } else {
        // Fallback: primera palabra tras 'a' como contacto, el resto como mensaje
        final words = rest.replaceFirst(RegExp(r'^a\s+', caseSensitive: false), '').split(RegExp(r'\s+'));
        if (words.length >= 2) {
          contact = words.first.trim();
          content = words.sublist(1).join(' ').trim();
        }
      }
    }

    if (contact.isEmpty) return null;

    // Limpia colas de "en whatsapp"
    contact = contact.replaceAll(RegExp(r'\s+(?:en|por)\s+whatsapp.*$', caseSensitive: false), '').trim();
    content = content.replaceAll(RegExp(r'\s+(?:en|por)\s+whatsapp.*$', caseSensitive: false), '').trim();

    // Determina si es compartir archivo o texto directo
    final isShare = _fileKeywords.hasMatch(text) || _fileKeywords.hasMatch(content);
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


    return WhatsAppIntent(
      action: WhatsAppAction.sendMessage,
      contact: contact,
      message: content.isNotEmpty ? content : 'Hola desde NanoAI',
    );
  }
}

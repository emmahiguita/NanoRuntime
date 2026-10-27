import 'dart:convert';

/// Gramática explícita de respuestas y formularios; no genera contenidos ni
/// descarga enlaces. La identidad delimitada permanece como dato literal.
abstract final class WhatsAppComponentRequests {
  static const quoted = r'"(?:\\.|[^"\\])*"';

  /// Controles del usuario, nunca inferidos del contenido de otra aplicación.
  static bool isConfirm(String text) =>
      text.trim().toLowerCase() == 'confirmar acción';
  static bool isCancel(String text) => const {
    'cancelar acción',
    'cancelar tarea',
    'detener acción',
    'detener tarea',
  }.contains(text.trim().toLowerCase());

  /// Aporta la app antes de la orden, sin añadirla dentro del mensaje. Un
  /// componente WhatsApp no autoriza navegar a otra app por accidente.
  static String scope(String text) {
    final header = text
        .split(RegExp(r':|\s+que\s+|\s+diciendo\s+', caseSensitive: false))
        .first;
    if (RegExp(r'\bwhatsapp\b', caseSensitive: false).hasMatch(header)) {
      return text;
    }
    if (RegExp(
          r'^(?:abre|abrir|entra|ve)\s+',
          caseSensitive: false,
        ).hasMatch(header) &&
        !RegExp(
          r'^(?:abre|abrir|entra|ve)\s+(?:(?:el|la|al|a|en)\s+)?(?:chat|grupo|conversaci[oó]n)\b',
          caseSensitive: false,
        ).hasMatch(header)) {
      throw const FormatException(
        'Desactiva WhatsApp para controlar otra aplicación.',
      );
    }
    return 'Abre WhatsApp y $text';
  }

  /// Objetivos de UI que no caben en una orden atómica del componente.
  static String? uiGoal(String text) =>
      RegExp(
        r'^(?:pulsa|toca|selecciona|busca|escribe|rellena|desliza|navega)\b',
        caseSensitive: false,
      ).hasMatch(text)
      ? scope(text)
      : null;

  /// Solo responde al texto proporcionado, no inventa qué contestar al contacto.
  static String? currentReply(String text) => RegExp(
    r'^(?:responde|contesta)\s+(?:en\s+)?(?:este\s+chat|el\s+chat\s+actual)\s*:\s*(.+)$',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(text.trim())?[1];

  /// La petición de ventana es exacta y separada de enviar texto/archivos.
  static bool isFloating(String text) => RegExp(
    r'^(?:abre|abrir)\s+whatsapp(?:\s+business)?\s+en\s+ventana\s+flotante[.!]?$',
    caseSensitive: false,
  ).hasMatch(text.trim());

  static bool isNavigationSequence(String text) {
    // Las conjunciones de una identidad o payload entre comillas son datos.
    final header = text
        .replaceAll(RegExp(r'"(?:\\.|[^"\\])*"'), '[dato]')
        .split(RegExp(r':|\s+que\s+|\s+diciendo\s+', caseSensitive: false))
        .first;
    return RegExp(
      r'^(?:abre|abrir|entra|ve)\s+.+?(?:[,;]\s*|\s+(?:y|luego)\s+)'
      r'(?:busca|buscar|entra|abre|toca|pulsa|escribe|rellena|env[ií]a)\b',
      caseSensitive: false,
    ).hasMatch(header);
  }

  /// Reserva órdenes de artefacto para la preparación de archivos reales.
  static bool isArtifact(String text) => RegExp(
    r'^(?:comparte|compartir|env[ií]a|enviar)\s+(?:el\s+)?'
    r'(?:producto|cat[aá]logo|pdf|documento)\b',
    caseSensitive: false,
  ).hasMatch(text.trim());

  /// Convierte únicamente un PDF por nombre, enlace explícito o adjunto preparado.
  /// Un enlace permanece texto: no lo abre, rellena ni presenta como PDF.
  static String normalize(String input) {
    final text = input.trim();
    final pdf = RegExp(
      '^(?:comparte|compartir|env[ií]a) el formulario PDF ($quoted) con ($quoted)\$',
      caseSensitive: false,
    ).firstMatch(text);
    if (pdf != null) return 'Comparte el PDF ${pdf[1]} con ${pdf[2]}';
    final link = RegExp(
      '^(?:comparte|compartir|env[ií]a) el formulario ($quoted) con ($quoted)\$',
      caseSensitive: false,
    ).firstMatch(text);
    if (link != null) {
      final url = jsonDecode(link[1]!) as String;
      final target = jsonDecode(link[2]!) as String;
      final uri = Uri.tryParse(url);
      if (target.trim().isEmpty ||
          uri == null ||
          uri.host.isEmpty ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException(
          'Indica un enlace HTTP/HTTPS y destinatario válidos.',
        );
      }
      return 'Envía a ${jsonEncode(target)}: $url';
    }
    return text.replaceFirst(
      RegExp(
        r'^(env[ií]a|manda|comparte|compartir)\s+el\s+formulario\s+adjunto\s+(?:a|con)\s+',
        caseSensitive: false,
      ),
      'Envía el adjunto a ',
    );
  }
}

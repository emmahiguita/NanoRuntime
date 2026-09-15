import 'dart:convert';

/// Formateador especializado de contenido web para el chat de Nano (SRP).
///
/// Transforma respuestas HTTP en bruto (JSON, HTML o texto plano) en
/// mensajes claros, profesionales y en lenguaje natural estructurado con
/// Markdown, eliminando formatos robóticos, JSONs crudos o textos basura tipo SEO.
class WebContentFormatter {
  const WebContentFormatter();

  /// Formatea la respuesta HTTP completa según su tipo de contenido y estructura.
  String format({
    required String rawBody,
    required Uri uri,
    required int statusCode,
  }) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) {
      return '### 🌐 Consulta Web Realizada\n'
          '- **Fuente:** $uri\n'
          '- **Estado:** HTTP $statusCode (Sin contenido de respuesta)';
    }

    // 1. Intentar parsear como JSON estructurado
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return _formatJsonMap(decoded, uri, statusCode);
        } else if (decoded is List) {
          return _formatJsonList(decoded, uri, statusCode);
        }
      } catch (_) {
        // Fallback a procesamiento de texto normal si el parseo falla
      }
    }

    // 2. Procesar como documento HTML
    if (trimmed.contains('<html') || trimmed.contains('<body') || trimmed.contains('<!DOCTYPE')) {
      return _formatHtml(trimmed, uri, statusCode);
    }

    // 3. Procesar como texto plano o CLI format (ej: wttr.in format=3)
    return _formatPlainText(trimmed, uri, statusCode);
  }

  /// Formateo específico para JSON de tipo Map
  String _formatJsonMap(Map<String, dynamic> data, Uri uri, int statusCode) {
    // Caso especial común: Consulta de IP pública (ipify, ifconfig, ipinfo, etc.)
    if (data.containsKey('ip') && data.length <= 4) {
      final ip = data['ip'].toString();
      final buffer = StringBuffer('### 🌐 Información de Red & Conexión\n\n');
      buffer.writeln('- **Dirección IP Pública:** `$ip`');
      buffer.writeln('- **Estado:** Conectado a Internet');
      buffer.writeln('- **Servidor consultado:** ${uri.host}');
      if (data.containsKey('city') || data.containsKey('country')) {
        final loc = [data['city'], data['region'], data['country']]
            .where((e) => e != null && e.toString().isNotEmpty)
            .join(', ');
        if (loc.isNotEmpty) buffer.writeln('- **Ubicación estimada:** $loc');
      }
      return buffer.toString().trim();
    }

    final buffer = StringBuffer('### 🌐 Datos Obtenidos [${uri.host}]\n\n');
    var count = 0;
    for (final entry in data.entries) {
      if (count >= 15) {
        buffer.writeln('\n_… y ${data.length - count} campos adicionales._');
        break;
      }
      final key = _humanizeKey(entry.key);
      final val = entry.value;
      if (val is Map) {
        buffer.writeln('- **$key:**');
        for (final sub in val.entries.take(5)) {
          buffer.writeln('  • ${_humanizeKey(sub.key.toString())}: `${sub.value}`');
        }
      } else if (val is List) {
        buffer.writeln('- **$key:** (${val.length} elementos)');
        for (final item in val.take(4)) {
          buffer.writeln('  • `$item`');
        }
      } else {
        buffer.writeln('- **$key:** `${val ?? "N/A"}`');
      }
      count++;
    }

    buffer.writeln('\n🔍 *Fuente:* $uri');
    return buffer.toString().trim();
  }

  /// Formateo específico para JSON de tipo List
  String _formatJsonList(List<dynamic> list, Uri uri, int statusCode) {
    final buffer = StringBuffer('### 🌐 Lista de Elementos [${uri.host}]\n\n');
    buffer.writeln('Se obtuvieron **${list.length}** registros de la fuente:\n');

    for (final item in list.take(8)) {
      if (item is Map) {
        final title = item['title'] ?? item['name'] ?? item['id'] ?? 'Elemento';
        buffer.writeln('• **$title**');
      } else {
        buffer.writeln('• `$item`');
      }
    }

    if (list.length > 8) {
      buffer.writeln('\n_… y ${list.length - 8} elementos más._');
    }

    buffer.writeln('\n🔍 *Fuente:* $uri');
    return buffer.toString().trim();
  }

  /// Formateo y limpieza de HTML extrayendo contenido útil y descartando ruido SEO
  String _formatHtml(String html, Uri uri, int statusCode) {
    // 1. Extraer título
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    var title = titleMatch?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    title = _decodeHtmlEntities(title);

    // 2. Extraer meta descripción si existe
    final descMatch = RegExp(r'<meta[^>]*name="description"[^>]*content="([^"]*)"', caseSensitive: false).firstMatch(html) ??
        RegExp(r'<meta[^>]*content="([^"]*)"[^>]*name="description"', caseSensitive: false).firstMatch(html);
    var description = descMatch?.group(1)?.trim() ?? '';
    description = _decodeHtmlEntities(description);

    // 3. Remover bloques no deseados (scripts, styles, navs, headers, footers, svg)
    var clean = html;
    clean = clean.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<nav[\s\S]*?</nav>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<header[\s\S]*?</header>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<footer[\s\S]*?</footer>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<aside[\s\S]*?</aside>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<svg[\s\S]*?</svg>', caseSensitive: false), ' ');
    clean = clean.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');

    // 4. Convertir saltos y párrafos en saltos legibles
    clean = clean.replaceAll(RegExp(r'<(?:p|div|br|h[1-6]|li)[^>]*>', caseSensitive: false), '\n');
    clean = clean.replaceAll(RegExp(r'<[^>]*>'), ' ');
    clean = _decodeHtmlEntities(clean);

    // 5. Agrupar líneas y eliminar basura corta/publicidad
    final lines = clean
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.length > 25 && !l.toLowerCase().contains('cookie') && !l.toLowerCase().contains('privacy policy'))
        .toList();

    final mainParagraphs = lines.take(5).join('\n\n');

    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      buffer.writeln('### 🌐 $title\n');
    } else {
      buffer.writeln('### 🌐 Contenido Web: ${uri.host}\n');
    }

    if (description.isNotEmpty) {
      buffer.writeln('> $description\n');
    }

    if (mainParagraphs.isNotEmpty) {
      buffer.writeln(mainParagraphs);
    } else {
      buffer.writeln('Página cargada exitosamente sin extracto de texto principal.');
    }

    buffer.writeln('\n---\n🔍 *Fuente original:* $uri');
    return buffer.toString().trim();
  }

  /// Formateo de texto plano limpio
  String _formatPlainText(String text, Uri uri, int statusCode) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = clean.length > 2000 ? '${clean.substring(0, 2000)}…' : clean;

    return '### 🌐 ${uri.host}\n\n'
        '$preview\n\n'
        '🔍 *Fuente:* $uri';
  }

  String _humanizeKey(String key) {
    if (key.isEmpty) return key;
    return key
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—');
  }
}

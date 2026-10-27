import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/services/execution_budget.dart';
import 'public_link_target.dart';

/// QUÉ: lee contenido textual real, separado de la tarjeta de vista previa.
/// CÓMO: tamaño/plazo acotados, caché con vencimiento y cierre en finally.
/// POR QUÉ: el título de una URL no basta para responder sobre su contenido.
final class ConversationLinkReader {
  ConversationLinkReader({
    http.Client Function()? client,
    Future<bool> Function(Uri)? allowed,
  }) : _client = client ?? PublicLinkTarget.client,
       _allowed = allowed ?? PublicLinkTarget.resolve;
  final http.Client Function() _client;
  final Future<bool> Function(Uri) _allowed;
  final _cache = <String, (DateTime, String)>{};
  final _running = <String, Future<String>>{};

  Future<String> read(String url) async {
    final now = DateTime.now();
    _cache.removeWhere(
      (_, item) => now.difference(item.$1) > const Duration(minutes: 5),
    );
    if (_cache.containsKey(url)) return _cache[url]!.$2;
    if (_running.containsKey(url)) return _running[url]!;
    if (_running.length >= 3) return 'Enlace pendiente de lectura.';
    final work = _fetch(url);
    _running[url] = work;
    try {
      final text = await work;
      // Solo evidencia útil: un fallo podrá reintentarse en el siguiente turno.
      if (text.startsWith('Contenido leído')) {
        if (_cache.length >= 24) _cache.remove(_cache.keys.first);
        _cache[url] = (now, text);
      }
      return text;
    } finally {
      _running.remove(url);
    }
  }

  Future<String> _fetch(String url) async {
    final client = _client();
    void Function()? detach;
    try {
      detach = ExecutionBudget.current?.register(client.close);
      return await () async {
        var uri = Uri.parse(url);
        for (var hop = 0; hop < 4; hop++) {
          ExecutionBudget.current?.check();
          if (!await _allowed(uri)) {
            return 'Enlace sin lectura: destino no público o no permitido.';
          }
          final response = await client.send(
            http.Request('GET', uri)..followRedirects = false,
          );
          if (response.isRedirect) {
            final location = response.headers['location'];
            await response.stream.listen((_) {}).cancel();
            if (location == null) break;
            uri = uri.resolve(location);
            continue;
          }
          if (response.statusCode != 200) {
            return 'Enlace sin lectura: HTTP ${response.statusCode}.';
          }
          final mime = response.headers['content-type'] ?? '';
          if (!mime.contains('text/html') && !mime.contains('text/plain')) {
            return 'Enlace recibido con formato $mime; el cuerpo no fue interpretado.';
          }
          final bytes = <int>[];
          var partial = false;
          await for (final chunk in response.stream) {
            ExecutionBudget.current?.check();
            final remaining = 256 * 1024 - bytes.length;
            bytes.addAll(chunk.take(remaining));
            if (bytes.length >= 256 * 1024) {
              partial = true;
              break;
            }
          }
          var text = utf8
              .decode(bytes, allowMalformed: true)
              .replaceAll(
                RegExp(
                  r'<(script|style|nav)\b[^>]*>.*?</\1>',
                  caseSensitive: false,
                  dotAll: true,
                ),
                ' ',
              )
              .replaceAll(RegExp(r'<[^>]*>'), ' ')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (text.isEmpty) {
            return 'Enlace sin texto legible; puede requerir sesión o JavaScript.';
          }
          if (text.length > 8000) {
            text = text.substring(0, 8000);
            partial = true;
          }
          return 'Contenido leído de $uri el ${DateTime.now().toIso8601String()} '
              '(${partial ? 'extracto parcial' : 'HTML/texto recibido; sin recursos dinámicos'}):\n$text';
        }
        return 'Enlace sin lectura: demasiadas redirecciones.';
      }().timeout(const Duration(seconds: 7));
    } catch (_) {
      return 'Enlace no leído; no se conoce su contenido.';
    } finally {
      client.close();
      detach?.call();
    }
  }
}

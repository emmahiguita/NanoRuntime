import 'dart:convert';
import 'dart:io';

/// Informe portátil con esperado, observado y PNG originales. Solo referencia
/// nombres generados por el capturador; escapa los datos de apps y herramientas.
Future<void> writeOwlQaHtml(Directory folder, Map<String, dynamic> report) async {
  String escape(Object? value) => const HtmlEscape().convert('$value');
  String evidence(Map data, String title) {
    final name = data['image'];
    final image = name is String && RegExp(r'^(before|after)_\d+\.png$').hasMatch(name)
        ? '<a href="$name"><img src="$name" alt="${escape(title)}"></a>'
        : '<p>Captura no disponible: ${escape(data['screenshotError'])}</p>';
    return '<figure><figcaption>$title · ${escape(data['at'])}</figcaption>$image'
        '<small>SHA-256: ${escape(data['sha256'])}</small></figure>';
  }
  final body = (report['steps'] as List).cast<Map>().map((step) =>
    '<article><h2>Paso ${escape(step['step'])}: ${escape(step['state'])}</h2>'
    '<p>Esperado: ${escape(step['expected'])}</p>'
    '<pre>Observado: ${escape(jsonEncode(step['observed']))}</pre>'
    '<div class="captures">${evidence(step['before'] as Map, 'Antes')}'
    '${evidence(step['after'] as Map, 'Después')}</div></article>').join();
  await File('${folder.path}/report.html').writeAsString(
    '<!doctype html><html lang="es"><meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
    '<title>Nano QA</title><style>body{font:16px system-ui;max-width:1000px;margin:24px auto;padding:16px;'
    'color:#17202a;background:#f6f8fa}article{background:white;padding:16px;margin:16px 0;border-radius:16px}'
    'pre,small{white-space:pre-wrap;overflow-wrap:anywhere}img{max-width:100%;max-height:540px}'
    '.captures{display:flex;flex-wrap:wrap}figure{margin:8px;max-width:44%}small{display:block}</style>'
    '<h1>Nano QA: ${escape(report['state'])}</h1>'
    '<p>${escape(report['startedAt'])} — ${escape(report['endedAt'])}</p>'
    '<p>Error: ${escape(report['error'] ?? 'ninguno registrado')}</p>$body'
    '<p>Solo acredita las aserciones documentadas. No demuestra entrega de mensajes, '
    'ausencia de bugs ni comprensión visual completa.</p></html>', flush: true);
}

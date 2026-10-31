import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'owl_workspace_store.dart';

/// Empaqueta artefactos propios del run; nunca adjunta carpetas de otras apps.
String _zipRun(String path) {
  final archive = Archive();
  var total = 0;
  for (final item in Directory(
    path,
  ).listSync(followLinks: false).whereType<File>()) {
    final name = item.uri.pathSegments.last;
    if (!RegExp(
      r'^(report\.(json|html)|(?:before|after)_\d+\.png)$',
    ).hasMatch(name)) {
      continue;
    }
    final bytes = item.readAsBytesSync();
    total += bytes.length;
    if (total > 32 * 1024 * 1024) {
      throw const FormatException(
        'Evidencias mayores de 32 MB; comparte por separado.',
      );
    }
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  final bytes = ZipEncoder().encode(archive);
  if (bytes == null) throw StateError('No se generó el ZIP.');
  final result = File('$path/report.zip');
  result.writeAsBytesSync(bytes, flush: true);
  return result.path;
}

/// Abre el compartir del sistema sin elegir destinatario ni afirmar entrega.
Future<String> exportLatestQa(OwlWorkspaceStore store) async {
  final rows =
      (await store.index(
          'owl_qa_runs_v1',
        )).values.whereType<Map>().where((v) => v['at'] != null).toList()
        ..sort((a, b) => (b['at'] as num).compareTo(a['at'] as num));
  if (rows.isEmpty) {
    throw const FormatException('No hay un informe QA finalizado.');
  }
  final folder = await store.folder('qa', rows.first['id'] as String);
  final path = await compute(_zipRun, folder.path);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: 'application/zip')],
      subject: 'Nano QA — informe y evidencias',
    ),
  );
  return 'Informe preparado en $path. El selector del sistema controla el destino; no se acredita entrega.';
}

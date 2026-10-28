import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/services/owl_surface_bridge.dart';
import 'owl_export_library.dart';
import 'owl_workspace_store.dart';

/// Procesa únicamente archivos que Android entregó explícitamente a nuestra
/// actividad de compartir. No ejecuta herramientas ni invoca un modelo.
abstract final class OwlExportInbox {
  static Future<String>? _running;
  static Future<String> drain() =>
      _running ??= _read().whenComplete(() => _running = null);

  static Future<String> _read() async {
    final raw =
        await OwlSurfaceBridge.channel.invokeListMethod<dynamic>(
          'pendingImports',
        ) ??
        [];
    if (raw.isEmpty) return '';
    final inbox = Directory(
      '${(await getApplicationSupportDirectory()).path}/owl/inbox',
    );
    final base = await inbox.resolveSymbolicLinks();
    final messages = <String>[];
    for (final item in raw.cast<Map>()) {
      final path = item['path'] as String;
      final file = File(await File(path).resolveSymbolicLinks());
      if (file.parent.path != base)
        throw const FormatException('Ruta de importación no autorizada.');
      final result = await OwlExportLibrary(
        OwlWorkspaceStore(),
      ).importFile(file.path, item['name'] as String);
      final acknowledged = await OwlSurfaceBridge.channel.invokeMethod<bool>(
        'ackImport',
        {'path': path},
      );
      if (acknowledged != true)
        throw StateError(
          'Importado, pero no se confirmó el consumo del inbox.',
        );
      messages.add(result);
    }
    return messages.join('\n\n');
  }
}

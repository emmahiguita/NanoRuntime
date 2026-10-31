import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/owl_surface_bridge.dart';
import 'owl_export_library.dart';
import 'owl_workspace_store.dart';

/// Drena archivos compartidos explícitamente. Un archivo inválido no impide
/// importar el resto; fallos de almacenamiento conservan su entrada pendiente.
abstract final class OwlExportInbox {
  static Future<String>? _running;
  static bool _requested = false;

  /// Los eventos que llegan durante una importación solicitan otra lectura,
  /// sin perder el archivo nuevo ni crear dos escritores o un sondeo de fondo.
  static Future<String> drain() {
    _requested = true;
    return _running ??= _drainPending().whenComplete(() => _running = null);
  }

  static Future<String> _drainPending() async {
    final messages = <String>[];
    for (var pass = 0; pass < 8; pass++) {
      _requested = false;
      final result = await _read();
      if (result.isNotEmpty) messages.add(result);
      if (!_requested) return messages.join('\n\n');
    }
    messages.add(
      'Llegaron más archivos. Abre Nano de nuevo para completar las entradas pendientes.',
    );
    return messages.join('\n\n');
  }

  static Future<String> _read() async {
    final raw =
        await OwlSurfaceBridge.channel.invokeListMethod<dynamic>(
          'pendingImports',
        ) ??
        [];
    if (raw.isEmpty) return '';
    final support = await getApplicationSupportDirectory();
    final inbox = Directory('${support.path}/owl/inbox');
    final base = await inbox.resolveSymbolicLinks();
    final messages = <String>[];
    for (final item in raw.cast<Map>()) {
      final path = item['path'] as String;
      final source = File(path);
      try {
        if (!await source.exists()) {
          await _ack(path);
          messages.add(
            'Archivo pendiente ausente: ${item['name']}; continúa la cola.',
          );
          continue;
        }
        final file = File(await source.resolveSymbolicLinks());
        if (file.parent.path != base) {
          messages.add(
            'Ruta de importación rechazada. No se accedió al archivo.',
          );
          continue;
        }
        try {
          final result = await OwlExportLibrary(
            OwlWorkspaceStore(),
          ).importFile(file.path, item['name'] as String);
          await _ack(path);
          messages.add(result);
        } on FormatException catch (error) {
          // Conserva copia y diagnóstico del archivo rechazado, sin consumir
          // una plaza de la cola de importaciones ni tratarlo como historial.
          final rejected = await Directory(
            '${support.path}/owl/rejected',
          ).create(recursive: true);
          final name = file.uri.pathSegments.last;
          await file.copy('${rejected.path}/$name');
          await File(
            '${rejected.path}/$name.error.txt',
          ).writeAsString(error.message, flush: true);
          await _ack(path);
          messages.add(
            'No se importó ${item['name']}: ${error.message}. Copia conservada en ${rejected.path}.',
          );
        }
      } catch (error) {
        messages.add(
          'Pendiente ${item['name']}: $error. No se descartó la entrada; continúa el resto.',
        );
      }
    }
    return messages.join('\n\n');
  }

  /// Android elimina solo su copia temporal tras confirmar persistencia o
  /// rechazo conservado; un ack fallido permanece visible para su recuperación.
  static Future<void> _ack(String path) async {
    if (await OwlSurfaceBridge.channel.invokeMethod<bool>('ackImport', {
          'path': path,
        }) !=
        true) {
      throw StateError('No se confirmó el consumo de la entrada compartida.');
    }
  }
}

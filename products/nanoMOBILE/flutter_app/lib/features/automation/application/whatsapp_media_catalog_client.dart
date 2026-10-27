import 'package:flutter/services.dart';

/// Contrato del índice nativo: metadatos/miniaturas, nunca deduce un destinatario.
final class WhatsAppMediaCatalogClient {
  static const _channel = MethodChannel('com.nanoai/automation_store');
  final _thumbnails = <String, Future<Uint8List?>>{};

  Future<Map<String, dynamic>> scan() async =>
      await _channel.invokeMapMethod<String, dynamic>('whatsappMediaScan') ??
      {};

  Future<Map<String, dynamic>> page({Map<String, dynamic>? before}) async =>
      await _channel.invokeMapMethod<String, dynamic>('whatsappMediaPage', {
        if (before != null) 'beforeMs': int.tryParse('${before['modified']}'),
        if (before != null) 'beforeUri': before['uri'],
      }) ??
      {};

  /// Coalescencia y caché de hasta 80 miniaturas; cambiar el archivo cambia la clave.
  Future<Uint8List?> thumbnail(Map<String, dynamic> row) {
    final key = '${row['uri']}|${row['generation']}';
    final found = _thumbnails.remove(key);
    if (found != null) {
      _thumbnails[key] = found;
      return found;
    }
    final future = _channel.invokeMethod<Uint8List>('whatsappMediaThumbnail', {
      'uri': row['uri'],
    });
    _thumbnails[key] = future;
    if (_thumbnails.length > 80) _thumbnails.remove(_thumbnails.keys.first);
    return future;
  }

  /// El original solo se abre tras un toque y el nativo revalida permisos y existencia.
  Future<void> open(String uri) =>
      _channel.invokeMethod('whatsappMediaOpen', {'uri': uri});
  void clearThumbnails() => _thumbnails.clear();
}

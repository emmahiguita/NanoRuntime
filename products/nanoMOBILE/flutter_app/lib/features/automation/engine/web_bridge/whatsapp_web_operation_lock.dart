/// Serializa las operaciones de Nano que cambian el chat del WebView.
/// Rechaza concurrencia, sin colas que puedan enviar a un destino ya obsoleto.
library;

abstract final class WhatsAppWebOperationLock {
  static bool _busy = false;

  /// La exclusión se mantiene hasta acabar realmente, incluso tras un error.
  static Future<T> run<T>(Future<T> Function() operation) async {
    if (_busy) throw StateError('WhatsApp Web está procesando otra operación');
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }
}

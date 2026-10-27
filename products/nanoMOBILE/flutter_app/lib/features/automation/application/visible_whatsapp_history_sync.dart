import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/web_bridge/whatsapp_web_history_reader.dart';

/// Sincronización de la pantalla abierta: no navega, no envía y no vive tras dispose.
final class VisibleWhatsAppHistorySync {
  final String title, alias;
  final revision = ValueNotifier<int>(0);
  late final _reader = WhatsAppWebHistoryReader.forAlias(alias);
  Timer? _timer;
  bool _closed = false, _started = false;
  int _lastRevision = 0;
  VisibleWhatsAppHistorySync({required this.title, required this.alias});

  /// Se inicia únicamente después de comprobar cuenta y conversación Web.
  void start() {
    if (_closed || _started) return;
    _started = true;
    unawaited(_tick());
  }

  Future<void> _tick() async {
    var delay = const Duration(seconds: 2);
    try {
      await _reader.capture(
        title,
        alias,
        visibleOnly: true,
        interrupted: () => _closed,
      );
      _publishIfChanged();
    } catch (_) {
      // La fuente puede omitir adjuntos; conserva lo guardado y reduce reintentos.
      _publishIfChanged();
      delay = const Duration(seconds: 5);
    } finally {
      if (!_closed) _timer = Timer(delay, () => unawaited(_tick()));
    }
  }

  // No relee SQLite por un snapshot DOM idéntico al anterior.
  void _publishIfChanged() {
    if (!_closed && _reader.persistedRevision != _lastRevision) {
      _lastRevision = _reader.persistedRevision;
      revision.value++;
    }
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    _reader.dispose();
    revision.dispose();
  }
}

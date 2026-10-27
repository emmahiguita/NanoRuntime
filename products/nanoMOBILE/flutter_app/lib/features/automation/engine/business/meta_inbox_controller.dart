import 'dart:async';
import 'package:flutter/foundation.dart';
import 'meta_inbox_models.dart';
import 'meta_templates_api.dart';
import '../messaging/canonical_message.dart';
import '../messaging/canonical_message_store.dart';
part 'meta_inbox_persistence.dart';

/// Coordina lectura oficial, páginas y cambios; nunca ejecuta inferencia ni envíos.
class MetaInboxController extends ChangeNotifier {
  MetaInboxController({
    this.peer,
    required this.isVisible,
    MetaTemplatesApi? api,
  }) : api = api ?? MetaTemplatesApi();
  final String? peer;
  final bool Function() isVisible;
  final MetaTemplatesApi api;
  List<MetaInboxMessage> messages = [];
  String? error, _scope;
  bool busy = false, configured = false, _disposed = false, _active = true;
  bool _initialized = false;
  int? nextBefore, _pageSnapshot, _pollThrough;
  int _cursor = 0;
  Timer? _timer;

  /// Una operación a la vez; una respuesta tardía no notifica un widget destruido.
  Future<void> _run(Future<void> Function() operation) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
    } catch (exception) {
      if (!_disposed) {
        error = exception.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
        _schedule();
      }
    }
  }

  /// Reinicia una instantánea explícitamente; no trata URL/llave guardadas como acceso validado.
  Future<void> refresh() => _run(() async {
    messages = [];
    nextBefore = null;
    _initialized = false;
    _pollThrough = null;
    configured = (await api.connection()).ready;
    if (!configured || _disposed) return;
    final page = await api.inboxPage(peer: peer);
    if (_disposed) return;
    _scope = page.scope;
    _pageSnapshot = page.snapshot;
    _cursor = page.snapshot;
    nextBefore = page.nextBefore;
    await _merge(page.messages);
    _initialized = true;
  });

  /// Historial anterior usa la instantánea inicial; no pierde páginas por mensajes nuevos.
  Future<void> loadOlder() => _run(() async {
    if (nextBefore == null || !_initialized) return;
    final page = await api.inboxPage(
      peer: peer,
      before: nextBefore,
      through: _pageSnapshot,
    );
    if (_disposed) return;
    _checkScope(page);
    await _merge(page.messages);
    nextBefore = page.nextBefore;
  });

  /// El ID del proveedor deduplica mensajes; el teléfono identifica conversaciones.
  Future<void> _merge(List<MetaInboxMessage> events) async {
    String key(MetaInboxMessage m) => peer == null ? m.peerId : m.wamid;
    final known = {for (final message in messages) key(message): message};
    for (final event in events) {
      if (peer != null && event.peerId != peer) continue;
      if (event.kind == 'status') {
        for (final entry in known.entries.toList()) {
          if (entry.value.wamid == event.wamid) {
            final updated = entry.value.withDelivery(event.deliveryState);
            await _persistCanonical(updated);
            known[entry.key] = updated;
          }
        }
        continue;
      }
      if (!['message', 'echo'].contains(event.kind)) {
        continue;
      }
      final previous = known[key(event)];
      if (previous == null || event.sequence > previous.sequence) {
        await _persistCanonical(event);
        if (_disposed) return;
        known[key(event)] = event;
      }
    }
    messages = known.values.toList()
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
  }

  /// Un cambio de cuenta requiere recarga, nunca reutiliza el historial anterior como propio.
  void _checkScope(MetaInboxPage page) {
    if (page.scope != _scope) {
      messages = [];
      _initialized = false;
      throw const FormatException('La cuenta cambió. Actualiza la bandeja.');
    }
  }

  /// Polling serial de cambios, acotado a tres páginas por vuelta para evitar ráfagas infinitas.
  Future<void> _poll() => _run(() async {
    if (!_initialized || !_active || !isVisible()) return;
    for (var count = 0; count < 3; count++) {
      final page = await api.inboxChanges(_cursor, through: _pollThrough);
      if (_disposed) return;
      _checkScope(page);
      if (page.cursor == null ||
          page.cursor! < _cursor ||
          (page.nextAfter != null && page.cursor! == _cursor)) {
        throw const FormatException(
          'No se pudo confirmar el avance del historial.',
        );
      }
      await _merge(page.messages);
      _cursor = page.cursor!;
      _pollThrough = page.nextAfter == null ? null : page.snapshot;
      if (page.nextAfter == null) break;
    }
  });

  /// Un timer de una sola ejecución evita solicitudes solapadas; no funciona en background.
  void _schedule() {
    _timer?.cancel();
    if (_disposed || !_active || !_initialized) return;
    _timer = Timer(const Duration(seconds: 8), () {
      if (isVisible()) {
        unawaited(_poll());
      } else {
        _schedule();
      }
    });
  }

  /// Al volver procesa cambios pendientes; pausar no altera otras automatizaciones.
  void setActive(bool active) {
    _active = active;
    _timer?.cancel();
    if (active) _schedule();
  }

  /// Cierra el HTTPClient propio y cancela timer al salir de la ruta.
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    api.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../engine/storage/automation_db_store_client.dart';
import 'automation_activity_event.dart';

/// Bitácora local sobre el SQLite existente. No sustituye al journal de
/// autorización: este registro es solo diagnóstico y jamás decide reintentos.
class AutomationActivityStore {
  AutomationActivityStore._();
  static final instance = AutomationActivityStore._();
  static const _key = 'automation_action_history_v1';
  static const _limit = 400;
  final revision = ValueNotifier<int>(0);
  final List<AutomationActivityEvent> _events = [];
  Future<void>? _loading;
  Future<void> _queue = Future<void>.value();
  bool persisted = true;

  Future<void> _load() => _loading ??= () async {
    try {
      final raw = await AutomationDbStoreClient.instance
          .section(_key)
          .timeout(const Duration(seconds: 3));
      if (raw == null) return;
      for (final item in (jsonDecode(raw) as List).take(_limit)) {
        try {
          _events.add(
            AutomationActivityEvent.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
        } on Object {
          // Se conserva el resto del historial si una entrada está dañada.
        }
      }
    } on Object {
      persisted = false;
    }
  }();

  /// Serializa anexos del mismo engine; overlay y dashboard usan esta instancia.
  /// Sin canal nativo mantiene la instantánea en memoria y lo informa en la UI.
  Future<void> append(AutomationActivityEvent event) {
    final next = _queue.then((_) async {
      await _load();
      _events.add(event);
      if (_events.length > _limit) {
        _events.removeRange(0, _events.length - _limit);
      }
      try {
        persisted = await AutomationDbStoreClient.instance
            .putSection(
              _key,
              jsonEncode(_events.map((e) => e.toJson()).toList()),
            )
            .timeout(const Duration(seconds: 3));
      } on Object {
        persisted = false;
      }
      revision.value++;
    });
    // Un fallo diagnóstico no puede bloquear el ejecutor ni dejar la cola rota.
    _queue = next.catchError((Object error) {
      persisted = false;
      debugPrint('[automation-history] ${error.runtimeType}');
    });
    return _queue;
  }

  Future<List<AutomationActivityEvent>> read() async {
    await _load();
    await _queue;
    return List.unmodifiable(_events.reversed);
  }

  /// API sin contenido de mensajes/documentos. Limita metadatos antes de guardar.
  void record({
    required String runId,
    required String route,
    required String state,
    required String detail,
    String target = '',
    String packageName = '',
  }) {
    String bounded(String s, int max) =>
        s.length > max ? s.substring(0, max) : s;
    unawaited(
      append(
        AutomationActivityEvent(
          runId: bounded(runId, 120),
          route: bounded(route, 160),
          state: bounded(state, 80),
          detail: bounded(detail, 600),
          target: bounded(target, 160),
          packageName: bounded(packageName, 160),
          atMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }
}

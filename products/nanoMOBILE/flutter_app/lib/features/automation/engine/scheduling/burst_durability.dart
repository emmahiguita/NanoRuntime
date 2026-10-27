/// LOOP-2-BURST-DURABILITY — sombra durable metadata-first (OPTION A).
///
/// Registra la IDENTIDAD de una ráfaga en curso (conversación, claves de
/// notificación y timestamps) para que un kill durante la ventana de
/// asentamiento (800ms-3s) no pierda la coalescencia. NUNCA persiste texto:
/// el contenido se rehidrata de notificaciones ACTIVAS vía `byKey` nativo;
/// si la notificación ya no existe, el fragmento se pierde honestamente
/// (métrica), jamás se reconstruye contenido inventado.
///
/// Invariante de privacidad: solo metadata. OPTION B (contenido durable)
/// queda pendiente de autorización explícita del dueño del producto.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../storage/automation_db_store_client.dart';

/// Interfaz mínima que el [BurstTurnGate] llama sin conocer SQLite.
abstract interface class BurstDurability {
  /// Un fragmento real entró a la ventana de su conversación.
  Future<void> recordFragment(String conversationId, String notificationKey);

  /// El turno de la conversación fue emitido; la ráfaga dejó de estar viva.
  Future<void> markEmitted(String conversationId);

  /// La ráfaga ya no puede recuperarse; se abandona con registro.
  Future<void> discard(String conversationId);
}

/// Ráfaga SETTLING cuya ventana expiró sin emitirse (candidata a recuperar).
final class StaleBurst {
  final String conversationId;
  final List<String> notificationKeys;
  final int firstSeenAt;
  final int lastSeenAt;

  const StaleBurst({
    required this.conversationId,
    required this.notificationKeys,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
}

final class BurstShadowStore implements BurstDurability {
  BurstShadowStore({required this.db});

  final AutomationDbStoreClient db;

  static const String _section = 'burst_shadow_v1';
  static const Duration _ttl = Duration(hours: 1);
  static const String _statusSettling = 'SETTLING';
  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<void> recordFragment(
    String conversationId,
    String notificationKey,
  ) async {
    if (conversationId.isEmpty || notificationKey.isEmpty) return;
    await _enqueueMutation(() async {
      final all = await _load();
      final now = DateTime.now().millisecondsSinceEpoch;
      final prev = all[conversationId] ?? _newEntry();
      final keys = List<String>.from(prev.keys);
      if (!keys.contains(notificationKey)) {
        keys.add(notificationKey);
        // Un bucket jamás supera maxBurst (64) en memoria; el espejo tampoco.
        if (keys.length > 64) keys.removeAt(0);
      }
      all[conversationId] = _ShadowEntry(
        keys: keys,
        firstSeenAt: prev.firstSeenAt == 0 ? now : prev.firstSeenAt,
        lastSeenAt: now,
      );
      if (!await _save(all)) {
        throw StateError('No se pudo persistir la sombra de ráfaga');
      }
      debugPrint(
        '[burst-shadow] conv=${_shortId(conversationId)} '
        'persistidos=${keys.length}',
      );
    });
  }

  @override
  Future<void> markEmitted(String conversationId) async {
    if (conversationId.isEmpty) return;
    await _enqueueMutation(() async {
      final all = await _load();
      all.remove(conversationId);
      if (!await _save(all)) {
        throw StateError('No se pudo cerrar la sombra de ráfaga');
      }
    });
  }

  @override
  Future<void> discard(String conversationId) async {
    if (conversationId.isEmpty) return;
    await _enqueueMutation(() async {
      final all = await _load();
      all.remove(conversationId);
      if (!await _save(all)) {
        throw StateError('No se pudo descartar la sombra de ráfaga');
      }
    });
  }

  /// Ráfagas SETTLING cuya ventana expiró (lastSeenAt < now - [window]) y
  /// que el recovery debe intentar rehidratar. No modifica el store: el
  /// destino (EMITTED o discard) lo decide el flujo que las consume.
  Future<List<StaleBurst>> recoverStale(Duration window) async {
    try {
      await _mutationTail;
      final all = await _load();
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - window.inMilliseconds;
      final stale = <StaleBurst>[];
      all.forEach((convId, entry) {
        final status = entry.status;
        final lastSeen = entry.lastSeenAt;
        if (status == _statusSettling && lastSeen < cutoff) {
          stale.add(
            StaleBurst(
              conversationId: convId,
              notificationKeys: List<String>.from(entry.keys),
              firstSeenAt: entry.firstSeenAt,
              lastSeenAt: lastSeen,
            ),
          );
        }
      });
      return stale;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _enqueueMutation(Future<void> Function() mutation) {
    final operation = _mutationTail.then<void>((_) => mutation());
    _mutationTail = operation.catchError((Object error) {
      // El fallo queda visible, pero no envenena la cola ni rompe el turno.
      debugPrint('[burst-shadow] escritura falló: ${error.runtimeType}');
    });
    return _mutationTail;
  }

  static String _shortId(String value) =>
      value.substring(0, value.length > 8 ? 8 : value.length);

  _ShadowEntry _newEntry() =>
      const _ShadowEntry(keys: [], firstSeenAt: 0, lastSeenAt: 0);

  Future<Map<String, _ShadowEntry>> _load() async {
    try {
      final raw = await db.section(_section);
      if (raw == null || raw.isEmpty) return {};
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return map.map(
        (k, v) => MapEntry(
          k,
          _ShadowEntry.fromJson((v as Map).cast<String, dynamic>()),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<bool> _save(Map<String, _ShadowEntry> entries) async {
    try {
      final now = DateTime.now();
      entries.removeWhere(
        (_, e) =>
            e.lastSeenAt > 0 &&
            now.millisecondsSinceEpoch - e.lastSeenAt > _ttl.inMilliseconds,
      );
      final map = entries.map((k, v) => MapEntry(k, v.toJson()));
      return await db.putSection(_section, jsonEncode(map));
    } catch (_) {
      return false;
    }
  }
}

/// Entrada interna de la sombra (JSON serializable).
final class _ShadowEntry {
  final List<String> keys;
  final int firstSeenAt;
  final int lastSeenAt;
  final String status;

  const _ShadowEntry({
    required this.keys,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.status = BurstShadowStore._statusSettling,
  });

  Map<String, dynamic> toJson() => {
    'keys': keys,
    'firstSeenAt': firstSeenAt,
    'lastSeenAt': lastSeenAt,
    'status': status,
  };

  factory _ShadowEntry.fromJson(Map<String, dynamic> json) => _ShadowEntry(
    keys: ((json['keys'] as List?) ?? const [])
        .map((k) => '$k')
        .where((k) => k.isNotEmpty)
        .toList(),
    firstSeenAt: (json['firstSeenAt'] as num?)?.toInt() ?? 0,
    lastSeenAt: (json['lastSeenAt'] as num?)?.toInt() ?? 0,
    status: (json['status'] as String?) ?? BurstShadowStore._statusSettling,
  );
}

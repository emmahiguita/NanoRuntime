/// WA-MEM-08 — ConversationMemoryStore: estado local por conversación lógica,
/// aislado por ConversationKey. NUNCA una sola historia global de chat.
///
/// Honestidad dura:
/// - `outboundVerified` solo tras verificación real contra el estado.
/// - `outboundDispatched` = RemoteInput aceptado, objetivo NO demostrado.
/// - `effectUnknown` = pudo aterrizar o no: la memoria jamás lo presenta como
///   envío exitoso ("Nano envió X" solo con verified).
/// - El contenido del mensaje entrante es DATO NO CONFIABLE: se conserva como
///   observación factual ([inbound]), nunca como orden ni preferencia.
///
/// Dos conversaciones con el mismo nombre visible pero distinta identidad
/// (locus/shortcut/person/package) viven en claves distintas: sin evidencia de
/// identidad (conversationId vacío) no hay memoria (fail-closed: no se puede
/// aislar lo que no se puede identificar).
///
/// Mismo patrón DIP que EventDedupeStore: lógica pura en memoria +
/// persistencia desacoplada (producción = shared_prefs JSON).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'incoming_message.dart';

/// Tipo factual de una entrada de memoria.
enum ConversationMemoryEntryKind {
  /// Mensaje entrante observado. Nunca éxito, nunca instrucción.
  inbound,

  /// Envío VERIFICADO contra el estado real (la memoria puede decir "Nano
  /// envió X").
  outboundVerified,

  /// Envío despachado (RemoteInput aceptado) sin verificación final.
  outboundDispatched,

  /// Efecto incierto: el envío pudo aterrizar o no. Nunca éxito.
  effectUnknown,
}

/// Entrada inmutable del historial de una conversación.
final class ConversationMemoryEntry {
  final ConversationMemoryEntryKind kind;
  final String text;
  final String sender;
  final int atMs;
  final String eventId;
  final String ruleId;

  const ConversationMemoryEntry({
    required this.kind,
    required this.text,
    this.sender = '',
    required this.atMs,
    this.eventId = '',
    this.ruleId = '',
  });

  Map<String, Object?> toJson() => {
    'k': kind.name,
    't': text,
    if (sender.isNotEmpty) 's': sender,
    'a': atMs,
    if (eventId.isNotEmpty) 'e': eventId,
    if (ruleId.isNotEmpty) 'r': ruleId,
  };

  factory ConversationMemoryEntry.fromJson(Map<String, dynamic> m) =>
      ConversationMemoryEntry(
        kind: ConversationMemoryEntryKind.values.byName(m['k'] as String),
        text: (m['t'] as String?) ?? '',
        sender: (m['s'] as String?) ?? '',
        atMs: (m['a'] as num?)?.toInt() ?? 0,
        eventId: (m['e'] as String?) ?? '',
        ruleId: (m['r'] as String?) ?? '',
      );
}

/// Vista de solo lectura del historial de UNA conversación (lo consume el
/// agente conversacional en WA-AGENT-09). Las entradas están en orden
/// cronológico; la más reciente es la última.
final class ConversationMemory {
  final String conversationId;
  final List<ConversationMemoryEntry> entries;
  final int lastAtMs;

  const ConversationMemory({
    required this.conversationId,
    required this.entries,
    required this.lastAtMs,
  });

  bool get isEmpty => entries.isEmpty;

  ConversationMemoryEntry? get last => entries.isEmpty ? null : entries.last;

  factory ConversationMemory.fromJson(Map<String, dynamic> m) =>
      ConversationMemory(
        conversationId: (m['id'] as String?) ?? '',
        entries: [
          for (final e in (m['entries'] as List?) ?? const [])
            ConversationMemoryEntry.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
        ],
        lastAtMs: (m['lastAtMs'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {
    'id': conversationId,
    'entries': [for (final e in entries) e.toJson()],
    'lastAtMs': lastAtMs,
  };
}

/// Almacén de memoria por conversación. Métodos de escritura síncronos sobre
/// estado en memoria (un solo isolate); persistencia best-effort tras cada
/// mutación (mismo patrón que EventDedupeStore).
abstract interface class ConversationMemoryStore {
  /// Hidrata el estado persistido (una vez, al arrancar el provider).
  Future<void> load();

  /// Snapshot de la conversación; null si nunca se observó nada.
  ConversationMemory? memoryFor(String conversationId);

  /// Ids de conversaciones con historial retenido (solo lectura, para
  /// superficies de inspección como la pantalla Dev).
  Set<String> knownConversationIds();

  /// Registra la observación de un mensaje entrante. No-op sin identidad de
  /// conversación (fail-closed) o sin texto.
  void appendInbound(IncomingMessage message, {required int atMs});

  /// Registra un intento de envío con su honestidad real.
  void appendOutbound(
    String conversationId,
    String text, {
    required ConversationMemoryEntryKind kind,
    String? ruleId,
    required int atMs,
  });
}

/// Núcleo en memoria (puro). Los subtipos aportan persistencia (DIP).
abstract class _MemoryCore implements ConversationMemoryStore {
  _MemoryCore({
    this.maxEntriesPerConversation = defaultMaxEntries,
    this.maxConversations = defaultMaxConversations,
  });

  /// Entradas conservadas por conversación (bounded, las más recientes).
  static const int defaultMaxEntries = 60;

  /// Conversaciones con historial retenido (bounded, las más activas).
  static const int defaultMaxConversations = 100;

  static const int _maxTextField = 2000;

  final int maxEntriesPerConversation;
  final int maxConversations;

  final Map<String, List<ConversationMemoryEntry>> _byConversation = {};
  bool _loaded = false;

  void _markDirty();

  static String _boundText(String raw) =>
      raw.length <= _maxTextField ? raw : raw.substring(0, _maxTextField);

  List<ConversationMemoryEntry> _listFor(String conversationId) {
    final list = _byConversation.putIfAbsent(conversationId, () => []);
    if (list.length > maxEntriesPerConversation) {
      list.removeRange(0, list.length - maxEntriesPerConversation);
    }
    return list;
  }

  void _evictColdestIfNeeded() {
    if (_byConversation.length <= maxConversations) return;
    // Evictar la conversación con actividad más antigua (menor lastAt).
    String? coldest;
    int coldestAt = 0;
    for (final e in _byConversation.entries) {
      final at = e.value.isEmpty ? 0 : e.value.last.atMs;
      if (coldest == null || at < coldestAt) {
        coldest = e.key;
        coldestAt = at;
      }
    }
    if (coldest != null) _byConversation.remove(coldest);
  }

  @override
  ConversationMemory? memoryFor(String conversationId) {
    if (conversationId.isEmpty) return null;
    final list = _byConversation[conversationId];
    if (list == null || list.isEmpty) return null;
    return ConversationMemory(
      conversationId: conversationId,
      entries: List.unmodifiable(list),
      lastAtMs: list.last.atMs,
    );
  }

  @override
  Set<String> knownConversationIds() => Set.unmodifiable(
    _byConversation.keys.where((id) => _byConversation[id]!.isNotEmpty),
  );

  @override
  void appendInbound(IncomingMessage message, {required int atMs}) {
    if (message.conversation.key.id.isEmpty) return;
    if (message.text.trim().isEmpty) return;
    _listFor(message.conversation.key.id).add(
      ConversationMemoryEntry(
        kind: ConversationMemoryEntryKind.inbound,
        text: _boundText(message.text),
        sender: _boundText(message.sender),
        atMs: atMs,
        eventId: message.eventId,
      ),
    );
    _evictColdestIfNeeded();
    _markDirty();
  }

  @override
  void appendOutbound(
    String conversationId,
    String text, {
    required ConversationMemoryEntryKind kind,
    String? ruleId,
    required int atMs,
  }) {
    if (conversationId.isEmpty) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    _listFor(conversationId).add(
      ConversationMemoryEntry(
        kind: kind,
        text: _boundText(clean),
        atMs: atMs,
        ruleId: ruleId ?? '',
      ),
    );
    _evictColdestIfNeeded();
    _markDirty();
  }

  /// Para persistencia: snapshot serializable de todas las conversaciones.
  Map<String, Object?> _snapshot() => {
    for (final e in _byConversation.entries)
      if (e.value.isNotEmpty)
        e.key: ConversationMemory(
          conversationId: e.key,
          entries: e.value,
          lastAtMs: e.value.last.atMs,
        ).toJson(),
  };

  void _hydrate(Map<String, Object?> raw) {
    for (final e in raw.entries) {
      final m = (e.value as Map).cast<String, dynamic>();
      final memory = ConversationMemory.fromJson(m);
      if (memory.conversationId.isNotEmpty && memory.entries.isNotEmpty) {
        _byConversation[memory.conversationId] = List.of(memory.entries);
      }
    }
  }
}

/// Store en memoria (preview/tests). Determinista, sin persistencia.
class MemoryConversationMemoryStore extends _MemoryCore {
  MemoryConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
  });

  @override
  Future<void> load() async {
    _loaded = true;
  }

  @override
  void _markDirty() {
    // Sin persistencia.
  }
}

/// Persistencia en shared_preferences (JSON). Producción.
class SharedPrefsConversationMemoryStore extends _MemoryCore {
  static const _key = 'automation.conversation_memory.v1';

  SharedPrefsConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
  });

  @override
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _hydrate(map);
        debugPrint('[convmem] load: ${_byConversation.length} conversaciones');
      } else {
        debugPrint('[convmem] load: sin datos persistidos');
      }
    } on Object catch (e) {
      debugPrint('[convmem] load falló: $e');
      // Store corrupto o esquema viejo: arrancar limpio (fail-closed).
    }
    _loaded = true;
  }

  @override
  void _markDirty() {
    if (!_loaded) return;
    unawaited(_write());
  }

  Future<void> _write() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_snapshot()));
  }
}

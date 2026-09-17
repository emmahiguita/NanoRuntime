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

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/automation_db_store_client.dart';
import 'conversation_agent.dart';
import 'conversation_assignment_store.dart';
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

  /// Mensaje saliente del dueño observado en la notificación sin despacho previo de Nano (intervención manual).
  outboundObservedManual,

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
  final String scopeId;
  final ConversationAgentId? agentId;
  final List<ConversationMemoryEntry> entries;
  final int lastAtMs;
  final List<String> unresolvedObligations;
  final String? activeTopic;
  final int? lastManualInterventionMs;

  const ConversationMemory({
    required this.conversationId,
    this.scopeId = '',
    this.agentId,
    required this.entries,
    required this.lastAtMs,
    this.unresolvedObligations = const [],
    this.activeTopic,
    this.lastManualInterventionMs,
  });

  bool get isEmpty => entries.isEmpty;

  ConversationMemoryEntry? get last => entries.isEmpty ? null : entries.last;

  factory ConversationMemory.fromJson(Map<String, dynamic> m) =>
      ConversationMemory(
        conversationId: (m['id'] as String?) ?? '',
        scopeId: (m['scopeId'] as String?) ?? '',
        agentId: m['agentId'] is String
            ? ConversationAgentId.fromName(m['agentId'] as String)
            : null,
        entries: [
          for (final e in (m['entries'] as List?) ?? const [])
            ConversationMemoryEntry.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
        ],
        lastAtMs: (m['lastAtMs'] as num?)?.toInt() ?? 0,
        unresolvedObligations: [
          for (final o in (m['obligations'] as List?) ?? const []) o.toString(),
        ],
        activeTopic: m['topic'] as String?,
        lastManualInterventionMs: (m['manualAt'] as num?)?.toInt(),
      );

  Map<String, Object?> toJson() => {
    'id': conversationId,
    if (scopeId.isNotEmpty) 'scopeId': scopeId,
    if (agentId != null) 'agentId': agentId!.name,
    'entries': [for (final e in entries) e.toJson()],
    'lastAtMs': lastAtMs,
    if (unresolvedObligations.isNotEmpty) 'obligations': unresolvedObligations,
    if (activeTopic != null && activeTopic!.isNotEmpty) 'topic': activeTopic,
    if (lastManualInterventionMs != null) 'manualAt': lastManualInterventionMs,
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
  Set<String> knownConversationIds({ConversationAgentId? agentId});

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

  /// Registra una obligación o petición pendiente aún no resuelta.
  void addUnresolvedObligation(String conversationId, String obligation);

  /// Resuelve obligaciones atendidas.
  void resolveObligations(String conversationId, List<String> resolved);

  /// Limpia todas las obligaciones pendientes de la conversación.
  void clearObligations(String conversationId);

  /// Registra una intervención manual del dueño en WhatsApp.
  void recordManualIntervention(String conversationId, int atMs);

  /// Reconcilia un mensaje saliente `isSelf` observado en notificaciones.
  void reconcileOutbound(
    String conversationId,
    String text, {
    required int atMs,
  });
}

/// Núcleo en memoria (puro). Los subtipos aportan persistencia (DIP).
abstract class _MemoryCore implements ConversationMemoryStore {
  _MemoryCore({
    this.maxEntriesPerConversation = defaultMaxEntries,
    this.maxConversations = defaultMaxConversations,
    ConversationAssignmentStore? assignments,
  }) : _assignments = assignments;

  /// Entradas conservadas por conversación (bounded, las más recientes).
  static const int defaultMaxEntries = 60;

  /// Conversaciones con historial retenido (bounded, las más activas).
  static const int defaultMaxConversations = 100;

  static const int _maxTextField = 2000;

  final int maxEntriesPerConversation;
  final int maxConversations;
  final ConversationAssignmentStore? _assignments;

  final Map<String, List<ConversationMemoryEntry>> _byConversation = {};
  final Map<String, List<String>> _obligationsByConversation = {};
  final Map<String, String> _topicByConversation = {};
  final Map<String, int> _manualAtByConversation = {};
  final Map<String, String> _conversationIdByScope = {};
  final Map<String, ConversationAgentId> _agentByScope = {};
  bool _loaded = false;

  void _markDirty();

  void _persistNormalizedEntry(String scopeId, ConversationMemoryEntry entry) {}

  void _persistNormalizedState(String scopeId, ConversationMemory memory) {}

  static String _boundText(String raw) =>
      raw.length <= _maxTextField ? raw : raw.substring(0, _maxTextField);

  String _scopeFor(String conversationId) {
    if (_assignments == null) return conversationId;
    final scope = _assignments.scopeForConversationId(conversationId);
    _conversationIdByScope[scope.id] = conversationId;
    _agentByScope[scope.id] = scope.agentId;
    return scope.id;
  }

  List<ConversationMemoryEntry> _listFor(String conversationId) {
    final scopeId = _scopeFor(conversationId);
    final list = _byConversation.putIfAbsent(scopeId, () => []);
    // AUTO-CONSOLIDATE-02 — trim ANTES de insertar con margen de 1: con
    // `> max` el máximo efectivo era 61 (el trim nunca veía la entrada que
    // estaba por añadirse; evidencia en traza: historyEntries=61).
    if (list.length >= maxEntriesPerConversation) {
      list.removeRange(0, list.length - maxEntriesPerConversation + 1);
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
    if (coldest != null) {
      _byConversation.remove(coldest);
      _obligationsByConversation.remove(coldest);
      _topicByConversation.remove(coldest);
      _manualAtByConversation.remove(coldest);
      _conversationIdByScope.remove(coldest);
      _agentByScope.remove(coldest);
    }
  }

  @override
  ConversationMemory? memoryFor(String conversationId) {
    if (conversationId.isEmpty) return null;
    final scopeId = _scopeFor(conversationId);
    final list = _byConversation[scopeId];
    if (list == null || list.isEmpty) return null;
    return ConversationMemory(
      conversationId: conversationId,
      scopeId: scopeId,
      agentId: _agentByScope[scopeId],
      entries: List.unmodifiable(list),
      lastAtMs: list.last.atMs,
      unresolvedObligations: List.unmodifiable(
        _obligationsByConversation[scopeId] ?? const [],
      ),
      activeTopic: _topicByConversation[scopeId],
      lastManualInterventionMs: _manualAtByConversation[scopeId],
    );
  }

  @override
  Set<String> knownConversationIds({ConversationAgentId? agentId}) =>
      Set.unmodifiable(
        _byConversation.keys
            .where(
              (scopeId) =>
                  _byConversation[scopeId]!.isNotEmpty &&
                  (agentId == null || _agentByScope[scopeId] == agentId),
            )
            .map((scopeId) => _conversationIdByScope[scopeId] ?? scopeId),
      );

  @override
  void appendInbound(IncomingMessage message, {required int atMs}) {
    if (message.conversation.key.id.isEmpty) return;
    if (message.text.trim().isEmpty) return;
    final conversationId = message.conversation.key.id;
    final scopeId = _scopeFor(conversationId);
    final eventId = message.eventId.trim();
    if (eventId.isNotEmpty &&
        (_byConversation[scopeId]?.any((entry) => entry.eventId == eventId) ??
            false)) {
      // Los reintentos del DurableInbox vuelven a presentar el MISMO evento.
      // La memoria es idempotente por eventId para que el prompt no aprenda
      // repeticiones que nunca ocurrieron en la conversación real.
      return;
    }
    // Protección contra reemisiones idénticas de Android con eventId vacío o rotado
    if (_byConversation[scopeId]?.any((entry) =>
            entry.kind == ConversationMemoryEntryKind.inbound &&
            entry.text == _boundText(message.text.trim()) &&
            (atMs - entry.atMs).abs() <= 1000) ??
        false) {
      return;
    }
    final entry = ConversationMemoryEntry(
      kind: ConversationMemoryEntryKind.inbound,
      text: _boundText(message.text),
      sender: _boundText(message.sender),
      atMs: atMs,
      eventId: message.eventId,
    );
    _listFor(conversationId).add(entry);
    _persistNormalizedEntry(scopeId, entry);
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
    final scopeId = _scopeFor(conversationId);
    final entry = ConversationMemoryEntry(
      kind: kind,
      text: _boundText(clean),
      atMs: atMs,
      eventId: _outboundEventId(scopeId, clean, atMs, ruleId ?? ''),
      ruleId: ruleId ?? '',
    );
    _listFor(conversationId).add(entry);
    _persistNormalizedEntry(scopeId, entry);
    // Un mensaje saliente (del bot o del dueño) atiende el turno y resuelve obligaciones previas
    if (_obligationsByConversation.containsKey(scopeId)) {
      _obligationsByConversation[scopeId]?.clear();
      _persistStateFor(conversationId);
    }
    _evictColdestIfNeeded();
    _markDirty();
  }

  @override
  void addUnresolvedObligation(String conversationId, String obligation) {
    if (conversationId.isEmpty) return;
    final clean = obligation.trim();
    if (clean.isEmpty) return;
    final scopeId = _scopeFor(conversationId);
    final list = _obligationsByConversation.putIfAbsent(scopeId, () => []);
    if (!list.contains(clean)) {
      list.add(clean);
      if (list.length > 10) list.removeAt(0);
      _persistStateFor(conversationId);
      _markDirty();
    }
  }

  @override
  void resolveObligations(String conversationId, List<String> resolved) {
    if (conversationId.isEmpty || resolved.isEmpty) return;
    final list = _obligationsByConversation[_scopeFor(conversationId)];
    if (list != null && list.isNotEmpty) {
      list.removeWhere(resolved.contains);
      _persistStateFor(conversationId);
      _markDirty();
    }
  }

  @override
  void clearObligations(String conversationId) {
    if (conversationId.isEmpty) return;
    final scopeId = _scopeFor(conversationId);
    if (_obligationsByConversation.containsKey(scopeId)) {
      _obligationsByConversation[scopeId]?.clear();
      _persistStateFor(conversationId);
      _markDirty();
    }
  }

  @override
  void recordManualIntervention(String conversationId, int atMs) {
    if (conversationId.isEmpty) return;
    _manualAtByConversation[_scopeFor(conversationId)] = atMs;
    _persistStateFor(conversationId);
    _markDirty();
  }

  @override
  void reconcileOutbound(
    String conversationId,
    String text, {
    required int atMs,
  }) {
    if (conversationId.isEmpty) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    final scopeId = _scopeFor(conversationId);
    final list = _listFor(conversationId);

    // Buscar si hay un outboundDispatched reciente con texto coincidente
    final norm = clean.toLowerCase();
    int? matchedIndex;
    for (var i = list.length - 1; i >= 0; i--) {
      final entry = list[i];
      if (entry.kind == ConversationMemoryEntryKind.outboundDispatched) {
        if ((atMs - entry.atMs).abs() <= 30000 &&
            entry.text.toLowerCase() == norm) {
          matchedIndex = i;
          break;
        }
      }
    }

    if (matchedIndex != null) {
      // Promover a outboundVerified
      final prev = list[matchedIndex];
      list[matchedIndex] = ConversationMemoryEntry(
        kind: ConversationMemoryEntryKind.outboundVerified,
        text: prev.text,
        sender: prev.sender,
        atMs: atMs > 0 ? atMs : prev.atMs,
        eventId: prev.eventId,
        ruleId: prev.ruleId,
      );
      _persistNormalizedEntry(scopeId, list[matchedIndex]);
    } else {
      // Intervención manual del dueño en WhatsApp
      final entry = ConversationMemoryEntry(
        kind: ConversationMemoryEntryKind.outboundObservedManual,
        text: _boundText(clean),
        atMs: atMs,
        eventId: _outboundEventId(scopeId, clean, atMs, 'manual'),
      );
      list.add(entry);
      _persistNormalizedEntry(scopeId, entry);
      recordManualIntervention(conversationId, atMs);
    }
    _evictColdestIfNeeded();
    _markDirty();
  }

  void _persistStateFor(String conversationId) {
    final memory = memoryFor(conversationId);
    if (memory != null) {
      _persistNormalizedState(memory.scopeId, memory);
    }
  }

  String _outboundEventId(
    String scopeId,
    String text,
    int atMs,
    String ruleId,
  ) {
    final digest = sha256
        .convert(utf8.encode('$scopeId\u0000$atMs\u0000$ruleId\u0000$text'))
        .toString();
    return 'out:${digest.substring(0, 32)}';
  }

  /// Para persistencia: snapshot serializable de todas las conversaciones.
  Map<String, Object?> _snapshot() => {
    for (final e in _byConversation.entries)
      if (e.value.isNotEmpty)
        e.key: ConversationMemory(
          conversationId: _conversationIdByScope[e.key] ?? e.key,
          scopeId: e.key,
          agentId: _agentByScope[e.key],
          entries: e.value,
          lastAtMs: e.value.last.atMs,
          unresolvedObligations: _obligationsByConversation[e.key] ?? const [],
          activeTopic: _topicByConversation[e.key],
          lastManualInterventionMs: _manualAtByConversation[e.key],
        ).toJson(),
  };

  bool _hydrate(Map<String, Object?> raw) {
    var repairedDuplicates = false;
    for (final e in raw.entries) {
      final m = (e.value as Map).cast<String, dynamic>();
      final memory = ConversationMemory.fromJson(m);
      if (memory.conversationId.isNotEmpty && memory.entries.isNotEmpty) {
        final scopeId = memory.scopeId.isNotEmpty
            ? memory.scopeId
            : _scopeFor(memory.conversationId);
        _conversationIdByScope[scopeId] = memory.conversationId;
        final agent =
            memory.agentId ??
            _assignments?.agentForConversationId(memory.conversationId);
        if (agent != null) _agentByScope[scopeId] = agent;
        final deduplicated = _deduplicateByEventId(memory.entries);
        repairedDuplicates |= deduplicated.length != memory.entries.length;
        _byConversation[scopeId] = deduplicated;
        if (memory.unresolvedObligations.isNotEmpty) {
          _obligationsByConversation[scopeId] = List.of(
            memory.unresolvedObligations,
          );
        }
        if (memory.activeTopic != null && memory.activeTopic!.isNotEmpty) {
          _topicByConversation[scopeId] = memory.activeTopic!;
        }
        if (memory.lastManualInterventionMs != null) {
          _manualAtByConversation[scopeId] = memory.lastManualInterventionMs!;
        }
      }
    }
    return repairedDuplicates;
  }

  List<ConversationMemoryEntry> _deduplicateByEventId(
    List<ConversationMemoryEntry> entries,
  ) {
    final seen = <String>{};
    final reversed = <ConversationMemoryEntry>[];
    // Conserva la versión más reciente. Es importante para un outbound cuyo
    // estado haya progresado de dispatched a verified con el mismo eventId.
    for (final entry in entries.reversed) {
      final eventId = entry.eventId.trim();
      final key = eventId.isNotEmpty
          ? eventId
          : '${entry.kind.name}:${entry.atMs}:${entry.sender}:${entry.text}';
      if (!seen.add(key)) continue;
      reversed.add(entry);
    }
    final deduplicated = reversed.reversed.toList(growable: true);
    if (deduplicated.length > maxEntriesPerConversation) {
      deduplicated.removeRange(
        0,
        deduplicated.length - maxEntriesPerConversation,
      );
    }
    return deduplicated;
  }
}

/// Store en memoria (preview/tests). Determinista, sin persistencia.
class MemoryConversationMemoryStore extends _MemoryCore {
  MemoryConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
    super.assignments,
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
    super.assignments,
  });

  @override
  Future<void> load() async {
    var repairedDuplicates = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        repairedDuplicates = _hydrate(map);
        debugPrint('[convmem] load: ${_byConversation.length} conversaciones');
      } else {
        debugPrint('[convmem] load: sin datos persistidos');
      }
    } on Object catch (e) {
      debugPrint('[convmem] load falló: $e');
      // Store corrupto o esquema viejo: arrancar limpio (fail-closed).
    }
    _loaded = true;
    if (repairedDuplicates) {
      try {
        await _write();
      } on Object catch (e) {
        debugPrint('[convmem] no se pudo persistir reparación: $e');
      }
    }
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

/// Persistencia transaccional (SQLite vía Kotlin — WA-PROD-02). Misma
/// semántica que [SharedPrefsConversationMemoryStore] con reemplazo atómico
/// de sección y migración única de la clave legacy.
class SqliteConversationMemoryStore extends _MemoryCore {
  static const _section = 'memory';
  static const _legacyKey = 'automation.conversation_memory.v1';

  SqliteConversationMemoryStore({
    super.maxEntriesPerConversation,
    super.maxConversations,
    super.assignments,
  });

  @override
  Future<void> load() async {
    var repairedDuplicates = false;
    try {
      var raw = await AutomationDbStoreClient.instance.section(_section);
      raw ??= await _migrateLegacy();
      if (raw != null && raw.isNotEmpty) {
        repairedDuplicates = _hydrate(
          (jsonDecode(raw) as Map).cast<String, dynamic>(),
        );
        await _backfillNormalizedStore();
        debugPrint('[convmem] load sqlite: ${_byConversation.length}');
      } else {
        debugPrint('[convmem] load sqlite: sin datos');
      }
    } on Object catch (e) {
      debugPrint('[convmem] load sqlite falló: $e');
    }
    _loaded = true;
    if (repairedDuplicates) {
      try {
        await _write();
      } on Object catch (e) {
        debugPrint('[convmem] no se pudo persistir reparación sqlite: $e');
      }
    }
  }

  Future<void> _backfillNormalizedStore() async {
    final assignments = _assignments;
    if (assignments != null) {
      for (final conversationId in knownConversationIds()) {
        await assignments.ensureAssignmentForConversationId(conversationId);
      }
    }
    for (final item in _byConversation.entries) {
      for (final entry in item.value) {
        _persistNormalizedEntry(item.key, entry);
      }
      final conversationId = _conversationIdByScope[item.key] ?? item.key;
      final memory = memoryFor(conversationId);
      if (memory != null) _persistNormalizedState(item.key, memory);
    }
  }

  Future<String?> _migrateLegacy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyKey);
      if (raw == null || raw.isEmpty) return null;
      final ok = await AutomationDbStoreClient.instance.putSection(
        _section,
        raw,
      );
      if (ok) await prefs.remove(_legacyKey);
      return ok ? raw : null;
    } on Object {
      return null;
    }
  }

  @override
  void _markDirty() {
    if (!_loaded) return;
    unawaited(_write());
  }

  Future<void> _write() async {
    await AutomationDbStoreClient.instance.putSection(
      _section,
      jsonEncode(_snapshot()),
    );
  }

  @override
  void _persistNormalizedEntry(String scopeId, ConversationMemoryEntry entry) {
    final direction = entry.kind == ConversationMemoryEntryKind.inbound
        ? 'inbound'
        : 'outbound';
    final deliveryState = switch (entry.kind) {
      ConversationMemoryEntryKind.inbound => 'observed',
      ConversationMemoryEntryKind.outboundVerified => 'verified',
      ConversationMemoryEntryKind.outboundDispatched => 'dispatched',
      ConversationMemoryEntryKind.outboundObservedManual => 'manual',
      ConversationMemoryEntryKind.effectUnknown => 'unknown',
    };
    final eventId = entry.eventId.isNotEmpty
        ? entry.eventId
        : _outboundEventId(scopeId, entry.text, entry.atMs, entry.ruleId);
    unawaited(
      AutomationDbStoreClient.instance.appendConversationMessage(
        scopeId: scopeId,
        eventId: eventId,
        direction: direction,
        deliveryState: deliveryState,
        sender: entry.sender,
        body: entry.text,
        atMs: entry.atMs,
        ruleId: entry.ruleId,
      ),
    );
  }

  @override
  void _persistNormalizedState(String scopeId, ConversationMemory memory) {
    unawaited(
      AutomationDbStoreClient.instance.putConversationDialogueState(
        scopeId: scopeId,
        stateJson: jsonEncode(memory.toJson()),
        updatedAtMs: memory.lastAtMs,
      ),
    );
  }
}

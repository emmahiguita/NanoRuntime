/// WA-DEDUPE-03 — EventDedupeStore: puerta de idempotencia del pipeline.
///
/// Garantiza el CLOSE de T3.6: un mensaje lógico entrante dispara a lo sumo
/// UN intento de respuesta posiblemente irreversible. Tres controles en serie,
/// aplicados SIEMPRE antes de despachar reglas:
///
///  1. Deduplicación por evento — eventId determinista (WA-ID-02): la
///     re-publicación de la MISMA notificación (mismo mensaje, mismo timestamp
///     del mensaje, mismo texto) nunca vuelve a disparar.
///  2. Anti-bounceback — el texto de un envío con posible aterrizaje queda
///     registrado por conversación; cuando la propia app de mensajería publica
///     el eco ("Tú: gracias"), ese evento se ignora en vez de tratarse como
///     mensaje nuevo que vuelve a disparar la regla (bucle infinito).
///  3. Cooldown por conversación — un intento de respuesta (verificado,
///     despachado sin verificar o con resultado desconocido) deja la
///     conversación en pausa corta: ráfagas de eventos distinguibles pero casi
///     simultáneos no producen respuestas múltiples. Incluye el intento en
///     vuelo ([markReplyPending]): el segundo evento que entra a mitad de una
///     ejecución ya queda bloqueado.
///
/// Reglas de reintento honestas:
/// - Un evento con estado `outcomeUnknown` NUNCA se reintenta dentro del TTL:
///   el envío pudo aterrizar; reintentar sería doble envío (no blind retry).
/// - Solo un fallo PREVIO al envío ([failed]) deja el evento reintentable,
///   y solo tras [failedBackoffMs].
///
/// Mismo patrón DIP que RuleStore: lógica pura en memoria + persistencia
/// desacoplada (producción = shared_prefs JSON, preview/tests = memoria).
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../storage/automation_db_store_client.dart';

/// Veredicto de la puerta de deduplicación para un evento entrante.
enum DedupeVerdict {
  /// Primer contacto del evento y sin condición que bloquee: puede despachar.
  proceed,

  /// El evento ya se vio dentro del TTL (o se reintentó hace poco tras fallar).
  duplicate,

  /// El texto coincide con un envío con posible aterrizaje de esta conversación
  /// (eco de nuestra propia respuesta). No es un mensaje nuevo: ignorar.
  bounceback,

  /// La conversación está en cooldown tras un intento de respuesta reciente
  /// (incluido uno todavía en vuelo).
  cooldown,
}

/// Estados del ledger de eventos entrantes (auditoría honesta por evento).
enum DedupeEventState {
  /// Reservado y despachado hacia reglas. Mientras existe, el evento no se
  /// reprocesa (duplicate).
  reserved,

  /// La respuesta se verificó contra el estado real del objetivo.
  replyVerified,

  /// La respuesta se despachó (RemoteInput aceptado) sin verificación final.
  /// No es éxito verificado.
  replyDispatched,

  /// El caller agotó su espera; el envío pudo aterrizar o no. No se reintenta.
  outcomeUnknown,

  /// El intento falló sin efecto irreversible (ej. acción expirada).
  failed,

  /// Se ignoró deliberadamente (duplicado, eco, cooldown). Razón en el entry.
  ignored,

  /// Acción notify completada.
  notified,

  /// Acción draft preparada (sin envío).
  drafted,
}

/// Normalización de texto para comparar eco/outbound (misma forma que el
/// canonical del eventId: trim + minúsculas).
String normalizeDedupeText(String raw) => raw.trim().toLowerCase();

/// Puerta de idempotencia consultada por RulePipeline ANTES de despachar.
/// Métodos de decisión síncronos sobre estado en memoria (un solo isolate);
/// la persistencia es best-effort tras cada mutación.
abstract interface class EventDedupeStore {
  /// Hidrata el estado persistido (una vez, al arrancar el provider).
  Future<void> load();

  /// WA-PROD-02.2 — espera a que TODAS las escrituras pendientes terminaron.
  /// El pipeline la invoca entre la reserva del evento y el dispatch: un
  /// kill después de este punto jamás pierde la reserva (el replay del wake
  /// devuelve duplicate, nunca doble envío).
  Future<void> flush();

  /// Decide y reserva el evento en una sola operación síncrona:
  /// - `duplicate` si ya existe dentro del TTL (o falló hace menos del backoff);
  /// - `bounceback`/`cooldown` si el texto/conversación lo bloquean;
  /// - `proceed` tras registrar la reserva (estado `reserved`).
  DedupeVerdict reserve(
    String eventId, {
    required String conversationId,
    required String text,
    required int atMs,
  });

  /// Marca que un intento de respuesta de [conversationId] está EN VUELO.
  /// No se persiste (transitorio): cubre la ventana entre el despacho de un
  /// evento y el registro de su estado terminal.
  void markReplyPending(String conversationId, int atMs);

  /// Registra el estado terminal de un evento ya reservado. No-op si el evento
  /// expiró o nunca fue reservado.
  void record(
    String eventId,
    DedupeEventState state, {
    required int atMs,
    String reason = '',
  });

  /// Registra un envío con posible aterrizaje (texto normalizado) por
  /// conversación, para detectar el eco de la propia respuesta.
  void recordVerifiedOutbound(
    String conversationId,
    String text, {
    required int atMs,
  });
}

/// Entry interno del ledger de eventos.
class _DedupeEntry {
  DedupeEventState state;
  int atMs;
  String reason;

  final String conversationId;
  final String text;

  _DedupeEntry({
    required this.state,
    this.conversationId = '',
    this.text = '',
    required this.atMs,
    String reason = '',
  }) : reason = reason.length <= _maxReason
           ? reason
           : reason.substring(0, _maxReason);

  static const _maxReason = 160;

  Map<String, Object?> toJson() => {
    'st': state.name,
    'cv': conversationId,
    'tx': text,
    'at': atMs,
    if (reason.isNotEmpty) 'rs': reason,
  };
}

/// Echo de outbound por conversación.
class _OutboundEcho {
  final String text;
  final int atMs;

  const _OutboundEcho(this.text, this.atMs);

  Map<String, Object?> toJson() => {'t': text, 'a': atMs};
}

/// Núcleo de la lógica (puro, en memoria). Los subtipos solo aportan
/// persistencia (DIP).
abstract class _DedupeCore implements EventDedupeStore {
  final int ttlMs;
  final int cooldownMs;
  final int failedBackoffMs;
  final int bouncebackMs;
  final int eventCap;
  final int outboundCap;

  _DedupeCore({
    this.ttlMs = defaultTtlMs,
    this.cooldownMs = defaultCooldownMs,
    this.failedBackoffMs = defaultFailedBackoffMs,
    this.bouncebackMs = defaultBouncebackMs,
    this.eventCap = defaultEventCap,
    this.outboundCap = defaultOutboundCap,
  });

  /// TTL de un evento visto (duplicate): 24 h.
  static const defaultTtlMs = Duration.millisecondsPerDay;

  /// Pausa por conversación tras un intento de respuesta. Corta a propósito:
  /// bloquea ráfagas casi simultáneas sin tragarse mensajes reales separados.
  static const defaultCooldownMs = 5000;

  /// Ventana de ECO de respuesta propia (bounceback): solo el eco real de la
  /// app origen llega aquí — WhatsApp publica "Tú: <texto>" SEGUNDOS después
  /// del envío. Con el TTL de 24 h del ledger, un mensaje legítimo del
  /// cliente con el MISMO texto que una respuesta previa (ej. "Hola" otra
  /// vez) moría como bounceback horas después: verificado en Oppo con Emm
  /// ("Hola" repetido quedaba sin responder). 3 min cubre el eco con margen
  /// y no traga mensajes reales posteriores.
  static const defaultBouncebackMs = 180000;

  /// Expiración de un intento EN VUELO (_pendingReplies) sin terminal
  /// registrado. Solo red de seguridad (proceso murió o excepción sin
  /// record): la liberación normal es explícita en [record]. Un reply
  /// dinámico puede tardar >1 min en hardware lento; 10 min cubre con margen.
  static const defaultPendingReplyTtlMs = 600000;

  /// Ventana tras la cual un evento que falló SIN efecto irreversible puede
  /// reintentarse (si la app origen re-publica el mismo evento).
  static const defaultFailedBackoffMs = 30000;

  static const defaultEventCap = 800;
  static const defaultOutboundCap = 30;

  final Map<String, _DedupeEntry> _events = {};
  final Map<String, int> _pendingReplies = {};
  final Map<String, List<_OutboundEcho>> _outbound = {};

  bool _loaded = false;

  /// Persistencia best-effort del snapshot (no-op en el store de memoria).
  void _markDirty();

  /// Escritura concreta del subtipo (prefs/sqlite); memoria = no-op.
  Future<void> _write();

  /// Cola de escrituras SERIALIZADA: cada snapshot espera al anterior (una
  /// escritura vieja nunca completa después de una nueva pisando el estado)
  /// y [flush] puede esperar la cola completa antes de una acción
  /// irreversible (WA-PROD-02.2).
  Future<void>? _writeChain;

  void _queueWrite() {
    final write = _write();
    _writeChain = (_writeChain ?? Future.value()).then((_) => write);
    unawaited(_writeChain);
  }

  @override
  Future<void> flush() async {
    await _writeChain;
  }

  static bool _expired(int atMs, int nowMs, int ttlMs) => nowMs - atMs >= ttlMs;

  /// Un fallo previo al envío es reintentable solo tras el backoff; cualquier
  /// otro estado (incluido outcomeUnknown) bloquea dentro del TTL.
  bool _retryableAfterFailure(_DedupeEntry entry, int atMs) =>
      entry.state == DedupeEventState.failed &&
      atMs - entry.atMs >= failedBackoffMs;

  void _prune(int nowMs) {
    var changed = false;
    _events.removeWhere((_, e) {
      final gone = _expired(e.atMs, nowMs, ttlMs);
      changed = changed || gone;
      return gone;
    });
    // REVIEW-01: el intento en vuelo NO expira con cooldownMs (5 s). Un reply
    // dinámico tarda decenas de segundos y podarlo a los 5 s dejaba pasar un
    // segundo evento de la MISMA conversación → dispatch doble concurrente.
    // Expira solo como red de seguridad; la liberación normal es en record().
    _pendingReplies.removeWhere((_, at) {
      final gone = _expired(at, nowMs, defaultPendingReplyTtlMs);
      changed = changed || gone;
      return gone;
    });
    _outbound.removeWhere((_, list) {
      // El eco de outbound expira con su propia ventana corta (bouncebackMs),
      // NO con el TTL del ledger: un eco con el mismo texto que un mensaje
      // legítimo posterior no debe bloquearlo horas después.
      list.removeWhere((e) => _expired(e.atMs, nowMs, bouncebackMs));
      return list.isEmpty;
    });
    if (changed) _markDirty();
  }

  void _evictIfOversized(int nowMs) {
    if (_events.length <= eventCap) return;
    final ids = _events.keys.toList()
      ..sort((a, b) => _events[a]!.atMs.compareTo(_events[b]!.atMs));
    for (final id in ids.take(_events.length - eventCap)) {
      _events.remove(id);
    }
    _markDirty();
  }

  bool _isKnownOutbound(String conversationId, String normalizedText) =>
      _outbound[conversationId]?.any((e) => e.text == normalizedText) ?? false;

  /// Último intento de respuesta (terminal o en vuelo) de la conversación.
  int _lastReplyAttemptAtMs(String conversationId, int nowMs) {
    var last = _pendingReplies[conversationId] ?? 0;
    for (final e in _events.values) {
      final isAttempt =
          e.state == DedupeEventState.replyVerified ||
          e.state == DedupeEventState.replyDispatched ||
          e.state == DedupeEventState.outcomeUnknown;
      if (isAttempt && e.conversationId == conversationId && e.atMs > last) {
        last = e.atMs;
      }
    }
    return last;
  }

  @override
  DedupeVerdict reserve(
    String eventId, {
    required String conversationId,
    required String text,
    required int atMs,
  }) {
    _prune(atMs);
    final prior = _events[eventId];
    if (prior != null && !_retryableAfterFailure(prior, atMs)) {
      return DedupeVerdict.duplicate;
    }

    final keyed = conversationId.isNotEmpty;
    if (keyed) {
      final normalized = normalizeDedupeText(text);
      if (normalized.isNotEmpty &&
          _isKnownOutbound(conversationId, normalized)) {
        _events[eventId] = _DedupeEntry(
          state: DedupeEventState.ignored,
          conversationId: conversationId,
          text: normalized,
          atMs: atMs,
          reason: 'eco de respuesta propia',
        );
        _markDirty();
        return DedupeVerdict.bounceback;
      }
      final lastAttempt = _lastReplyAttemptAtMs(conversationId, atMs);
      if (lastAttempt > 0 && atMs - lastAttempt < cooldownMs) {
        _events[eventId] = _DedupeEntry(
          state: DedupeEventState.ignored,
          conversationId: conversationId,
          text: normalized,
          atMs: atMs,
          reason: 'conversación en cooldown de respuesta',
        );
        _markDirty();
        return DedupeVerdict.cooldown;
      }
    }

    _events[eventId] = _DedupeEntry(
      state: DedupeEventState.reserved,
      conversationId: conversationId,
      text: text,
      atMs: atMs,
    );
    _markDirty();
    _evictIfOversized(atMs);
    return DedupeVerdict.proceed;
  }

  @override
  void markReplyPending(String conversationId, int atMs) {
    if (conversationId.isEmpty) return;
    _pendingReplies[conversationId] = atMs;
    // Transitorio: no se persiste; si el proceso muere a mitad del envío, el
    // cooldown de vuelo se pierde (el estado terminal lo cubre al registrar).
  }

  @override
  void record(
    String eventId,
    DedupeEventState state, {
    required int atMs,
    String reason = '',
  }) {
    final entry = _events[eventId];
    if (entry == null) return; // expirado o nunca reservado: nada que anotar
    entry
      ..state = state
      ..atMs = atMs
      ..reason = reason;
    // REVIEW-01: el terminal del evento dueño libera el intento en vuelo de
    // su conversación — el estado terminal ya gobierna el cooldown desde
    // _lastReplyAttemptAtMs. Guard <= atMs: jamás borrar un pending más
    // nuevo (otro evento en vuelo de la misma conversación).
    final pendingAt = _pendingReplies[entry.conversationId];
    if (pendingAt != null && pendingAt <= atMs) {
      _pendingReplies.remove(entry.conversationId);
    }
    _markDirty();
  }

  @override
  void recordVerifiedOutbound(
    String conversationId,
    String text, {
    required int atMs,
  }) {
    if (conversationId.isEmpty) return;
    final normalized = normalizeDedupeText(text);
    if (normalized.isEmpty) return;
    final list = _outbound.putIfAbsent(conversationId, () => []);
    list.removeWhere((e) => _expired(e.atMs, atMs, bouncebackMs));
    list.add(_OutboundEcho(normalized, atMs));
    if (list.length > outboundCap) {
      list.removeRange(0, list.length - outboundCap);
    }
    _markDirty();
  }
}

/// Store en memoria (preview/tests). Determinista, sin persistencia.
class MemoryEventDedupeStore extends _DedupeCore {
  MemoryEventDedupeStore({
    super.ttlMs,
    super.cooldownMs,
    super.failedBackoffMs,
    super.bouncebackMs,
    super.eventCap,
    super.outboundCap,
  });

  @override
  Future<void> load() async {
    _prune(DateTime.now().millisecondsSinceEpoch);
    _loaded = true;
  }

  @override
  void _markDirty() {
    // Sin persistencia.
  }

  @override
  Future<void> _write() async {
    // Sin persistencia.
  }
}

/// Persistencia en shared_preferences (JSON). Producción. Mismo patrón que
/// SharedPrefsRuleStore: mutaciones en memoria + escritura best-effort; no
/// escribir antes de [load] para no pisar el historial con un estado vacío.
class SharedPrefsEventDedupeStore extends _DedupeCore {
  static const _key = 'automation.event_dedupe.v1';

  SharedPrefsEventDedupeStore({
    super.ttlMs,
    super.cooldownMs,
    super.failedBackoffMs,
    super.bouncebackMs,
    super.eventCap,
    super.outboundCap,
  });

  @override
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final events = (map['events'] as Map?)?.cast<String, dynamic>() ?? {};
        for (final e in events.entries) {
          final m = (e.value as Map).cast<String, dynamic>();
          _events[e.key] = _DedupeEntry(
            state: DedupeEventState.values.byName(m['st'] as String),
            conversationId: (m['cv'] as String?) ?? '',
            text: (m['tx'] as String?) ?? '',
            atMs: (m['at'] as num?)?.toInt() ?? 0,
            reason: (m['rs'] as String?) ?? '',
          );
        }
        final outbound =
            (map['outbound'] as Map?)?.cast<String, dynamic>() ?? {};
        for (final o in outbound.entries) {
          final echoes = <_OutboundEcho>[];
          for (final m in (o.value as List)) {
            final mm = (m as Map).cast<String, dynamic>();
            echoes.add(
              _OutboundEcho(
                (mm['t'] as String?) ?? '',
                (mm['a'] as num?)?.toInt() ?? 0,
              ),
            );
          }
          _outbound[o.key] = echoes;
        }
      }
    } on Object {
      // Store corrupto o esquema viejo: arrancar limpio (honesto, sin datos
      // fabricados). El historial empieza vacío; la puerta sigue cerrada para
      // eventos futuros.
    }
    _prune(DateTime.now().millisecondsSinceEpoch);
    _loaded = true;
  }

  @override
  void _markDirty() {
    if (!_loaded) return; // no pisar el historial antes de hidratarlo
    _queueWrite();
  }

  @override
  Future<void> _write() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'events': {for (final e in _events.entries) e.key: e.value.toJson()},
        'outbound': {
          for (final o in _outbound.entries)
            o.key: [for (final e in o.value) e.toJson()],
        },
      }),
    );
  }
}

/// Persistencia transaccional (SQLite vía Kotlin — WA-PROD-02). Reemplaza a
/// [SharedPrefsEventDedupeStore] en producción: escritor único Kotlin y
/// reemplazo atómico de sección (WAL). La primera carga migra la clave
/// legacy de prefs y la borra (una sola vez, idempotente).
class SqliteEventDedupeStore extends _DedupeCore {
  static const _section = 'dedupe';
  static const _legacyKey = 'automation.event_dedupe.v1';

  SqliteEventDedupeStore({
    super.ttlMs,
    super.cooldownMs,
    super.failedBackoffMs,
    super.bouncebackMs,
    super.eventCap,
    super.outboundCap,
  });

  @override
  Future<void> load() async {
    try {
      var raw = await AutomationDbStoreClient.instance.section(_section);
      raw ??= await _migrateLegacy();
      if (raw != null && raw.isNotEmpty) {
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final events = (map['events'] as Map?)?.cast<String, dynamic>() ?? {};
        for (final e in events.entries) {
          final m = (e.value as Map).cast<String, dynamic>();
          _events[e.key] = _DedupeEntry(
            state: DedupeEventState.values.byName(m['st'] as String),
            conversationId: (m['cv'] as String?) ?? '',
            text: (m['tx'] as String?) ?? '',
            atMs: (m['at'] as num?)?.toInt() ?? 0,
            reason: (m['rs'] as String?) ?? '',
          );
        }
        final outbound =
            (map['outbound'] as Map?)?.cast<String, dynamic>() ?? {};
        for (final o in outbound.entries) {
          final echoes = <_OutboundEcho>[];
          for (final m in (o.value as List)) {
            final mm = (m as Map).cast<String, dynamic>();
            echoes.add(
              _OutboundEcho(
                (mm['t'] as String?) ?? '',
                (mm['a'] as num?)?.toInt() ?? 0,
              ),
            );
          }
          _outbound[o.key] = echoes;
        }
      }
    } on Object {
      // Sección corrupta o esquema viejo: arrancar limpio (fail-closed).
    }
    _prune(DateTime.now().millisecondsSinceEpoch);
    _loaded = true;
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
    _queueWrite();
  }

  @override
  Future<void> _write() async {
    await AutomationDbStoreClient.instance.putSection(
      _section,
      jsonEncode({
        'events': {for (final e in _events.entries) e.key: e.value.toJson()},
        'outbound': {
          for (final o in _outbound.entries)
            o.key: [for (final e in o.value) e.toJson()],
        },
      }),
    );
  }
}

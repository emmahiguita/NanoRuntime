/// RATE-01 — ContactRateLimiter: límite duro de respuestas por conversación
/// en una ventana de tiempo. Capa DISTINTA y complementaria del cooldown:
///
/// - cooldown (WA-DEDUPE-03) frena ráfagas: una respuesta por evento.
/// - rate limit (este archivo) frena saturación sostenida: máximo N
///   respuestas por conversación en la ventana.
///
/// El alcance es el [ConversationKey.id] COMPLETO (canal+paquete+cuenta+
/// conversación): dos contactos homónimos jamás comparten contador. La
/// clave vacía (sin identidad) se deniega SIEMPRE: sin identidad no hay
/// rate limit confiable y el pipeline ya la trata como no escribible.
///
/// El registro del intento ocurre ANTES del envío: el rate limit protege
/// al canal, no al resultado. Un intento permitido que luego falle sigue
/// contando en la ventana (el canal ya pagó el costo).
library;

import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:shared_preferences/shared_preferences.dart';

import '../messaging/conversation_key.dart';
import '../storage/automation_db_store_client.dart';

/// Política de ventana deslizante. `const`: auditable, sin estado.
final class ContactRatePolicy {
  const ContactRatePolicy({
    this.maxRepliesPerWindow = 3,
    this.window = const Duration(minutes: 10),
  });

  /// Máximo de respuestas permitidas por conversación en [window].
  final int maxRepliesPerWindow;

  /// Ventana deslizante de conteo.
  final Duration window;
}

/// Consulta y registra intentos de respuesta por conversación exacta.
abstract interface class ContactRateLimiter {
  /// Política vigente (para mensajes de razón honestos).
  ContactRatePolicy get policy;

  /// true si el intento está permitido Y queda registrado en la ventana.
  /// false = bloqueado: el llamador NO debe enviar.
  Future<bool> allowReply(ConversationKey key, {required DateTime at});
}

/// Persistencia en shared_preferences (JSON). Mismo patrón que
/// [EventDedupeStore]: carga asíncrona al arranque, ventana deslizante
/// podada en cada operación, sin esquemas nuevos.
final class SharedPreferencesContactRateLimiter implements ContactRateLimiter {
  SharedPreferencesContactRateLimiter({
    this.policy = const ContactRatePolicy(),
  });

  @override
  final ContactRatePolicy policy;

  static const _storeKey = 'automation.contact_rate_limiter.v1';

  /// {"<conversationKeyId>": [int ms de intentos permitidos]}.
  final Map<String, List<int>> _attempts = {};
  bool _loaded = false;

  Future<void>? _loading;

  Future<void> load() {
    if (_loaded) return Future.value();
    // REVIEW-01: future compartido — una segunda llamada espera la MISMA
    // hidratación en vez de decidir sobre _attempts todavía vacío (antes
    // _loaded se ponía true ANTES del primer await: carrera de decisión
    // pre-hidratación y persistencia que pisaba el historial).
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null) {
      _loaded = true;
      return;
    }
    try {
      final decoded = _decodeAttempts(raw);
      _attempts
        ..clear()
        ..addAll(decoded);
    } catch (e) {
      // Prefs corruptas = empezar limpio y honesto: el rate limit se
      // rearma solo; jamás se lanza (el pipeline no debe caer por esto).
      _attempts.clear();
    }
    _loaded = true;
  }

  @override
  Future<bool> allowReply(
    ConversationKey key, {
    required DateTime at,
  }) async {
    await load();
    final id = key.id;
    if (id.isEmpty) return false; // sin identidad: denegar siempre

    final atMs = at.millisecondsSinceEpoch;
    final windowMs = policy.window.inMilliseconds;
    final current =
        (_attempts[id] ?? const <int>[])
            .where((t) => atMs - t < windowMs)
            .toList();
    if (current.length >= policy.maxRepliesPerWindow) return false;

    current.add(atMs);
    _attempts[id] = current;
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    // Podar conversaciones sin intentos vivos: evita crecimiento infinito.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowMs = policy.window.inMilliseconds;
    final pruned = <String, List<int>>{};
    for (final entry in _attempts.entries) {
      final alive = entry.value.where((t) => nowMs - t < windowMs).toList();
      if (alive.isNotEmpty) pruned[entry.key] = alive;
    }
    _attempts
      ..clear()
      ..addAll(pruned);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, _encodeAttempts(_attempts));
  }

  static Map<String, List<int>> _decodeAttempts(String raw) {
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return map.map(
      (key, value) => MapEntry(
        key,
        (value as List).cast<num>().map((e) => e.toInt()).toList(),
      ),
    );
  }

  static String _encodeAttempts(Map<String, List<int>> attempts) =>
      jsonEncode(attempts);
}

/// Persistencia transaccional (SQLite vía Kotlin — WA-PROD-02). Misma
/// semántica que [SharedPreferencesContactRateLimiter] con reemplazo atómico
/// de sección y migración única de la clave legacy. La decisión se persiste
/// ANTES de devolver allowReply=true (igual que el impl de prefs).
final class SqliteContactRateLimiter implements ContactRateLimiter {
  SqliteContactRateLimiter({this.policy = const ContactRatePolicy()});

  @override
  final ContactRatePolicy policy;

  static const _section = 'rate';
  static const _legacyKey = 'automation.contact_rate_limiter.v1';

  final Map<String, List<int>> _attempts = {};
  bool _loaded = false;
  Future<void>? _loading;

  // La interfaz no expone load(): cada impl se auto-hidrata en allowReply
  // (mismo patrón que el impl de prefs) — la barrera global no la espera.
  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      var raw = await AutomationDbStoreClient.instance.section(_section);
      raw ??= await _migrateLegacy();
      if (raw != null && raw.isNotEmpty) {
        _attempts
          ..clear()
          ..addAll(SharedPreferencesContactRateLimiter._decodeAttempts(raw));
      }
    } catch (e) {
      // Sección corrupta: empezar limpio y honesto (el límite se rearma).
      _attempts.clear();
    }
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
  Future<bool> allowReply(
    ConversationKey key, {
    required DateTime at,
  }) async {
    await load();
    final id = key.id;
    if (id.isEmpty) return false;

    final atMs = at.millisecondsSinceEpoch;
    final windowMs = policy.window.inMilliseconds;
    final current =
        (_attempts[id] ?? const <int>[])
            .where((t) => atMs - t < windowMs)
            .toList();
    if (current.length >= policy.maxRepliesPerWindow) return false;

    current.add(atMs);
    _attempts[id] = current;
    await _persist();
    return true;
  }

  Future<void> _persist() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final windowMs = policy.window.inMilliseconds;
    final pruned = <String, List<int>>{};
    for (final entry in _attempts.entries) {
      final alive = entry.value.where((t) => nowMs - t < windowMs).toList();
      if (alive.isNotEmpty) pruned[entry.key] = alive;
    }
    _attempts
      ..clear()
      ..addAll(pruned);
    await AutomationDbStoreClient.instance.putSection(
      _section,
      SharedPreferencesContactRateLimiter._encodeAttempts(_attempts),
    );
  }
}

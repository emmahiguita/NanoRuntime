/// RuleRegistry (T3.1) — registro persistente de reglas de automatización.
///
/// Single source of truth de las reglas habilitadas. El NotificationListener y
/// el scheduler consultan aquí; la EJECUCIÓN la hace el AutomationCoordinator
/// (nunca este registry). Puro + persistencia desacoplada ([RuleStore] DIP).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../messaging/messaging_package.dart';
import 'scheduled_rule.dart';
import 'trigger.dart';

/// Persistencia de reglas (DIP). Producción = shared_prefs JSON; tests = memoria.
abstract interface class RuleStore {
  Future<List<ScheduledRule>> load();
  Future<void> save(List<ScheduledRule> rules);
}

/// Store en memoria (tests/preview). Determinista.
class MemoryRuleStore implements RuleStore {
  MemoryRuleStore([List<ScheduledRule>? seed])
    : _rules = List.of(seed ?? const []);
  List<ScheduledRule> _rules;

  @override
  Future<List<ScheduledRule>> load() async => List.of(_rules);

  @override
  Future<void> save(List<ScheduledRule> rules) async => _rules = List.of(rules);
}

/// Persistencia de reglas en shared_preferences (JSON). Producción.
class SharedPrefsRuleStore implements RuleStore {
  static const _key = 'automation.scheduled_rules.v1';

  @override
  Future<List<ScheduledRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final m in list)
          ScheduledRule.fromJson((m as Map).cast<String, dynamic>()),
      ];
    } on Object {
      // Never seed enabled defaults over unreadable user configuration.
      rethrow;
    }
  }

  @override
  Future<void> save(List<ScheduledRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _key,
      jsonEncode([for (final r in rules) r.toJson()]),
    );
    if (!saved) throw StateError('Rule persistence rejected');
  }
}

class RuleRegistry {
  RuleRegistry(this._store);

  final RuleStore _store;
  final List<ScheduledRule> _rules = [];
  bool _loaded = false;
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();
  bool persistenceHealthy = true;

  Future<void> flush() => _writes;

  /// WA-UNIV-01 — id fijo de la regla universal de conversación de WhatsApp.
  /// Regla de SISTEMA sembrada por petición explícita del dueño: APP=WhatsApp,
  /// FILTER=sin keyword obligatoria (cualquier mensaje entrante),
  /// ACTION=respuesta dinámica del Conversation Engine (LLM), AUTO REPLY.
  /// Sin ella el Personal Agent no recibe ni un "Hola" tras una reinstalación.
  static const universalWhatsAppRuleId = 'wa_universal_conversation';

  List<ScheduledRule> get rules => List.unmodifiable(_rules);

  /// Carga las reglas persistidas (llamado una vez al arrancar el provider)
  /// y siembra la regla universal si no existe (idempotente por id fijo).
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _rules
      ..clear()
      ..addAll(await _store.load());
    _loaded = true;
    _seedUniversalWhatsAppRule();
  }

  /// WA-UNIV-01 — garantiza la regla universal tras cada arranque del
  /// registro. Solo mira la EXISTENCIA del id fijo: si el usuario la borró,
  /// reaparece (regla de sistema, no borrable); si la desactivó o editó,
  /// el seed no la toca (toggle y edición respetados). `createdByUser`
  /// queda true: la autoridad standing de WA-AUTH-04 nace de la petición
  /// explícita del dueño de tener conversación automática en WhatsApp, y
  /// con false el dispatcher exigiría confirmación humana en cada mensaje
  /// (fail-closed que anularía el auto-reply pedido).
  void _seedUniversalWhatsAppRule() {
    if (_rules.any((r) => r.id == universalWhatsAppRuleId)) return;
    final rule = ScheduledRule(
      id: universalWhatsAppRuleId,
      trigger: const NotificationTrigger(
        packageName: MessagingPackage.whatsapp,
      ),
      action: RuleAction.reply,
      dynamicReply: true,
      enabled: true,
      createdAt: DateTime.now(),
      createdByUser: true,
    );
    _rules.add(rule);
    debugPrint(
      '[rules] seed universal WhatsApp (wa_universal_conversation): '
      'cualquier mensaje de com.whatsapp → reply dinámico LLM',
    );
    _persist();
  }

  void add(ScheduledRule rule) {
    _rules.add(rule);
    _persist();
  }

  void remove(String id) {
    _rules.removeWhere((r) => r.id == id);
    _persist();
  }

  void setEnabled(String id, bool enabled) {
    final i = _rules.indexWhere((r) => r.id == id);
    if (i >= 0) _rules[i] = _rules[i].copyWith(enabled: enabled);
    _persist();
  }

  /// RULES-EDIT-01 — reemplaza la regla completa (edición profesional:
  /// trigger, acción, texto, archivo). El id es el ancla; la regla entera
  /// es el nuevo estado. Mismo camino de persistencia que [setEnabled].
  void update(String id, ScheduledRule rule) {
    final i = _rules.indexWhere((r) => r.id == id);
    if (i >= 0) _rules[i] = rule;
    _persist();
  }

  /// Registra el disparo (para deduplicación/cooldown en T3.6).
  /// WA-RULES-UI-02 — [outcome] guarda el resultado real (nombre del
  /// RuleOutcome) para que la pantalla Reglas muestre el estado de la
  /// última ejecución sin inventar éxito.
  void markFired(String id, DateTime at, {String? outcome}) {
    final i = _rules.indexWhere((r) => r.id == id);
    if (i >= 0) {
      _rules[i] = _rules[i].copyWith(
        lastFiredAt: at,
        lastOutcome: outcome ?? _rules[i].lastOutcome,
      );
    }
    _persist();
  }

  void _persist() {
    // No persistir antes de cargar: evitaría pisar el store con una lista vacía.
    if (!_loaded) return;
    final snapshot = List<ScheduledRule>.of(_rules);
    _writes = _writes
        .catchError((Object _) {})
        .then((_) => _store.save(snapshot));
    _writes.then<void>(
      (_) => persistenceHealthy = true,
      onError: (Object error) {
        persistenceHealthy = false;
        debugPrint('[rules] persistence failed; automation blocked: $error');
      },
    );
  }
}

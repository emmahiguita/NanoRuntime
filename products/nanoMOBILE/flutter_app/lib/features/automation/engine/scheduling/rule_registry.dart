/// RuleRegistry (T3.1) — registro persistente de reglas de automatización.
///
/// Single source of truth de las reglas habilitadas. El NotificationListener y
/// el scheduler consultan aquí; la EJECUCIÓN la hace el AutomationCoordinator
/// (nunca este registry). Puro + persistencia desacoplada ([RuleStore] DIP).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'scheduled_rule.dart';

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
      // WA-PHYS-11: store corrupto o esquema viejo → arrancar sin reglas
      // (fail-closed), jamás tumbar el provider de arranque con una excepción
      // no manejada (verificado en dispositivo físico con seed malformado).
      return const [];
    }
  }

  @override
  Future<void> save(List<ScheduledRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final r in rules) r.toJson()]),
    );
  }
}

class RuleRegistry {
  RuleRegistry(this._store);

  final RuleStore _store;
  final List<ScheduledRule> _rules = [];
  bool _loaded = false;

  List<ScheduledRule> get rules => List.unmodifiable(_rules);

  /// Carga las reglas persistidas (llamado una vez al arrancar el provider).
  Future<void> load() async {
    _rules
      ..clear()
      ..addAll(await _store.load());
    _loaded = true;
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
    if (_loaded) _store.save(List.of(_rules));
  }
}

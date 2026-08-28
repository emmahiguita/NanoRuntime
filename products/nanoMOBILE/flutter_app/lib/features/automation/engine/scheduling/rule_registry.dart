/// RuleRegistry (T3.1) — registro persistente de reglas de automatización.
///
/// Single source of truth de las reglas habilitadas. El NotificationListener y
/// el scheduler consultan aquí; la EJECUCIÓN la hace el AutomationCoordinator
/// (nunca este registry). Puro + persistencia desacoplada ([RuleStore] DIP).
library;

import 'scheduled_rule.dart';

/// Persistencia de reglas (DIP). Producción = shared_prefs JSON; tests = memoria.
abstract interface class RuleStore {
  Future<List<ScheduledRule>> load();
  Future<void> save(List<ScheduledRule> rules);
}

/// Store en memoria (tests/preview). Determinista.
class MemoryRuleStore implements RuleStore {
  MemoryRuleStore([List<ScheduledRule>? seed]) : _rules = List.of(seed ?? const []);
  List<ScheduledRule> _rules;

  @override
  Future<List<ScheduledRule>> load() async => List.of(_rules);

  @override
  Future<void> save(List<ScheduledRule> rules) async => _rules = List.of(rules);
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

  /// Registra el disparo (para deduplicación/cooldown en T3.6).
  void markFired(String id, DateTime at) {
    final i = _rules.indexWhere((r) => r.id == id);
    if (i >= 0) _rules[i] = _rules[i].copyWith(lastFiredAt: at);
    _persist();
  }

  void _persist() {
    // No persistir antes de cargar: evitaría pisar el store con una lista vacía.
    if (_loaded) _store.save(List.of(_rules));
  }
}

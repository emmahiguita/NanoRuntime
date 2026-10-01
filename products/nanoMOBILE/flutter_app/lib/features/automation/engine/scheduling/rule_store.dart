// rule_store.dart
//
// QUÉ HACE: persiste reglas de automatización detrás de una interfaz estable.
// CÓMO: ofrece implementaciones en memoria y SharedPreferences con espejo nativo.
// POR QUÉ: separa almacenamiento de la coordinación del RuleRegistry (DIP/SRP).

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'scheduled_rule.dart';
import 'trigger.dart';

abstract interface class RuleStore {
  Future<List<ScheduledRule>> load();
  Future<void> save(List<ScheduledRule> rules);
}

class MemoryRuleStore implements RuleStore {
  MemoryRuleStore([List<ScheduledRule>? seed])
    : _rules = List.of(seed ?? const []);

  List<ScheduledRule> _rules;

  @override
  Future<List<ScheduledRule>> load() async => List.of(_rules);

  @override
  Future<void> save(List<ScheduledRule> rules) async => _rules = List.of(rules);
}

class SharedPrefsRuleStore implements RuleStore {
  static const _key = 'automation.scheduled_rules.v1';
  static const _eligiblePackagesKey = 'automation.eligible_packages';

  @override
  Future<List<ScheduledRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      final rules = [
        for (final item in list)
          ScheduledRule.fromJson((item as Map).cast<String, dynamic>()),
      ];
      final expectedMirror = computeEligiblePackages(rules);
      if (prefs.getString(_eligiblePackagesKey) != expectedMirror) {
        await prefs.setString(_eligiblePackagesKey, expectedMirror);
      }
      return rules;
    } on Object {
      // Nunca reemplaza configuración ilegible por reglas habilitadas.
      rethrow;
    }
  }

  static String computeEligiblePackages(List<ScheduledRule> rules) {
    final enabledRules = rules.where(
      (rule) => rule.enabled && rule.trigger is NotificationTrigger,
    );
    final hasCatchAll = enabledRules.any(
      (rule) => (rule.trigger as NotificationTrigger).packageName == null,
    );
    if (hasCatchAll) return '*';
    final packages = enabledRules
        .map((rule) => (rule.trigger as NotificationTrigger).packageName!)
        .where((package) => package.isNotEmpty)
        .toSet();
    return packages.join(',');
  }

  @override
  Future<void> save(List<ScheduledRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _key,
      jsonEncode([for (final rule in rules) rule.toJson()]),
    );
    if (!saved) throw StateError('Rule persistence rejected');

    // Mantiene el filtro nativo sincronizado para no despertar Flutter con ruido.
    final mirrorSaved = await prefs.setString(
      _eligiblePackagesKey,
      computeEligiblePackages(rules),
    );
    if (!mirrorSaved) {
      throw StateError('Rule admission mirror persistence rejected');
    }
  }
}

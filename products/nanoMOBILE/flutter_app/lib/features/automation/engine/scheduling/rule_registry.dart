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
  static const _eligiblePackagesKey = 'automation.eligible_packages';

  @override
  Future<List<ScheduledRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      final rules = [
        for (final m in list)
          ScheduledRule.fromJson((m as Map).cast<String, dynamic>()),
      ];
      final expectedMirror = computeEligiblePackages(rules);
      if (prefs.getString(_eligiblePackagesKey) != expectedMirror) {
        await prefs.setString(_eligiblePackagesKey, expectedMirror);
      }
      return rules;
    } on Object {
      // Never seed enabled defaults over unreadable user configuration.
      rethrow;
    }
  }

  static String computeEligiblePackages(List<ScheduledRule> rules) {
    final enabledNotificationRules = rules.where(
      (r) => r.enabled && r.trigger is NotificationTrigger,
    );
    final hasCatchAll = enabledNotificationRules.any(
      (r) => (r.trigger as NotificationTrigger).packageName == null,
    );
    if (hasCatchAll) {
      return '*';
    } else {
      final pkgs = enabledNotificationRules
          .map((r) => (r.trigger as NotificationTrigger).packageName!)
          .where((p) => p.isNotEmpty)
          .toSet();
      return pkgs.join(',');
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

    // NATIVE-ADMISSION-01: Sincroniza paquetes elegibles para que Kotlin descarte
    // ruido (<1ms) sin despertar FGS/FlutterEngine headless cuando la UI está cerrada.
    final eligiblePackages = computeEligiblePackages(rules);
    final mirrorSaved = await prefs.setString(
      _eligiblePackagesKey,
      eligiblePackages,
    );
    if (!mirrorSaved) {
      throw StateError('Rule admission mirror persistence rejected');
    }
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

  /// WA-CONSENT-01 — IDs fijos de las reglas universales de WhatsApp.
  /// Se crean ÚNICAMENTE por petición explícita del dueño desde la UI de
  /// configuración (opt-in). No se siembran automáticamente.
  static const universalWhatsAppRuleId = 'wa_universal_conversation';
  static const universalWhatsAppBusinessRuleId =
      'wa_universal_conversation_business';

  List<ScheduledRule> get rules => List.unmodifiable(_rules);

  /// Carga las reglas persistidas (llamado una vez al arrancar el provider).
  /// WA-CONSENT-01 — NO siembra la regla universal automáticamente:
  /// el consentimiento debe ser explícito desde la UI de activación.
  /// Las instalaciones existentes conservan sus reglas tal cual.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _rules
      ..clear()
      ..addAll(await _store.load());
    _loaded = true;
    // WA-CONSENT-01: sin auto-seed. La UI llama a seedWhatsAppRule() al
    // activar la automatización por primera vez.
  }

  /// WA-CONSENT-01 — siembra la regla universal de WhatsApp para el paquete
  /// indicado POR PETICIÓN EXPLÍCITA del usuario desde la pantalla de
  /// activación. Idempotente: si la regla ya existe (instalación previa)
  /// no la duplica ni la sobreescribe (toggle y edición respetados).
  ///
  /// [packageName] debe ser uno de [MessagingPackage.whatsapp] /
  /// [MessagingPackage.whatsappBusiness].
  void seedWhatsAppRule(String packageName) {
    final id = packageName == MessagingPackage.whatsappBusiness
        ? universalWhatsAppBusinessRuleId
        : universalWhatsAppRuleId;
    if (_rules.any((r) => r.id == id)) return; // ya existe, nada que hacer
    final rule = ScheduledRule(
      id: id,
      trigger: NotificationTrigger(packageName: packageName),
      action: RuleAction.reply,
      dynamicReply: true,
      enabled: true,
      createdAt: DateTime.now(),
      createdByUser: true, // consentimiento explícito verificado
    );
    _rules.add(rule);
    debugPrint(
      '[rules] seed WhatsApp rule id=$id pkg=$packageName (opt-in explícito)',
    );
    _persist();
  }

  /// WA-CONSENT-01 — true si la regla universal de [packageName] existe y
  /// está habilitada. Usado por la UI para reflejar el estado del toggle.
  bool isWhatsAppRuleActive(String packageName) {
    final id = packageName == MessagingPackage.whatsappBusiness
        ? universalWhatsAppBusinessRuleId
        : universalWhatsAppRuleId;
    return _rules.any((r) => r.id == id && r.enabled);
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

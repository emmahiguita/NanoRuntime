/// RuleRegistry (T3.1) — registro persistente de reglas de automatización.
///
/// Single source of truth de las reglas habilitadas. El NotificationListener y
/// el scheduler consultan aquí; la EJECUCIÓN la hace el AutomationCoordinator
/// (nunca este registry). Puro + persistencia desacoplada ([RuleStore] DIP).
library;

import 'package:flutter/foundation.dart' show debugPrint, ChangeNotifier;

import '../messaging/messaging_package.dart';
import 'rule_store.dart';
import 'scheduled_rule.dart';
import 'trigger.dart';

export 'rule_store.dart';

class RuleRegistry with ChangeNotifier {
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
    final loaded = await _store.load();
    final seenIds = <String>{};
    final unique = <ScheduledRule>[];
    for (final r in loaded) {
      if (seenIds.add(r.id)) {
        unique.add(r);
      }
    }
    _rules
      ..clear()
      ..addAll(unique);

    // No crea reglas implícitas: WhatsApp exige el opt-in del dueño en la UI.
    _loaded = true;
    _persist();
    notifyListeners();
  }

  /// WA-CONSENT-01 — siembra la regla universal de WhatsApp para el paquete.
  static String ruleIdForPackage(String packageName) =>
      packageName == MessagingPackage.whatsappBusiness
      ? universalWhatsAppBusinessRuleId
      : universalWhatsAppRuleId;

  /// WA-CONSENT-01 — siembra o reactiva la regla universal de WhatsApp para el paquete.
  void seedWhatsAppRule(String packageName, {String? senderMatch}) {
    final id = ruleIdForPackage(packageName);
    final matches = _rules.where((r) => r.id == id).toList();
    if (matches.isNotEmpty) {
      _rules.removeWhere((r) => r.id == id);
      _rules.add(
        matches.first.copyWith(
          enabled: true,
          trigger: NotificationTrigger(
            packageName: packageName,
            senderMatch: senderMatch,
          ),
        ),
      );
      _persist();
      return;
    }
    final rule = ScheduledRule(
      id: id,
      trigger: NotificationTrigger(
        packageName: packageName,
        senderMatch: senderMatch,
      ),
      action: RuleAction.reply,
      dynamicReply: true,
      enabled: true,
      createdAt: DateTime.now(),
      createdByUser: true,
    );
    _rules.add(rule);
    debugPrint('[rules] seed WhatsApp rule id=$id pkg=$packageName');
    _persist();
  }

  /// WA-CONSENT-01 — elimina la regla universal de WhatsApp para el paquete.
  void removeWhatsAppRule(String packageName) {
    remove(ruleIdForPackage(packageName));
  }

  /// WA-CONSENT-01 — true si la regla universal de [packageName] existe y
  /// está habilitada. Usado por la UI para reflejar el estado del toggle.
  bool isWhatsAppRuleActive(String packageName) {
    final id = ruleIdForPackage(packageName);
    return _rules.any((r) => r.id == id && r.enabled);
  }

  void add(ScheduledRule rule) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index >= 0) {
      _rules[index] = rule;
    } else {
      _rules.add(rule);
    }
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
    notifyListeners();
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

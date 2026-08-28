/// RulePipeline (T3.2-T3.3) — el glue WhatsApp-first:
///
///   NotificationObject (real)
///     → NotificationEvent (adapter)
///     → RuleEngine.match (determinista)
///     → RuleDispatcher.dispatch (coordinator, nunca agente paralelo)
///     → markFired (dedup/cooldown en T3.6)
///
/// Este es el punto de entrada que el NotificationListenerService nativo llama
/// cuando llega una notificación de com.whatsapp.
library;

import '../notifications/notification_object.dart';
import 'notification_event_adapter.dart';
import 'rule_dispatcher.dart';
import 'rule_engine.dart';
import 'rule_registry.dart';

class RulePipeline {
  RulePipeline({
    required RuleRegistry registry,
    required RuleEngine engine,
    required RuleDispatcher dispatcher,
  }) : _registry = registry,
       _engine = engine,
       _dispatcher = dispatcher;

  final RuleRegistry _registry;
  final RuleEngine _engine;
  final RuleDispatcher _dispatcher;

  /// Procesa una notificación entrante: matchea reglas habilitadas y las
  /// ejecuta. Devuelve los resultados (vacío = sin regla que disparó).
  Future<List<RuleDispatchResult>> onNotification(
    NotificationObject notif,
  ) async {
    final event = const NotificationEventAdapter().fromNotification(notif);
    final matched = _engine.match(_registry.rules, event);

    final results = <RuleDispatchResult>[];
    for (final rule in matched) {
      final r = await _dispatcher.dispatch(rule, notif);
      results.add(r);
      // Registrar el disparo para deduplicación/cooldown (T3.6).
      if (r.outcome == RuleOutcome.replied || r.outcome == RuleOutcome.notified) {
        _registry.markFired(rule.id, DateTime.now());
      }
    }
    return results;
  }
}

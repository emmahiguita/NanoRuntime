import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ledger/action_ledger_provider.dart';
import 'automation_coordinator_provider.dart';
import 'automation_engine.dart';

/// Provider del [AutomationEngine] — el punto de entrada PÚBLICO del módulo.
/// Las fuentes de objetivo (chat, notificaciones, voz, eventos, scheduler)
/// consumen ESTE provider para invocar el MISMO motor con `runGoal(goal)`.
final automationEngineProvider = Provider<AutomationEngine>((ref) {
  return AutomationEngine.from(
    ref.watch(automationCoordinatorProvider),
    ref.watch(actionLedgerProvider),
  );
});

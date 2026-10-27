import 'dart:async';
import '../../ledger/automation_activity_store.dart';

/// Observación efímera del intento nativo que el monitor ya consulta.
/// No contiene el mensaje/archivo ni ejecuta acciones. No prueba entrega.
class WhatsAppExecutionActivity {
  const WhatsAppExecutionActivity({
    required this.executionId,
    required this.operationId,
    required this.state,
    required this.recipient,
    required this.action,
    required this.packageName,
  });
  final String executionId, state, recipient, action, packageName;
  final int operationId;

  static final _events =
      StreamController<WhatsAppExecutionActivity>.broadcast();
  static Stream<WhatsAppExecutionActivity> get events => _events.stream;

  /// Solo el monitor publica tras verificar operationId y su propietario.
  static void publish(WhatsAppExecutionActivity event) {
    _events.add(event);
    AutomationActivityStore.instance.record(
      runId: event.executionId,
      route: 'Canal Android ? ${event.packageName}',
      state: event.state,
      target: event.recipient,
      packageName: event.packageName,
      detail:
          '${event.action} ? intento nativo ${event.operationId}. '
          'Esta observaci?n no acredita entrega ni lectura.',
    );
  }
}

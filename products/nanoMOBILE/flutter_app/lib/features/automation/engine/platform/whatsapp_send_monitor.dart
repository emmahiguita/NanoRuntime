import 'dart:async';
import 'package:flutter/services.dart';
import '../voice/execution_cancellation.dart';
import 'whatsapp_execution_activity.dart';

/// Un resultado incierto no autoriza repetir el envío. El emisor conserva
/// este estado aunque WhatsApp ya haya aceptado el clic o Nano no vuelva.
class WhatsAppOutcomeUnknown implements Exception {
  const WhatsAppOutcomeUnknown(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// Observa el mismo intento nativo de producción. No pulsa controles, no envía
/// de nuevo ni interpreta apertura como entrega; exige clic y retorno observados.
class WhatsAppSendMonitor {
  static const _channel = MethodChannel('com.nanoai/share');

  Future<Map<String, dynamic>> status() async => Map<String, dynamic>.from(
    await _channel.invokeMapMethod<String, dynamic>('automationStatus') ??
        const {},
  );

  /// Solo cancela el intento observado; nunca una tarea posterior.
  Future<void> cancel(int operationId) => _channel.invokeMethod<void>(
    'cancelAutomation',
    {'operationId': operationId},
  );

  Future<bool> launchAndWait(
    Future<bool> Function() launch, {
    ExecutionCancellationToken? cancellation,
    String recipient = '',
    String action = 'Enviar mensaje',
    String packageName = 'com.whatsapp',
  }) async {
    cancellation?.throwIfCancelled();
    int previous;
    try {
      previous = ((await status())['operationId'] as num?)?.toInt() ?? 0;
    } on MissingPluginException {
      previous = 0;
    }
    if (!await launch()) return false;
    int? ownedId;
    String? lastState;
    final wall = Stopwatch()..start();
    while (wall.elapsed < const Duration(seconds: 29)) {
      Map<String, dynamic> current;
      try {
        current = await status().timeout(const Duration(seconds: 2));
      } on Object {
        throw const WhatsAppOutcomeUnknown(
          'WhatsApp se abrió, pero el estado del intento no está disponible. No repetir automáticamente.',
        );
      }
      final id = (current['operationId'] as num?)?.toInt() ?? 0;
      if (id <= previous) {
        throw const WhatsAppOutcomeUnknown(
          'Flujo abierto sin autoenvío confirmado; requiere revisión en WhatsApp.',
        );
      }
      ownedId ??= id;
      if (id != ownedId) {
        throw const WhatsAppOutcomeUnknown(
          'El intento cambió; no se atribuye el resultado de otra tarea.',
        );
      }
      // Reutiliza la consulta existente; sin segundo temporizador de UI.
      final state = current['state'] as String? ?? 'unknown';
      final executionId = cancellation?.executionId;
      if (executionId != null && state != lastState) {
        lastState = state;
        WhatsAppExecutionActivity.publish(
          WhatsAppExecutionActivity(
            executionId: executionId,
            operationId: ownedId,
            state: state,
            recipient: recipient,
            action: action,
            packageName: packageName,
          ),
        );
      }
      if (cancellation?.isCancelled == true) {
        await cancel(ownedId);
        throw const WhatsAppOutcomeUnknown(
          'Intento detenido; revisa WhatsApp antes de repetir.',
        );
      }
      if (current['state'] == 'returned' && current['clicked'] == true) {
        return true;
      }
      if (current['state'] == 'stopped' ||
          current['state'] == 'return_unverified') {
        throw WhatsAppOutcomeUnknown(
          '${current['detail']} No repetir automáticamente.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    // Cancelar evita un clic tardío después del límite del llamador. No reintenta.
    if (ownedId != null) await cancel(ownedId);
    throw const WhatsAppOutcomeUnknown(
      'Tiempo de observación agotado; resultado incierto. Revisa WhatsApp antes de repetir.',
    );
  }
}

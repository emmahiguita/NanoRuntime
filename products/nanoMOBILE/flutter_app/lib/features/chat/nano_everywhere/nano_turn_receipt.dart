/// Resultado de una petición concreta, independiente del estado mutable del panel.
/// Observar clic/retorno nunca significa acreditar entrega o lectura del mensaje.
enum NanoTurnOutcome {
  answered,
  observed,
  unverified,
  clarification,
  confirmationRequired,
  failed,
  cancelled,
  busy,
}

class NanoTurnReceipt {
  const NanoTurnReceipt(
    this.requestId,
    this.outcome,
    this.text, {
    this.accepted = true,
  });
  final int requestId;
  final NanoTurnOutcome outcome;
  final String text;
  final bool accepted;

  /// Solo respuesta o postcondición observada cuentan como resultado positivo.
  bool get ok =>
      outcome == NanoTurnOutcome.answered ||
      outcome == NanoTurnOutcome.observed;
  Map<String, Object> toMap() => {
    'requestId': requestId,
    'accepted': accepted,
    'state': outcome.name,
    'ok': ok,
    'text': text,
  };

  /// Conserva los códigos del ejecutor sin convertir texto libre en éxito.
  factory NanoTurnReceipt.fromExecution(int id, String text) {
    final state =
        text.startsWith('[completedUnverified]') ||
            text.startsWith('[timeoutOutcomeUnknown]') ||
            text.startsWith('[outcomeUnknown]')
        ? NanoTurnOutcome.unverified
        : text.startsWith('[completed]')
        ? NanoTurnOutcome.observed
        : text.startsWith('[paused]')
        ? NanoTurnOutcome.confirmationRequired
        : text.startsWith('[busy]')
        ? NanoTurnOutcome.busy
        : text.startsWith('[clarification]')
        ? NanoTurnOutcome.clarification
        : text.startsWith('[cancelled]')
        ? NanoTurnOutcome.cancelled
        : text.startsWith('[')
        ? NanoTurnOutcome.failed
        : NanoTurnOutcome.unverified;
    return NanoTurnReceipt(id, state, text);
  }
}

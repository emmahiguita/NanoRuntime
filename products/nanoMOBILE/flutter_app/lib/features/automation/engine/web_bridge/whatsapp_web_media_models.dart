// whatsapp_web_media_models.dart
//
// QUÉ HACE:
// Define los estados formales, contratos de ejecución y resultados inmutables
// de la máquina de estados multimedia para WhatsApp Web.
//
// CÓMO FUNCIONA:
// - Enumera cada etapa desde [idle] hasta [dispatchedUnverified], [abortedSafe]
//   o [outcomeUnknown].
// - Encapsula la traza completa de estados visitados ([visitedStates]) junto
//   con la evidencia de envío ([SendEvidence]) y factorías de cierre deterministas.
//
// POR QUÉ:
// Aplica el Principio de Responsabilidad Única (SRP) separando los tipos de dominio
// del motor de transición de estados, manteniendo cada archivo bajo 200 líneas.

library;

import '../orchestration/commit_guard.dart';

/// Estados formales de la máquina de envío multimedia por WhatsApp Web.
enum WhatsAppWebMediaState {
  idle,
  validatingPayload,
  preparingContext,
  stagingBlob,
  awaitingPreviewModal,
  committingSend,
  dispatchedUnverified,
  abortedSafe,
  outcomeUnknown,
}

/// Resultado inmutable de una ejecución de la máquina de estados multimedia.
final class WhatsAppWebMediaMachineResult {
  final WhatsAppWebMediaState finalState;
  final List<WhatsAppWebMediaState> visitedStates;
  final SendEvidence evidence;

  const WhatsAppWebMediaMachineResult({
    required this.finalState,
    required this.visitedStates,
    required this.evidence,
  });

  bool get isDispatched =>
      finalState == WhatsAppWebMediaState.dispatchedUnverified &&
      evidence.status == SendEvidenceStatus.dispatchedUnverified;

  factory WhatsAppWebMediaMachineResult.abort(
    List<WhatsAppWebMediaState> visited,
    String reason, {
    SendEvidenceStatus status = SendEvidenceStatus.notExecuted,
  }) => WhatsAppWebMediaMachineResult(
    finalState: WhatsAppWebMediaState.abortedSafe,
    visitedStates: List.unmodifiable([
      ...visited,
      WhatsAppWebMediaState.abortedSafe,
    ]),
    evidence: SendEvidence(status, reason),
  );

  factory WhatsAppWebMediaMachineResult.fromWebResponse(
    List<WhatsAppWebMediaState> visited,
    Map<String, dynamic> response,
  ) {
    final reason = '${response['reason'] ?? 'Respuesta multimedia no verificable'}';
    final (state, evStatus) = switch ('${response['status'] ?? ''}') {
      'dispatchedUnverified' => (
        WhatsAppWebMediaState.dispatchedUnverified,
        SendEvidenceStatus.dispatchedUnverified,
      ),
      'notExecuted' => (
        WhatsAppWebMediaState.abortedSafe,
        SendEvidenceStatus.notExecuted,
      ),
      'contextChanged' => (
        WhatsAppWebMediaState.abortedSafe,
        SendEvidenceStatus.contextChanged,
      ),
      'incompleteEvidence' => (
        WhatsAppWebMediaState.abortedSafe,
        SendEvidenceStatus.incompleteEvidence,
      ),
      _ => (
        WhatsAppWebMediaState.outcomeUnknown,
        SendEvidenceStatus.outcomeUnknown,
      ),
    };
    return WhatsAppWebMediaMachineResult(
      finalState: state,
      visitedStates: List.unmodifiable([...visited, state]),
      evidence: SendEvidence(evStatus, reason),
    );
  }
}

/// Contrato de ejecución de scripts Web para desacoplar pruebas unitarias del WebView.
typedef WebScriptRunner = Future<Map<String, dynamic>> Function(
  String phase,
  String script,
);

/// Consentimiento de una única acción dentro de un plan concreto.
///
/// No es un permiso global: solo autoriza cuando coinciden la firma completa
/// del plan, el índice, el identificador del paso y los argumentos de la acción.
library;

class ActionConfirmation {
  final String planSignature;
  final int stepIndex;
  final String stepId;
  final String actionSignature;

  const ActionConfirmation({
    required this.planSignature,
    required this.stepIndex,
    required this.stepId,
    required this.actionSignature,
  });

  bool authorizes({
    required String planSignature,
    required int stepIndex,
    required String stepId,
    required String actionSignature,
  }) =>
      this.planSignature == planSignature &&
      this.stepIndex == stepIndex &&
      this.stepId == stepId &&
      this.actionSignature == actionSignature;
}

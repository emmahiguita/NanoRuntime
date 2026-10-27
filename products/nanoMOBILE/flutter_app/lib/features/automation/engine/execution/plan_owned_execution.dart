part of 'plan_execution_coordinator.dart';

/// Callback de producción que conserva el token propietario durante un efecto.
/// El callback legacy sigue disponible para consumidores anteriores.
typedef OwnedToolReport =
    Future<ToolExecutionReport> Function(
      ToolCall call,
      ToolDefinition tool,
      ToolExecutionBudget budget, {
      ExecutionCancellationToken? cancellation,
    });

const _cancelledBeforeDispatch = ToolOutcome(
  verdict: PolicyVerdict.denied,
  feedback: '[cancelled] Detenida antes de despachar la acción irreversible.',
  executionStatus: ToolExecutionStatus.notExecuted,
);

/// Cierra la frontera claim → dispatch. Si cancelan mientras se persiste el
/// claim, marca que no hubo despacho antes de completar el resultado.
Future<ToolExecutionReport> _ownedIrreversibleReport(
  _PlanExecutionState owner,
  ToolCall call,
  ToolDefinition tool,
  ToolExecutionBudget budget, {
  required ExecutionJournal journal,
  required ExecutionJournalEntry executingEntry,
  ExecutionCancellationToken? cancellation,
  void Function()? onPhysicalEffectDispatched,
}) async {
  if (cancellation?.isCancelled == true) {
    try {
      await journal.save(
        executingEntry.copyWith(
          status: ExecutionJournalStatus.failed,
          verificationState:
              'cancelada antes del despacho; ningún efecto iniciado',
          timestamp: DateTime.now().toUtc(),
        ),
      );
    } on Object {
      // No hubo efecto. El journal conserva su bloqueo por cautela si falló la escritura.
    }
    return const ToolExecutionReport(
      '[cancelled] Detenida antes del despacho irreversible.',
      ToolExecutionStatus.notExecuted,
    );
  }
  onPhysicalEffectDispatched?.call();
  final owned = owner._executeOwnedReportWithTimeout;
  if (owned != null) {
    return owned(call, tool, budget, cancellation: cancellation);
  }
  final legacy = owner._executeReportWithTimeout;
  if (legacy != null) return legacy(call, tool, budget);
  return ToolExecutionReport.legacy(
    await owner._executeWithTimeout(call, tool, budget),
  );
}

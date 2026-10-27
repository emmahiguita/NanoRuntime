part of 'agent_tool_dispatcher.dart';

/// Dispatcher: commands; conserva autorización y cancelación por ejecución.
mixin _AgentDispatcherCommands on _AgentDispatcherBase {
  @override
  void resetTurn() {}

  /// Huella observable del mundo para detectar tool loops entre rondas LLM.
  /// No expone el snapshot ni ejecuta acciones; solo resume estado real.
  Future<String> worldFingerprint() async {
    final snapshot = await _executor.snapshot();
    if (snapshot == null) return 'serviceOff';
    final nodes = snapshot.visibleNodes
        .map((node) => '${node.id}|${node.label}|${node.bounds}')
        .join('\u001e');
    return '${snapshot.package}|${snapshot.truncated}|$nodes';
  }

  /// True si [text] es un comando de herramienta del usuario (`@comando`).
  /// `@@` escapa: permite enviar texto literal que empiece con @.

  // ── Comandos @ ────────────────────────────────────────────────────────────

  /// Ejecuta un comando `@` del usuario y devuelve el feedback para el chat.
  /// Autoría humana: pasa por la política con [humanInitiated] — una
  /// escritura externa escrita a mano por el usuario NO pide confirmación.
  Future<String> runCommand(
    String command, {
    String? executionId,
    ExecutionCancellationToken? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final t = command.trim();
    if (t.startsWith('@@')) return t.substring(1);

    // Cada comando `@` es un turno propio: presupuesto fresco. El chat ya
    // resetea en send(); esto cubre cualquier llamador directo.
    resetTurn();

    final space = t.indexOf(RegExp(r'\s'));
    final verb = (space < 0 ? t : t.substring(0, space))
        .substring(1)
        .toLowerCase();
    final rest = space < 0 ? '' : t.substring(space + 1).trim();

    final audit = AutomationCommandAudit(t, executionId);
    audit.started();
    try {
      final result = await (this as AgentToolDispatcher)._dispatchCommandVerb(
        verb,
        rest,
        executionId: audit.runId,
        cancellation:
            cancellation ??
            ExecutionCancellationToken(executionId: audit.runId),
      );
      audit.finished(result);
      return result;
    } on Object catch (error) {
      audit.failed(error);
      rethrow;
    }
  }

  // ── Tool-calling LLM ──────────────────────────────────────────────────────

  /// Ejecuta un [ToolCall] del LLM bajo política. Sin [confirmed] ni autoría
  /// humana, una escritura externa devuelve needsConfirmation SIN ejecutarse
  /// (el chat muestra el diálogo y re-llama con confirmed: true).
  ///
  /// [authority] (WA-AUTH-04): autorización standing de una regla del usuario;
  /// solo salta la confirmación si satisface ESTA llamada exacta.
}

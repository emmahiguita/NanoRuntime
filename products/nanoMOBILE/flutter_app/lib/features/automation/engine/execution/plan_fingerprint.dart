part of 'plan_execution_coordinator.dart';

/// Plan: plan fingerprint; preserva firma, orden y evidencia durable.
mixin _PlanFingerprint on _PlanExecutionState {
  @override
  Future<String> loopFingerprint(ToolCall call) async {
    final action = call.confirmationSignature;
    if (!PlanExecutionCoordinator.uiStateSensitiveTools.contains(call.tool)) {
      return action;
    }
    final snapshot = await _executor.snapshot();
    if (snapshot == null) {
      return canonicalFingerprint({'action': action, 'state': 'unavailable'});
    }
    return canonicalFingerprint({
      'action': action,
      'state': {
        'package': snapshot.package,
        'truncated': snapshot.truncated,
        'nodes': [
          for (final node in snapshot.visibleNodes)
            '${node.windowId}:${node.id}:${node.type}:${node.text}:'
                '${node.description}:${node.bounds}',
        ],
      },
    });
  }
}

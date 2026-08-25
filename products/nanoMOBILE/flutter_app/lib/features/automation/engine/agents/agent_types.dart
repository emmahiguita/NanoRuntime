/// Tipos de agente (A13) — contexto, mensaje y resultado de roles lógicos.
library;

import '../governance/intent_spec.dart';
import 'agent_role.dart';

class AgentContext {
  final String goal;

  /// Intención autorizada (A11). null → se compila del goal.
  final IntentSpec? intent;

  const AgentContext({required this.goal, this.intent});
}

class AgentMessage {
  final AgentRole from;
  final AgentRole to;
  final Object payload;

  const AgentMessage({
    required this.from,
    required this.to,
    required this.payload,
  });
}

class AgentResult {
  final AgentRole role;
  final Object? value;

  const AgentResult({required this.role, this.value});
}

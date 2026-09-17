/// Typed invocation arguments and execution context.
library;

import 'tool_definition.dart';
import 'tool_risk.dart';

abstract interface class ToolArguments {
  Map<String, Object?> toRedactedMap();
}

/// Dynamic arguments are restricted to JSON/MCP/API boundaries.
final class MapToolArguments implements ToolArguments {
  const MapToolArguments(this.values);

  final Map<String, dynamic> values;

  T? get<T>(String key) => values[key] is T ? values[key] as T : null;

  @override
  Map<String, Object?> toRedactedMap() => Map.unmodifiable(values);
}

final class AgentIdentity {
  const AgentIdentity({required this.role, this.agentId, this.ownerId});

  final AgentCallerRole role;
  final String? agentId;
  final String? ownerId;
}

final class ToolExecutionEnvironment {
  const ToolExecutionEnvironment({
    required this.mode,
    required this.userPresent,
    this.approvalGranted = false,
  });

  const ToolExecutionEnvironment.foreground({
    this.userPresent = true,
    this.approvalGranted = false,
  }) : mode = ToolExecutionMode.foreground;

  final ToolExecutionMode mode;
  final bool userPresent;
  final bool approvalGranted;

  bool get isBackground => mode != ToolExecutionMode.foreground;
}

final class ToolConversationIdentity {
  const ToolConversationIdentity({
    required this.id,
    this.platform,
    this.participant,
  });

  final String id;
  final String? platform;
  final String? participant;
}

final class ToolExecutionContext<A extends ToolArguments> {
  const ToolExecutionContext({
    required this.executionId,
    required this.arguments,
    required this.caller,
    required this.environment,
    required this.requestedAt,
    this.conversation,
    this.parentExecutionId,
    this.correlationId,
  });

  final String executionId;
  final A arguments;
  final AgentIdentity caller;
  final ToolExecutionEnvironment environment;
  final ToolConversationIdentity? conversation;
  final String? parentExecutionId;
  final String? correlationId;
  final DateTime requestedAt;
}

/// Untyped request accepted only at agent/MCP/API boundaries.
final class ToolRequest {
  const ToolRequest({
    required this.toolId,
    required this.arguments,
    required this.caller,
    required this.environment,
    this.toolVersion,
    this.conversation,
    this.parentExecutionId,
    this.correlationId,
    this.requestedAt,
  });

  final String toolId;
  final int? toolVersion;
  final Map<String, dynamic> arguments;
  final AgentIdentity caller;
  final ToolExecutionEnvironment environment;
  final ToolConversationIdentity? conversation;
  final String? parentExecutionId;
  final String? correlationId;
  final DateTime? requestedAt;
}

final class TypedToolRequest<A extends ToolArguments> {
  const TypedToolRequest({
    required this.toolId,
    required this.arguments,
    required this.caller,
    required this.environment,
    this.toolVersion,
    this.conversation,
    this.parentExecutionId,
    this.correlationId,
    this.requestedAt,
  });

  final String toolId;
  final int? toolVersion;
  final A arguments;
  final AgentIdentity caller;
  final ToolExecutionEnvironment environment;
  final ToolConversationIdentity? conversation;
  final String? parentExecutionId;
  final String? correlationId;
  final DateTime? requestedAt;
}

typedef ToolArgumentDecoder<A extends ToolArguments> =
    A Function(Map<String, dynamic> raw);

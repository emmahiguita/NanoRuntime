/// Declarative contract for a formal Nano capability.
library;

import 'tool_permission.dart';
import 'tool_risk.dart';

enum ToolCategory { atomicAction, domainAction, skill, mcp, api, plugin }

enum AgentCallerRole {
  personal,
  business,
  system,
  user;

  static AgentCallerRole fromString(String value) => values.firstWhere(
    (role) => role.name.toLowerCase() == value.toLowerCase(),
    orElse: () => AgentCallerRole.system,
  );
}

/// Immutable metadata used by routing, policy and audit.
final class ToolDefinition {
  const ToolDefinition({
    required this.id,
    required this.version,
    required this.displayName,
    required this.description,
    required this.category,
    this.risk = ToolRiskLevel.low,
    this.sideEffect = ToolSideEffect.none,
    this.approvalPolicy = ApprovalPolicy.never,
    this.requiredPermissions = const [],
    this.allowedRoles = const [
      AgentCallerRole.personal,
      AgentCallerRole.business,
      AgentCallerRole.system,
      AgentCallerRole.user,
    ],
    this.allowedExecutionModes = const [ToolExecutionMode.foreground],
    this.inputSchema = const {},
    this.outputSchema = const {},
    this.timeout = const Duration(seconds: 15),
    this.verificationPolicy = ToolVerificationPolicy.notRequired,
    this.tags = const {},
  });

  final String id;
  final int version;
  final String displayName;
  final String description;
  final ToolCategory category;
  final ToolRiskLevel risk;
  final ToolSideEffect sideEffect;
  final ApprovalPolicy approvalPolicy;
  final List<ToolPermission> requiredPermissions;
  final List<AgentCallerRole> allowedRoles;
  final List<ToolExecutionMode> allowedExecutionModes;
  final Map<String, dynamic> inputSchema;
  final Map<String, dynamic> outputSchema;
  final Duration timeout;
  final ToolVerificationPolicy verificationPolicy;
  final Set<String> tags;

  String get versionedId => '$id@$version';
  String get name => displayName;
  Duration get defaultTimeout => timeout;

  bool allowsRole(AgentCallerRole role) => allowedRoles.contains(role);
  bool allowsMode(ToolExecutionMode mode) =>
      allowedExecutionModes.contains(mode);

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'displayName': displayName,
    'description': description,
    'category': category.name,
    'risk': risk.name,
    'sideEffect': sideEffect.name,
    'approvalPolicy': approvalPolicy.name,
    'requiredPermissions': requiredPermissions.map((p) => p.name).toList(),
    'allowedRoles': allowedRoles.map((r) => r.name).toList(),
    'allowedExecutionModes': allowedExecutionModes
        .map((mode) => mode.name)
        .toList(),
    'inputSchema': inputSchema,
    'outputSchema': outputSchema,
    'timeoutMs': timeout.inMilliseconds,
    'verificationPolicy': verificationPolicy.name,
    'tags': tags.toList()..sort(),
  };
}

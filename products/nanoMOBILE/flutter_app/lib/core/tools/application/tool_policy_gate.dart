/// Fail-closed policy decisions for formal tools.
library;

import '../domain/executable_tool.dart';
import '../domain/tool_input.dart';
import '../domain/tool_permission.dart';
import '../domain/tool_risk.dart';
import 'tool_registry.dart';

enum PolicyReason {
  toolNotFound,
  invalidInput,
  roleNotAllowed,
  permissionMissing,
  executionModeNotAllowed,
  approvalRequired,
  contextualApprovalRequired,
}

sealed class PolicyDecision {
  const PolicyDecision();
  String get auditValue;
}

final class PolicyAllowed extends PolicyDecision {
  const PolicyAllowed(this.tool);
  final RegisteredTool tool;
  @override
  String get auditValue => 'allowed';
}

final class PolicyDenied extends PolicyDecision {
  const PolicyDenied({required this.reason, required this.message, this.tool});
  final PolicyReason reason;
  final String message;
  final RegisteredTool? tool;
  @override
  String get auditValue => 'denied:${reason.name}';
}

final class ApprovalRequest {
  const ApprovalRequest({
    required this.toolId,
    required this.reason,
    required this.message,
  });
  final String toolId;
  final PolicyReason reason;
  final String message;
}

final class PolicyRequiresApproval extends PolicyDecision {
  const PolicyRequiresApproval({required this.tool, required this.request});
  final RegisteredTool tool;
  final ApprovalRequest request;
  @override
  String get auditValue => 'requiresApproval:${request.reason.name}';
}

abstract interface class PermissionProvider {
  bool hasPermission(ToolPermission permission);
}

/// Explicit permission set. An omitted permission is denied.
final class StaticPermissionProvider implements PermissionProvider {
  const StaticPermissionProvider(this.grantedPermissions);
  final Set<ToolPermission> grantedPermissions;

  @override
  bool hasPermission(ToolPermission permission) =>
      grantedPermissions.contains(permission);
}

typedef ContextualApprovalDecider =
    bool Function(
      RegisteredTool tool,
      ToolArguments arguments,
      ToolExecutionEnvironment environment,
    );

final class ToolPolicyGate {
  const ToolPolicyGate({
    required IToolRegistry registry,
    required PermissionProvider permissionProvider,
    ContextualApprovalDecider? contextualApprovalDecider,
  }) : _registry = registry,
       _permissionProvider = permissionProvider,
       _contextualApprovalDecider = contextualApprovalDecider;

  final IToolRegistry _registry;
  final PermissionProvider _permissionProvider;
  final ContextualApprovalDecider? _contextualApprovalDecider;

  PolicyDecision evaluate({
    required String toolId,
    int? toolVersion,
    required ToolArguments arguments,
    required AgentIdentity caller,
    required ToolExecutionEnvironment environment,
  }) {
    final tool = _registry.resolve(toolId, version: toolVersion);
    if (tool == null) {
      return PolicyDenied(
        reason: PolicyReason.toolNotFound,
        message: 'Herramienta "$toolId" no registrada o deshabilitada.',
      );
    }
    final definition = tool.definition;
    if (!definition.allowsRole(caller.role)) {
      return PolicyDenied(
        reason: PolicyReason.roleNotAllowed,
        message:
            'El rol ${caller.role.name} no puede ejecutar ${definition.versionedId}.',
        tool: tool,
      );
    }
    if (!definition.allowsMode(environment.mode)) {
      return PolicyDenied(
        reason: PolicyReason.executionModeNotAllowed,
        message:
            '${definition.versionedId} no permite modo ${environment.mode.name}.',
        tool: tool,
      );
    }
    for (final permission in definition.requiredPermissions) {
      if (!_permissionProvider.hasPermission(permission)) {
        return PolicyDenied(
          reason: PolicyReason.permissionMissing,
          message:
              'Falta el permiso ${permission.name} para ${definition.versionedId}.',
          tool: tool,
        );
      }
    }
    if (environment.approvalGranted) return PolicyAllowed(tool);

    final requiresApproval = switch (definition.approvalPolicy) {
      ApprovalPolicy.never => false,
      ApprovalPolicy.always => true,
      ApprovalPolicy.whenUserAbsent => !environment.userPresent,
      ApprovalPolicy.contextual =>
        _contextualApprovalDecider?.call(tool, arguments, environment) ??
            _safeContextualDefault(tool, environment),
    };
    if (requiresApproval) {
      final reason = definition.approvalPolicy == ApprovalPolicy.contextual
          ? PolicyReason.contextualApprovalRequired
          : PolicyReason.approvalRequired;
      return PolicyRequiresApproval(
        tool: tool,
        request: ApprovalRequest(
          toolId: definition.versionedId,
          reason: reason,
          message:
              '${definition.displayName} requiere aprobación humana en ${environment.mode.name}.',
        ),
      );
    }
    return PolicyAllowed(tool);
  }

  bool _safeContextualDefault(
    RegisteredTool tool,
    ToolExecutionEnvironment environment,
  ) {
    final sideEffect = tool.definition.sideEffect;
    if (sideEffect == ToolSideEffect.destructive) return true;
    if (environment.isBackground &&
        (sideEffect == ToolSideEffect.communication ||
            sideEffect == ToolSideEffect.externalWrite ||
            sideEffect == ToolSideEffect.localWrite)) {
      return true;
    }
    return !environment.userPresent && sideEffect != ToolSideEffect.none;
  }
}

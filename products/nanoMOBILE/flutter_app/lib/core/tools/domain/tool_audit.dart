/// Privacy-preserving audit records for formal tool execution.
library;

import 'tool_result.dart';

final class ToolExecutionRecord {
  const ToolExecutionRecord({
    required this.executionId,
    required this.toolId,
    required this.toolVersion,
    required this.callerRole,
    required this.argumentsHash,
    required this.policyDecision,
    required this.startedAt,
    required this.finishedAt,
    required this.executionStatus,
    required this.verificationStatus,
    required this.evidence,
    this.correlationId,
    this.parentExecutionId,
    this.conversationId,
    this.failureCode,
  });

  final String executionId;
  final String? correlationId;
  final String? parentExecutionId;
  final String toolId;
  final int toolVersion;
  final String callerRole;
  final String? conversationId;
  final String argumentsHash;
  final String policyDecision;
  final DateTime startedAt;
  final DateTime finishedAt;
  final ToolExecutionStatus executionStatus;
  final ToolVerificationStatus verificationStatus;
  final List<ToolEvidence> evidence;
  final String? failureCode;

  Map<String, Object?> toJson() => {
    'executionId': executionId,
    'correlationId': correlationId,
    'parentExecutionId': parentExecutionId,
    'toolId': toolId,
    'toolVersion': toolVersion,
    'callerRole': callerRole,
    'conversationId': conversationId,
    'argumentsHash': argumentsHash,
    'policyDecision': policyDecision,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    'executionStatus': executionStatus.name,
    'verificationStatus': verificationStatus.name,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'failureCode': failureCode,
  };
}

abstract interface class ToolAuditTrail {
  Future<void> append(ToolExecutionRecord record);
  Future<List<ToolExecutionRecord>> recent({int limit = 100});
}

final class InMemoryToolAuditTrail implements ToolAuditTrail {
  final List<ToolExecutionRecord> _records = [];

  @override
  Future<void> append(ToolExecutionRecord record) async {
    _records.add(record);
  }

  @override
  Future<List<ToolExecutionRecord>> recent({int limit = 100}) async {
    final start = (_records.length - limit).clamp(0, _records.length);
    return List.unmodifiable(_records.sublist(start).reversed);
  }
}

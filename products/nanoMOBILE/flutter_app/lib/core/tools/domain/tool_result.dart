/// Independent execution and verification outcomes for formal tools.
library;

enum ToolExecutionStatus {
  success,
  failed,
  cancelled,
  timedOut,
  requiresApproval,
}

enum ToolVerificationStatus {
  notRequired,
  pending,
  dispatched,
  verified,
  failed,
  unknown,
}

enum ToolEvidenceType {
  remoteInputAccepted,
  databaseRecordFound,
  uiNodeObserved,
  fileExists,
  httpResponse,
  processExitCode,
  outboundMessageObserved,
  computation,
}

final class ToolEvidence {
  const ToolEvidence({
    required this.type,
    required this.source,
    required this.timestamp,
    required this.data,
    this.confidence = 1,
  });

  final ToolEvidenceType type;
  final String source;
  final DateTime timestamp;
  final Map<String, Object?> data;
  final double confidence;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'source': source,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'data': data,
    'confidence': confidence,
  };
}

final class ToolFailure {
  const ToolFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  });

  final String code;
  final String message;
  final bool retryable;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'retryable': retryable,
  };
}

final class ToolVerificationResult {
  const ToolVerificationResult({
    required this.status,
    this.evidence = const [],
    this.failure,
  });

  final ToolVerificationStatus status;
  final List<ToolEvidence> evidence;
  final ToolFailure? failure;
}

final class ToolResult<O> {
  const ToolResult({
    required this.executionStatus,
    required this.verificationStatus,
    required this.startedAt,
    required this.finishedAt,
    this.output,
    this.evidence = const [],
    this.failure,
    this.executionId,
  });

  final ToolExecutionStatus executionStatus;
  final ToolVerificationStatus verificationStatus;
  final O? output;
  final List<ToolEvidence> evidence;
  final ToolFailure? failure;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String? executionId;

  bool get executionSucceeded => executionStatus == ToolExecutionStatus.success;
  bool get isVerified => verificationStatus == ToolVerificationStatus.verified;
  Duration get duration => finishedAt.difference(startedAt);

  ToolResult<O> copyWith({
    ToolExecutionStatus? executionStatus,
    ToolVerificationStatus? verificationStatus,
    O? output,
    List<ToolEvidence>? evidence,
    ToolFailure? failure,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? executionId,
  }) => ToolResult<O>(
    executionStatus: executionStatus ?? this.executionStatus,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    output: output ?? this.output,
    evidence: evidence ?? this.evidence,
    failure: failure ?? this.failure,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    executionId: executionId ?? this.executionId,
  );

  factory ToolResult.success({
    O? output,
    ToolVerificationStatus verificationStatus =
        ToolVerificationStatus.notRequired,
    List<ToolEvidence> evidence = const [],
    DateTime? startedAt,
    DateTime? finishedAt,
    String? executionId,
  }) {
    final start = startedAt ?? DateTime.now();
    return ToolResult<O>(
      executionStatus: ToolExecutionStatus.success,
      verificationStatus: verificationStatus,
      output: output,
      evidence: evidence,
      startedAt: start,
      finishedAt: finishedAt ?? DateTime.now(),
      executionId: executionId,
    );
  }

  factory ToolResult.failed({
    required ToolFailure failure,
    ToolVerificationStatus verificationStatus = ToolVerificationStatus.failed,
    List<ToolEvidence> evidence = const [],
    DateTime? startedAt,
    DateTime? finishedAt,
    String? executionId,
  }) {
    final start = startedAt ?? DateTime.now();
    return ToolResult<O>(
      executionStatus: ToolExecutionStatus.failed,
      verificationStatus: verificationStatus,
      evidence: evidence,
      failure: failure,
      startedAt: start,
      finishedAt: finishedAt ?? DateTime.now(),
      executionId: executionId,
    );
  }

  Map<String, Object?> toJson() => {
    'executionStatus': executionStatus.name,
    'verificationStatus': verificationStatus.name,
    'output': output,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'failure': failure?.toJson(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    'executionId': executionId,
  };
}

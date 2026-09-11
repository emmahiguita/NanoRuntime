/// WA-DRAFT-INBOX-01 — Modelo de borrador de respuesta pendiente (Modo Sugerencias).
library;

enum PendingReplyStatus {
  pending,
  approved,
  dispatching,
  dismissed,
  expired,
  superseded,
  contextChanged,
  sent,
  failed,
  outcomeUnknown,
}

final class PendingReply {
  final String id;
  final String conversationId;
  final String packageName;
  final String sender;
  final String originalMessage;
  final String draftText;
  final String sourceRuleId;
  final String notificationKey;
  final int notificationPostTime;

  /// WA-RI-05 / SOLID: Capacidad exacta de RemoteInput observada para revalidación TOCTOU
  final int actionIndex;
  final String remoteInputKey;
  final String contextFingerprint;

  final PendingReplyStatus status;
  final DateTime createdAt;
  final DateTime expiresAt; // createdAt + 24h

  const PendingReply({
    required this.id,
    required this.conversationId,
    required this.packageName,
    required this.sender,
    required this.originalMessage,
    required this.draftText,
    this.sourceRuleId = '',
    this.notificationKey = '',
    this.notificationPostTime = 0,
    this.actionIndex = -1,
    this.remoteInputKey = '',
    this.contextFingerprint = '',
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isPending => status == PendingReplyStatus.pending;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActionable =>
      (status == PendingReplyStatus.pending ||
          status == PendingReplyStatus.approved) &&
      !isExpired &&
      draftText.trim().isNotEmpty;

  /// Valida si la transición de ciclo de vida es legal (FAIL-CLOSED).
  bool canTransitionTo(PendingReplyStatus target) {
    if (status == target) return true;
    return switch (status) {
      PendingReplyStatus.pending =>
        target == PendingReplyStatus.approved ||
            target == PendingReplyStatus.dispatching ||
            target == PendingReplyStatus.sent ||
            target == PendingReplyStatus.dismissed ||
            target == PendingReplyStatus.expired ||
            target == PendingReplyStatus.superseded ||
            target == PendingReplyStatus.contextChanged ||
            target == PendingReplyStatus.failed,
      PendingReplyStatus.approved =>
        target == PendingReplyStatus.dispatching ||
            target == PendingReplyStatus.sent ||
            target == PendingReplyStatus.dismissed ||
            target == PendingReplyStatus.expired ||
            target == PendingReplyStatus.superseded ||
            target == PendingReplyStatus.contextChanged ||
            target == PendingReplyStatus.failed,
      PendingReplyStatus.dispatching =>
        target == PendingReplyStatus.sent ||
            target == PendingReplyStatus.failed ||
            target == PendingReplyStatus.contextChanged ||
            target == PendingReplyStatus.outcomeUnknown,
      PendingReplyStatus.outcomeUnknown =>
        target == PendingReplyStatus.dismissed ||
            target == PendingReplyStatus.failed,
      PendingReplyStatus.dismissed ||
      PendingReplyStatus.expired ||
      PendingReplyStatus.superseded ||
      PendingReplyStatus.contextChanged ||
      PendingReplyStatus.sent ||
      PendingReplyStatus.failed =>
        false,
    };
  }

  /// Approval belongs to one observed turn, never a matching display name
  /// or a message shared by another contact. Legacy drafts remain copyable.
  bool matchesSource({
    required String conversationId,
    required String packageName,
    required String notificationKey,
    required int notificationPostTime,
    DateTime? now,
  }) =>
      isActionable &&
      (now ?? DateTime.now()).isBefore(expiresAt) &&
      this.conversationId.isNotEmpty &&
      this.conversationId == conversationId &&
      this.packageName == packageName &&
      this.notificationKey.isNotEmpty &&
      this.notificationKey == notificationKey &&
      this.notificationPostTime > 0 &&
      this.notificationPostTime == notificationPostTime;

  PendingReply copyWith({
    String? id,
    String? conversationId,
    String? packageName,
    String? sender,
    String? originalMessage,
    String? draftText,
    String? sourceRuleId,
    String? notificationKey,
    int? notificationPostTime,
    int? actionIndex,
    String? remoteInputKey,
    String? contextFingerprint,
    PendingReplyStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return PendingReply(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      packageName: packageName ?? this.packageName,
      sender: sender ?? this.sender,
      originalMessage: originalMessage ?? this.originalMessage,
      draftText: draftText ?? this.draftText,
      sourceRuleId: sourceRuleId ?? this.sourceRuleId,
      notificationKey: notificationKey ?? this.notificationKey,
      notificationPostTime: notificationPostTime ?? this.notificationPostTime,
      actionIndex: actionIndex ?? this.actionIndex,
      remoteInputKey: remoteInputKey ?? this.remoteInputKey,
      contextFingerprint: contextFingerprint ?? this.contextFingerprint,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'packageName': packageName,
    'sender': sender,
    'originalMessage': originalMessage,
    'draftText': draftText,
    'sourceRuleId': sourceRuleId,
    'notificationKey': notificationKey,
    'notificationPostTime': notificationPostTime,
    'actionIndex': actionIndex,
    'remoteInputKey': remoteInputKey,
    'contextFingerprint': contextFingerprint,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory PendingReply.fromJson(Map<String, dynamic> json) {
    return PendingReply(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      packageName: json['packageName'] as String? ?? 'com.whatsapp',
      sender: json['sender'] as String? ?? '',
      originalMessage: json['originalMessage'] as String? ?? '',
      draftText: json['draftText'] as String? ?? '',
      sourceRuleId: json['sourceRuleId'] as String? ?? '',
      notificationKey: json['notificationKey'] as String? ?? '',
      notificationPostTime: (json['notificationPostTime'] as num?)?.toInt() ?? 0,
      actionIndex: (json['actionIndex'] as num?)?.toInt() ?? -1,
      remoteInputKey: json['remoteInputKey'] as String? ?? '',
      contextFingerprint: json['contextFingerprint'] as String? ?? '',
      status: PendingReplyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PendingReplyStatus.pending,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }
}

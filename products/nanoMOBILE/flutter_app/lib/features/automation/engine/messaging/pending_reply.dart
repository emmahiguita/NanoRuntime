/// WA-DRAFT-INBOX-01 — Modelo de borrador de respuesta pendiente (Modo Sugerencias).
library;

enum PendingReplyStatus {
  pending,
  approved,
  dismissed,
  expired,
  sent,
  failed,
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
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isPending => status == PendingReplyStatus.pending;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Approval belongs to one observed turn, never a matching display name
  /// or a message shared by another contact. Legacy drafts remain copyable.
  bool matchesSource({
    required String conversationId,
    required String packageName,
    required String notificationKey,
    required int notificationPostTime,
    DateTime? now,
  }) =>
      isPending &&
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

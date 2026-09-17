import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/tool_audit.dart';
import '../domain/tool_result.dart';

/// Bounded durable audit trail. It stores hashes, metadata and typed evidence,
/// never the original tool arguments.
final class SharedPreferencesToolAuditTrail implements ToolAuditTrail {
  const SharedPreferencesToolAuditTrail({
    this.storageKey = 'nano_tool_audit_v1',
    this.maxRecords = 200,
  });

  final String storageKey;
  final int maxRecords;

  @override
  Future<void> append(ToolExecutionRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = _decode(prefs.getString(storageKey));
    rows.add(record.toJson());
    if (rows.length > maxRecords) {
      rows.removeRange(0, rows.length - maxRecords);
    }
    final saved = await prefs.setString(storageKey, jsonEncode(rows));
    if (!saved) {
      throw StateError('No se pudo persistir ToolExecutionRecord.');
    }
  }

  @override
  Future<List<ToolExecutionRecord>> recent({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = _decode(prefs.getString(storageKey));
    return rows.reversed
        .take(limit)
        .map(_recordFromJson)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: true);
    } on Object {
      return [];
    }
  }

  ToolExecutionRecord _recordFromJson(Map<String, dynamic> row) {
    final evidenceRows = row['evidence'];
    final evidence = evidenceRows is List
        ? evidenceRows
              .whereType<Map>()
              .map((raw) {
                final item = raw.cast<String, dynamic>();
                return ToolEvidence(
                  type: ToolEvidenceType.values.firstWhere(
                    (value) => value.name == item['type'],
                    orElse: () => ToolEvidenceType.computation,
                  ),
                  source: '${item['source'] ?? 'unknown'}',
                  timestamp:
                      DateTime.tryParse('${item['timestamp'] ?? ''}') ??
                      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                  data: item['data'] is Map
                      ? (item['data'] as Map).cast<String, Object?>()
                      : const {},
                  confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
                );
              })
              .toList(growable: false)
        : const <ToolEvidence>[];
    return ToolExecutionRecord(
      executionId: '${row['executionId'] ?? ''}',
      correlationId: row['correlationId'] as String?,
      parentExecutionId: row['parentExecutionId'] as String?,
      toolId: '${row['toolId'] ?? ''}',
      toolVersion: (row['toolVersion'] as num?)?.toInt() ?? 1,
      callerRole: '${row['callerRole'] ?? 'system'}',
      conversationId: row['conversationId'] as String?,
      argumentsHash: '${row['argumentsHash'] ?? ''}',
      policyDecision: '${row['policyDecision'] ?? ''}',
      startedAt:
          DateTime.tryParse('${row['startedAt'] ?? ''}') ?? DateTime.now(),
      finishedAt:
          DateTime.tryParse('${row['finishedAt'] ?? ''}') ?? DateTime.now(),
      executionStatus: ToolExecutionStatus.values.firstWhere(
        (value) => value.name == row['executionStatus'],
        orElse: () => ToolExecutionStatus.failed,
      ),
      verificationStatus: ToolVerificationStatus.values.firstWhere(
        (value) => value.name == row['verificationStatus'],
        orElse: () => ToolVerificationStatus.unknown,
      ),
      evidence: evidence,
      failureCode: row['failureCode'] as String?,
    );
  }
}

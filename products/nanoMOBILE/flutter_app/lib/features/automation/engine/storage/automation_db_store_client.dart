/// WA-PROD-02 — cliente Dart del AutomationStoreDb (Kotlin).
///
/// El store vive en SQLite con UN escritor (Kotlin, synchronized) y
/// reemplazo atómico por sección. Este cliente es la ÚNICA vía de acceso de
/// los stores del pipeline; se registra en el engine de la UI y en el
/// headless (la base es única por proceso).
library;

import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter/services.dart';

class AutomationDbStoreClient {
  AutomationDbStoreClient._();

  static final AutomationDbStoreClient instance = AutomationDbStoreClient._();

  static const _channel = MethodChannel('com.nanoai/automation_store');

  bool _isHealthy = true;
  int _failedWriteCount = 0;
  String? _lastError;
  final ValueNotifier<bool> isHealthyNotifier = ValueNotifier<bool>(true);

  bool get isHealthy => _isHealthy;
  int get failedWriteCount => _failedWriteCount;
  String? get lastError => _lastError;

  void _recordSuccess() {
    if (!_isHealthy || _failedWriteCount > 0) {
      _isHealthy = true;
      _failedWriteCount = 0;
      _lastError = null;
      isHealthyNotifier.value = true;
    }
  }

  void _recordFailure(Object error) {
    _failedWriteCount++;
    _lastError = '$error';
    if (_isHealthy && _failedWriteCount >= 3) {
      _isHealthy = false;
      isHealthyNotifier.value = false;
    }
  }

  /// Snapshot completo de secciones (load único al arrancar un engine).
  Future<Map<String, String>> loadAll() async {
    try {
      return (await _channel.invokeMapMethod<String, String>('loadAll') ??
              const <String, String>{})
          .cast<String, String>();
    } on Object catch (error) {
      debugPrint('[automation-store] loadAll falló: $error');
      return const {};
    }
  }

  /// Sección puntual (migración + lecturas de arranque).
  Future<String?> section(String key) async {
    try {
      return await _channel.invokeMethod<String>('get', {'key': key});
    } on Object catch (error) {
      debugPrint('[automation-store] get($key) falló: $error');
      return null;
    }
  }

  Future<String?> requiredSection(String key) => _channel
      .invokeMethod<String>('get', {'key': key})
      .timeout(const Duration(seconds: 10));

  /// Reemplazo atómico de la sección. false = rechazada (whitelist/tamaño).
  Future<bool> putSection(String key, String json) async {
    try {
      final ok = await _channel.invokeMethod<bool>('put', {
            'key': key,
            'json': json,
          }) ??
          false;
      if (ok) {
        _recordSuccess();
      } else {
        _recordFailure('put($key) retornó false');
      }
      return ok;
    } on Object catch (error) {
      debugPrint('[automation-store] put($key) falló: $error');
      _recordFailure(error);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listConversationAssignments() async {
    try {
      final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'conversationAssignmentList',
      );
      return rows
              ?.map((row) => row.cast<String, dynamic>())
              .toList(growable: false) ??
          const [];
    } on Object catch (error) {
      debugPrint('[automation-store] conversationAssignmentList falló: $error');
      return const [];
    }
  }

  Future<bool> assignConversation({
    required String addressKey,
    required String scopeId,
    required String ownerId,
    required String agentId,
    String? previousAgentId,
    required String channel,
    required String appPackage,
    required String channelAccountId,
    required String conversationId,
    required int assignedAtMs,
    required String reason,
    String minimalContext = '',
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('conversationAssign', {
            'addressKey': addressKey,
            'scopeId': scopeId,
            'ownerId': ownerId,
            'agentId': agentId,
            if (previousAgentId != null) 'previousAgentId': previousAgentId,
            'channel': channel,
            'appPackage': appPackage,
            'channelAccountId': channelAccountId,
            'conversationId': conversationId,
            'assignedAtMs': assignedAtMs,
            'reason': reason,
            'minimalContext': minimalContext,
          }) ??
          false;
      if (ok) {
        _recordSuccess();
      } else {
        _recordFailure('conversationAssign retornó false');
      }
      return ok;
    } on Object catch (error) {
      debugPrint('[automation-store] conversationAssign falló: $error');
      _recordFailure(error);
      return false;
    }
  }

  Future<bool> appendConversationMessage({
    required String scopeId,
    required String eventId,
    required String direction,
    required String deliveryState,
    required String sender,
    required String body,
    required int atMs,
    String ruleId = '',
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('conversationMessageAppend', {
            'scopeId': scopeId,
            'eventId': eventId,
            'direction': direction,
            'deliveryState': deliveryState,
            'sender': sender,
            'body': body,
            'atMs': atMs,
            'ruleId': ruleId,
          }) ??
          false;
      if (ok) {
        _recordSuccess();
      } else {
        _recordFailure('conversationMessageAppend retornó false');
      }
      return ok;
    } on Object catch (error) {
      debugPrint('[automation-store] conversationMessageAppend falló: $error');
      _recordFailure(error);
      return false;
    }
  }

  Future<bool> putConversationDialogueState({
    required String scopeId,
    required String stateJson,
    required int updatedAtMs,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('conversationStatePut', {
            'scopeId': scopeId,
            'stateJson': stateJson,
            'updatedAtMs': updatedAtMs,
          }) ??
          false;
      if (ok) {
        _recordSuccess();
      } else {
        _recordFailure('conversationStatePut retornó false');
      }
      return ok;
    } on Object catch (error) {
      debugPrint('[automation-store] conversationStatePut falló: $error');
      _recordFailure(error);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listConversationMessages({
    required String scopeId,
    int limit = 200,
  }) async {
    try {
      final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'conversationMessageList',
        {
          'scopeId': scopeId,
          'limit': limit,
        },
      );
      if (rows == null) return const [];
      return rows
          .map((r) => r.cast<String, dynamic>())
          .toList(growable: false);
    } on Object catch (error) {
      debugPrint('[automation-store] conversationMessageList falló: $error');
      return const [];
    }
  }

  /// WA-EVLOG-01 — bitácora append-only del pipeline (auditoría local).
  /// Best-effort: un fallo jamás interrumpe el pipeline.
  Future<bool> appendPipelineEvent({
    required String conversationId,
    required String kind,
    required String detail,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('appendEvent', {
            'convId': conversationId,
            'kind': kind,
            'detail': detail,
          }) ??
          false;
    } on Object catch (error) {
      debugPrint('[automation-store] appendEvent falló: $error');
      return false;
    }
  }

  // Phase 6 - Durable Scheduling

  Future<bool> upsertOccurrence(
    String ruleId,
    String occurrenceId,
    int scheduledAtMs,
  ) async {
    try {
      return await _channel.invokeMethod<bool>('occurrenceUpsert', {
            'ruleId': ruleId,
            'occurrenceId': occurrenceId,
            'scheduledAtMs': scheduledAtMs,
          }) ??
          false;
    } on Object catch (error) {
      debugPrint('[automation-store] occurrenceUpsert falló: $error');
      return false;
    }
  }

  Future<bool> claimOccurrence(String occurrenceId) async {
    try {
      return await _channel.invokeMethod<bool>('occurrenceClaim', {
            'occurrenceId': occurrenceId,
          }) ??
          false;
    } on Object catch (error) {
      debugPrint('[automation-store] occurrenceClaim falló: $error');
      return false;
    }
  }

  Future<bool> updateOccurrenceStatus(
    String occurrenceId,
    String status, {
    String? reason,
  }) async {
    try {
      final args = <String, dynamic>{
        'occurrenceId': occurrenceId,
        'status': status,
      };
      if (reason != null) args['reason'] = reason;
      return await _channel.invokeMethod<bool>(
            'occurrenceUpdateStatus',
            args,
          ) ??
          false;
    } on Object catch (error) {
      debugPrint('[automation-store] occurrenceUpdateStatus falló: $error');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> recoverOccurrences() async {
    try {
      final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'occurrenceRecover',
      );
      return result?.map((e) => e.cast<String, dynamic>()).toList() ?? [];
    } on Object catch (error) {
      debugPrint('[automation-store] occurrenceRecover falló: $error');
      return [];
    }
  }
}

/// WA-PROD-02 — cliente Dart del AutomationStoreDb (Kotlin).
///
/// El store vive en SQLite con UN escritor (Kotlin, synchronized) y
/// reemplazo atómico por sección. Este cliente es la ÚNICA vía de acceso de
/// los stores del pipeline; se registra en el engine de la UI y en el
/// headless (la base es única por proceso).
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

class AutomationDbStoreClient {
  AutomationDbStoreClient._();

  static final AutomationDbStoreClient instance = AutomationDbStoreClient._();

  static const _channel = MethodChannel('com.nanoai/automation_store');

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
      return await _channel.invokeMethod<bool>('put', {
            'key': key,
            'json': json,
          }) ??
          false;
    } on Object catch (error) {
      debugPrint('[automation-store] put($key) falló: $error');
      return false;
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

  Future<bool> upsertOccurrence(String ruleId, String occurrenceId, int scheduledAtMs) async {
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

  Future<bool> updateOccurrenceStatus(String occurrenceId, String status, {String? reason}) async {
    try {
      final args = <String, dynamic>{
        'occurrenceId': occurrenceId,
        'status': status,
      };
      if (reason != null) args['reason'] = reason;
      return await _channel.invokeMethod<bool>('occurrenceUpdateStatus', args) ?? false;
    } on Object catch (error) {
      debugPrint('[automation-store] occurrenceUpdateStatus falló: $error');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> recoverOccurrences() async {
    try {
      final result = await _channel.invokeListMethod<Map<Object?, Object?>>('occurrenceRecover');
      return result?.map((e) => e.cast<String, dynamic>()).toList() ?? [];
    } on Object catch (error) {
      debugPrint('[automation-store] occurrenceRecover falló: $error');
      return [];
    }
  }
}

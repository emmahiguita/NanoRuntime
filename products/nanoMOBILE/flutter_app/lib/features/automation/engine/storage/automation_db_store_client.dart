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
}

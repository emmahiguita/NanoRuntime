// models_scan_coordinator.dart — Coordinador de escaneo de almacenamiento local y permisos.
// QUÉ HACE: Gestiona escaneos SAF y MANAGE_EXTERNAL_STORAGE con throttling de 30 segundos.
// CÓMO FUNCIONA: Consulta canales de plataforma de almacenamiento y evita re-escaneos redundantes.
// POR QUÉ: Elimina cuellos de botella de I/O en disco durante transiciones de pantalla (< 200 líneas).
library;

import '../domain/detected_model.dart';
import '../domain/model_storage_repository.dart';

class ModelsScanCoordinator {
  final ModelStorageRepository storage;
  DateTime? _lastSafScanAt;
  DateTime? _lastAllScanAt;

  ModelsScanCoordinator({required this.storage});

  /// Throttling de 30s para escaneos de todo el almacenamiento.
  bool shouldThrottleAllScan() {
    final last = _lastAllScanAt;
    return last != null && DateTime.now().difference(last).inSeconds < 30;
  }

  /// Throttling de 30s para escaneos de árbol SAF.
  bool shouldThrottleSafScan() {
    final last = _lastSafScanAt;
    return last != null && DateTime.now().difference(last).inSeconds < 30;
  }

  Future<List<DetectedModel>> scanAll() async {
    final list = await storage.scanAll();
    _lastAllScanAt = DateTime.now();
    return list;
  }

  Future<List<DetectedModel>> scanSaf() async {
    final list = await storage.scan();
    _lastSafScanAt = DateTime.now();
    return list;
  }

  Future<String?> persistedTree() => storage.persistedTree().catchError((_) => null);
  Future<bool> hasAllFilesAccess() => storage.hasAllFilesAccess().catchError((_) => false);
  Future<bool> requestAllFilesAccess() => storage.requestAllFilesAccess();
  Future<String?> openFd(String uri) => storage.openFd(uri);
  Future<String?> pickTree() => storage.pickTree();

  void resetThrottles() {
    _lastSafScanAt = null;
    _lastAllScanAt = null;
  }
}

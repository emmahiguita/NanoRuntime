import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog_models.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/runtime_engine.dart';
import 'chat_model_storage.dart';

/// Servicio responsable del ciclo de vida del modelo LLM, debounce de selección,
/// verificación del runtime local y rotación de sesión.
///
/// **QUÉ HACE:**
/// Orquesta la inicialización del modelo activo, asegurando que el motor de inferencia
/// local responda antes de emitir estados listos a la interfaz de usuario.
///
/// **CÓMO FUNCIONA:**
/// - Utiliza `ChatModelStorage` para hidratar el último modelo persistido.
/// - Aplica debouncing (600ms) ante cambios repetidos de modelo en la UI.
/// - Controla revisiones numéricas (`_modelSelectionRevision`) para descartar carreras asíncronas.
///
/// **POR QUÉ:**
/// Centraliza la orquestación del modelo sin mezclar UI ni streaming, previniendo
/// condiciones de carrera y fugas de temporizadores.
class ChatModelService {
  final Ref _ref;
  final ChatModelStorage _storage;
  int _modelSelectionRevision = 0;
  Timer? _loadTimer;
  String _sessionId = newSessionId();

  static int _sessionSeq = 0;

  static String newSessionId() =>
      'chat-${DateTime.now().microsecondsSinceEpoch}-${++_sessionSeq}';

  ChatModelService(this._ref, [this._storage = const ChatModelStorage()]);

  String get sessionId => _sessionId;
  int get modelSelectionRevision => _modelSelectionRevision;

  void rotateSession() {
    _sessionId = newSessionId();
  }

  /// Restaura la última selección de modelo para que sobreviva al reinicio de la app.
  Future<void> restoreModel({
    required bool Function() isMounted,
    required void Function({
      required String model,
      required String path,
      required ModelConnectionState connection,
    }) onModelRestored,
    required Future<void> Function(String model, int revision) onCheckEngine,
  }) async {
    final revision = _modelSelectionRevision;
    final saved = await _storage.loadSavedModel();
    if (saved == null || !isMounted() || revision != _modelSelectionRevision) return;

    onModelRestored(
      model: saved.model,
      path: saved.path,
      connection: ModelConnectionState.loadingModel,
    );
    await onCheckEngine(saved.model, revision);
  }

  /// Persiste la selección en Settings y claves legacy de SharedPreferences.
  void persistModelSelection(String name, String? path) {
    final cleanPath = path?.trim() ?? '';
    _ref.read(settingsProvider.notifier).setChatModel(name, cleanPath);
    unawaited(_storage.saveLegacy(name, cleanPath));
  }

  /// Re-comprueba la conectividad real con el motor llama.cpp y, si hay un
  /// modelo instalado, lo arranca (`ensureReady`) evitando deadlocks.
  Future<void> refreshEngine({
    required String? activeModelPath,
    required bool Function() isMounted,
    required void Function({required bool online, ModelConnectionState? conn}) onEngineUpdated,
  }) async {
    final engine = _ref.read(runtimeEngineProvider.notifier);
    if (activeModelPath != null) {
      final ready = await engine.ensureReady(modelPath: activeModelPath);
      if (!isMounted()) return;
      onEngineUpdated(
        online: ready || engine.isLive,
        conn: ready ? ModelConnectionState.ready : ModelConnectionState.error,
      );
      return;
    }
    await engine.refresh();
    if (!isMounted()) return;
    onEngineUpdated(online: engine.isLive);
  }

  /// Consulta el estado real del motor y actualiza el estado de conexión.
  Future<void> checkEngine({
    required String activeModel,
    int? expectedRevision,
    required bool Function() isMounted,
    required void Function({
      required String model,
      required ModelConnectionState connection,
      required bool online,
    }) onStateUpdated,
  }) async {
    final engine = _ref.read(runtimeEngineProvider.notifier);
    await engine.refresh();
    if (!isMounted() || (expectedRevision != null && expectedRevision != _modelSelectionRevision)) {
      return;
    }
    onStateUpdated(
      model: activeModel,
      connection: switch (engine.phase) {
        EnginePhase.ready => ModelConnectionState.ready,
        EnginePhase.degraded => ModelConnectionState.noModel,
        _ => ModelConnectionState.error,
      },
      online: engine.isLive,
    );
  }

  /// Maneja la selección de modelo, validación de EXTREME (9B+), rotación de sesión y debounce.
  void selectModel({
    required String name,
    String? path,
    bool confirmedExtreme = false,
    required String currentModel,
    required String? currentModelPath,
    required void Function({required String selectedModel, required String? selectedPath}) onSelectionStarted,
    required Future<void> Function(String model, int revision) onCheckEngine,
  }) {
    final entry = NeuralCatalog.entryOf(name);
    if (entry.name == name && entry.tier == ModelTier.extreme && !confirmedExtreme) {
      debugPrint('[ChatModelService] selectModel extreme ($name) sin confirmación — ignorado');
      return;
    }

    final modelChanged = name != currentModel;
    final pathChanged = path != null && path != currentModelPath;
    if (modelChanged || pathChanged) {
      rotateSession();
      debugPrint('[ChatModelService] modelo cambiado → nueva sesión $_sessionId');
    }
    final revision = ++_modelSelectionRevision;
    final selectedPath = modelChanged ? path : (path ?? currentModelPath);

    onSelectionStarted(selectedModel: name, selectedPath: selectedPath);
    persistModelSelection(name, selectedPath);

    _loadTimer?.cancel();
    _loadTimer = Timer(const Duration(milliseconds: 600), () async {
      _loadTimer = null;
      await onCheckEngine(name, revision);
    });
  }

  void dispose() {
    _loadTimer?.cancel();
    _loadTimer = null;
  }
}

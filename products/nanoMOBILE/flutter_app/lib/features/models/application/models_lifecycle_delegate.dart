// models_lifecycle_delegate.dart — Delegado de ciclo de vida (activación, descarga y borrado de modelos).
// QUÉ HACE: Centraliza la lógica de selección en ChatProvider, Whisper y eliminación de archivos GGUF.
// CÓMO FUNCIONA: Métodos desacoplados invocados por ModelsNotifier asegurando SRP y alta cohesión.
// POR QUÉ: Reduce el acoplamiento y mantiene ModelsNotifier estrictamente bajo 200 líneas.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/whisper_stt_service.dart';
import '../domain/detected_model.dart';
import '../domain/local_model.dart';
import 'model_file_manager.dart';

class ModelsLifecycleDelegate {
  const ModelsLifecycleDelegate();

  // QUÉ HACE: Carga el modelo en el motor de inferencia local o servicio Whisper STT.
  // CÓMO FUNCIONA: Si es STT lo asocia a WhisperSttService; si es LLM lo pasa a chatProvider.
  // POR QUÉ: Permite alternar modelos de lenguaje y voz de forma transparente.
  Future<bool> loadModel({
    required Ref ref,
    required LocalModel item,
    bool confirmedExtreme = false,
  }) async {
    if (!item.installed || item.localPath == null) return false;
    if (item.kind == ModelKind.voiceStt) {
      await WhisperSttService.instance.setActiveModel(item.fileName, item.localPath!);
      return true;
    }
    ref.read(chatProvider.notifier).selectModel(item.name, path: item.localPath, confirmedExtreme: confirmedExtreme);
    return false;
  }

  // QUÉ HACE: Descarga el modelo activo del motor de inferencia liberando memoria RAM.
  void unloadModel(Ref ref) => ref.read(chatProvider.notifier).selectModel('', path: null);

  // QUÉ HACE: Descarga el modelo de voz Whisper liberando recursos de audio.
  Future<void> unloadVoiceModel() async => WhisperSttService.instance.clearActiveModel();

  // QUÉ HACE: Elimina el archivo binario del modelo y descarga del runtime si estaba activo.
  Future<void> deleteModel({
    required Ref ref,
    required LocalModel item,
  }) async {
    if (!item.installed || item.localPath == null) return;
    await ModelFileManager.deletePhysicalFile(item.localPath);
    if (ref.read(chatProvider).activeModel.toLowerCase().contains(item.name.toLowerCase())) {
      unloadModel(ref);
    }
    if (WhisperSttService.instance.activeModelFile == item.fileName) {
      await unloadVoiceModel();
    }
  }

  // QUÉ HACE: Elimina modelo detectado en almacenamiento externo.
  Future<void> deleteDetectedModel({
    required Ref ref,
    required DetectedModel model,
    bool deletePhysicalFile = true,
  }) async {
    if (deletePhysicalFile) await ModelFileManager.deletePhysicalFile(model.path);
    if (ref.read(chatProvider).activeModel.toLowerCase().contains(model.name.toLowerCase())) {
      unloadModel(ref);
    }
  }

  // QUÉ HACE: Activa un modelo detectado en almacenamiento externo.
  // CÓMO FUNCIONA: Si tiene path lo envía directamente; si tiene URI abre el descriptor vía scanner.
  // POR QUÉ: Permite reutilizar modelos sin copiarlos a almacenamiento interno.
  Future<String?> useDetected({
    required Ref ref,
    required DetectedModel model,
    required Future<String?> Function(String uri) openFd,
  }) async {
    if (model.path != null) {
      ref.read(chatProvider.notifier).selectModel(model.name, path: model.path);
      return null;
    }
    final fd = await openFd(model.uri);
    if (fd != null) {
      ref.read(chatProvider.notifier).selectModel(model.name, path: fd);
    }
    return fd;
  }
}

// whisper_stt_service.dart — Transcripción local offline con whisper.cpp (licencia MIT).
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/models/data/catalog_local_model_repository.dart';
import 'nano_runtime_api.dart';

/// Servicio centralizado de voz local Whisper.cpp
class WhisperSttService {
  WhisperSttService._();
  static final WhisperSttService instance = WhisperSttService._();

  static const String prefActiveWhisperKey = 'active_whisper_model_file';
  static const String prefActiveWhisperPathKey = 'active_whisper_model_path';

  String? _activeModelFile;
  String? _activeModelPath;
  bool _initialized = false;

  String? get activeModelFile => _activeModelFile;
  String? get activeModelPath => _activeModelPath;
  bool get hasActiveModel => _activeModelPath != null && File(_activeModelPath!).existsSync();

  /// Inicializa la preferencia de modelo activo desde almacenamiento local
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeModelFile = prefs.getString(prefActiveWhisperKey);
      _activeModelPath = prefs.getString(prefActiveWhisperPathKey);

      // Si hay modelo seleccionado pero el archivo ya no existe, limpiarlo
      if (_activeModelPath != null && !File(_activeModelPath!).existsSync()) {
        await clearActiveModel();
      } else if (_activeModelPath == null) {
        // Auto-seleccionar primer modelo disponible en disco
        await autoSelectAvailableModel();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[WhisperSttService] Error al inicializar: $e');
    }
  }

  /// Establece y persiste el modelo Whisper local activo
  Future<void> setActiveModel(String fileName, String localPath) async {
    _activeModelFile = fileName;
    _activeModelPath = localPath;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefActiveWhisperKey, fileName);
      await prefs.setString(prefActiveWhisperPathKey, localPath);
    } catch (_) {}
  }

  /// Limpia la selección del modelo Whisper activo
  Future<void> clearActiveModel() async {
    _activeModelFile = null;
    _activeModelPath = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefActiveWhisperKey);
      await prefs.remove(prefActiveWhisperPathKey);
    } catch (_) {}
  }

  /// Busca si ggml-tiny.bin o ggml-base.bin están presentes en el almacenamiento
  Future<String?> findInstalledModelPath(String fileName) async {
    final dir = await CatalogLocalModelRepository.modelsDir();
    if (dir != null) {
      final file = File('$dir${Platform.pathSeparator}$fileName');
      if (file.existsSync()) return file.path;
    }
    for (final base in ['/data/user/0/dev.nanoai.mobile/files/nano/models', '/data/data/dev.nanoai.mobile/files/nano/models']) {
      final f = File('$base${Platform.pathSeparator}$fileName');
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  /// Auto-selecciona el modelo más ligero disponible si no hay uno activo
  Future<void> autoSelectAvailableModel() async {
    final tiny = await findInstalledModelPath('ggml-tiny.bin');
    if (tiny != null) return setActiveModel('ggml-tiny.bin', tiny);
    final base = await findInstalledModelPath('ggml-base.bin');
    if (base != null) return setActiveModel('ggml-base.bin', base);
  }

  /// Ejecuta la transcripción de un archivo de audio con el modelo Whisper activo
  Future<String?> transcribeAudio({
    required File audioFile,
    void Function(String progress)? onProgress,
  }) async {
    await init();
    if (!hasActiveModel) {
      await autoSelectAvailableModel();
      if (!hasActiveModel) return null;
    }

    final modelPath = _activeModelPath!;
    final modelName = _activeModelFile ?? 'Whisper GGML';
    onProgress?.call('Procesando con $modelName local...');

    File targetAudio = audioFile;
    File? tempConvertedFile;

    try {
      if (!audioFile.existsSync() || await audioFile.length() == 0) {
        return 'Error: Archivo de audio vacío o inexistente.';
      }

      // Decodificación a WAV PCM requerida para formatos como .opus, .m4a, .aac
      if (!audioFile.path.toLowerCase().endsWith('.wav')) {
        final wavPath = await NanoRuntimeApi.instance.convertAudioToWav(audioFile.path);
        if (wavPath != null && File(wavPath).existsSync()) {
          targetAudio = File(wavPath);
          tempConvertedFile = targetAudio;
        }
      }

      final whisperCliPath = await _resolveWhisperExecutable();
      if (whisperCliPath == null) {
        debugPrint('[WhisperSttService] whisper-cli no disponible en el entorno.');
        return null;
      }

      final engineDir = File(whisperCliPath).parent.path;
      final isScript = whisperCliPath.endsWith('.sh');
      final hasLinker = File('/system/bin/linker64').existsSync();
      final exec = isScript
          ? '/system/bin/sh'
          : (hasLinker ? '/system/bin/linker64' : whisperCliPath);
      final args = [
        if (isScript || (!isScript && hasLinker)) whisperCliPath,
        '-m', modelPath, '-f', targetAudio.path, '-l', 'es',
        '--no-timestamps', '--no-prints',
      ];
      final result = await Process.run(
        exec,
        args,
        environment: {'LD_LIBRARY_PATH': '$engineDir:/system/lib64'},
      ).timeout(
        const Duration(seconds: 35),
        onTimeout: () => ProcessResult(-1, -1, '', 'Timeout en transcripción local.'),
      );

      if (result.exitCode == 0) {
        final text = (result.stdout as String).trim();
        return text.isNotEmpty ? text : null;
      }
      debugPrint('[WhisperSttService] Error en CLI: ${result.stderr}');
      return null;
    } catch (e) {
      debugPrint('[WhisperSttService] Excepción durante transcripción: $e');
      return null;
    } finally {
      if (tempConvertedFile != null && tempConvertedFile.existsSync()) {
        try { tempConvertedFile.deleteSync(); } catch (_) {}
      }
    }
  }

  /// Resuelve la ruta del ejecutable whisper-cli o wrapper en el sandbox de la app
  Future<String?> _resolveWhisperExecutable() async {
    try {
      final models = await CatalogLocalModelRepository.modelsDir();
      if (models != null) {
        final nano = File(models).parent.path;
        final w = File('$nano/engine/whisper.sh');
        if (w.existsSync()) return w.path;
        final c = File('$nano/engine/whisper-cli');
        if (c.existsSync()) return c.path;
      }
    } catch (_) {}

    const candidates = [
      '/data/user/0/dev.nanoai.mobile/files/nano/engine/whisper.sh',
      '/data/data/dev.nanoai.mobile/files/nano/engine/whisper.sh',
      '/data/user/0/dev.nanoai.mobile/files/nano/engine/whisper-cli',
      '/data/data/dev.nanoai.mobile/files/nano/engine/whisper-cli',
      '/data/local/tmp/whisper.sh',
      '/data/local/tmp/whisper-cli',
      'whisper-cli',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
      try {
        final res = await Process.run('which', [c]);
        if (res.exitCode == 0 && (res.stdout as String).trim().isNotEmpty) return c;
      } catch (_) {}
    }
    return null;
  }
}

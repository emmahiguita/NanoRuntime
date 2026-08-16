import 'package:flutter/services.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/model_storage_repository.dart';

/// Implementación real sobre el canal `com.nanoai/model_storage` (Kotlin).
///
/// El escaneo (walk del árbol SAF) corre en Kotlin: cruzar la frontera solo
/// con metadatos evita serializar miles de nodos en Dart.
class ChannelModelStorageRepository implements ModelStorageRepository {
  const ChannelModelStorageRepository();

  static const _channel = MethodChannel(NanoRuntimeChannels.modelStorage);

  @override
  Future<String?> pickTree() async {
    try {
      return await _channel.invokeMethod<String>('pickTree');
    } on PlatformException {
      // "pick_pending": selector anterior aún abierto — sin cambios.
      return null;
    }
  }

  @override
  Future<String?> persistedTree() async {
    return await _channel.invokeMethod<String>('persistedTree');
  }

  @override
  Future<List<DetectedModel>> scan() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('scan');
    if (raw == null) {
      throw StateError('storage tree no concedido');
    }
    return [
      for (final item in raw)
        _fromMap((item as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<String?> openFd(String uri) async {
    return await _channel.invokeMethod<String>('openFd', {'uri': uri});
  }

  @override
  Future<List<DetectedModel>> scanAll() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('scanAll');
    if (raw == null) {
      throw StateError('acceso a todos los archivos no concedido');
    }
    return [
      for (final item in raw)
        _fromMap((item as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<bool> hasAllFilesAccess() async {
    return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
  }

  @override
  Future<bool> requestAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('requestAllFilesAccess') ??
          false;
    } on PlatformException {
      // "pending": solicitud anterior aún abierta — el permiso no cambió.
      return false;
    }
  }

  DetectedModel _fromMap(Map<String, Object?> map) {
    final format = switch (map['format'] as String? ?? '') {
      'gguf' => DetectedModelFormat.gguf,
      'safetensors' => DetectedModelFormat.safetensors,
      'onnx' => DetectedModelFormat.onnx,
      _ => DetectedModelFormat.onnx,
    };
    return DetectedModel(
      name: map['name'] as String? ?? 'desconocido',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? -1,
      uri: map['uri'] as String? ?? '',
      format: format,
      magicOk: map['magicOk'] as bool? ?? false,
      path: map['path'] as String?,
    );
  }
}

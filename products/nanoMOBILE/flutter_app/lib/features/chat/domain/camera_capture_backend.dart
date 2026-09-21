import 'package:flutter/services.dart';

import '../../../core/services/nano_runtime_api.dart';

/// Resultado factual de una foto escrita por la cámara del sistema.
class CapturedPhoto {
  const CapturedPhoto({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final int sizeBytes;
}

/// Puerto inyectable: la UI no depende directamente de Android ni de plugins.
abstract interface class CameraCaptureBackend {
  Future<CapturedPhoto?> capturePhoto();
}

/// Adaptador Android sin peso binario: delega en ACTION_IMAGE_CAPTURE.
class AndroidCameraCaptureBackend implements CameraCaptureBackend {
  const AndroidCameraCaptureBackend({
    MethodChannel channel = const MethodChannel(
      NanoRuntimeChannels.mediaCapture,
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<CapturedPhoto?> capturePhoto() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'capturePhoto',
      );
      if (raw == null) return null;
      final path = raw['path'];
      final name = raw['name'];
      final size = raw['sizeBytes'];
      if (path is! String || name is! String || size is! num || size <= 0) {
        return null;
      }
      return CapturedPhoto(path: path, name: name, sizeBytes: size.toInt());
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

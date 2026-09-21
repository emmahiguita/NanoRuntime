import 'dart:io';
import 'dart:typed_data';

import '../../../core/services/nano_runtime_api.dart';

typedef ImageLabeler = Future<List<dynamic>> Function(Uint8List bytes);

/// Puerto del chat para convertir una imagen real en observaciones verificables.
abstract interface class ChatVisionAdapter {
  Future<String?> describe(String path);
}

/// Puente multimodal liviano: bytes de imagen -> ML Kit -> contexto de texto.
///
/// No simula un VLM: comunica que el resultado es clasificación general y
/// nunca afirma texto, relaciones espaciales ni detalles que ML Kit no produjo.
class MlKitChatVisionAdapter implements ChatVisionAdapter {
  MlKitChatVisionAdapter({
    ImageLabeler? labelImage,
    this.maxBytes = 12 * 1024 * 1024,
  }) : _labelImage = labelImage ?? NanoRuntimeApi.instance.visionLabel;

  final ImageLabeler _labelImage;
  final int maxBytes;

  @override
  Future<String?> describe(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final length = await file.length();
      if (length <= 0 || length > maxBytes) return null;

      final rawLabels = await _labelImage(await file.readAsBytes());
      final labels = <String>[];
      for (final raw in rawLabels) {
        if (raw is! Map) continue;
        final label = '${raw['label'] ?? ''}'.trim();
        final confidence = (raw['confidence'] as num?)?.toDouble();
        if (label.isEmpty || confidence == null || confidence < 0.5) continue;
        labels.add('$label (${(confidence * 100).round()}%)');
        if (labels.length == 6) break;
      }
      if (labels.isEmpty) return null;

      return '[Observación visual local: ${labels.join(', ')}]\n'
          'Estas son etiquetas de clasificación de ML Kit; no son OCR, '
          'descripción espacial ni una interpretación completa de la imagen.';
    } catch (_) {
      return null;
    }
  }
}

import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/services/nano_runtime_api.dart';

typedef ImageLabeler = Future<List<dynamic>> Function(Uint8List bytes);
typedef ImageEvidenceReader =
    Future<Map<dynamic, dynamic>?> Function(String path);

/// Puerto del chat para convertir una imagen real en observaciones verificables.
abstract interface class ChatVisionAdapter {
  Future<String?> describe(String path);
}

/// Convierte una imagen real en evidencia OCR y etiquetas locales para el chat.
/// No sustituye un VLM ni afirma relaciones espaciales o comprensión completa.
class MlKitChatVisionAdapter implements ChatVisionAdapter {
  MlKitChatVisionAdapter({
    ImageLabeler? labelImage,
    ImageEvidenceReader? readImageEvidence,
    this.maxBytes = 12 * 1024 * 1024,
  }) : _labelImage = labelImage ?? NanoRuntimeApi.instance.visionLabel,
       _readImageEvidence = readImageEvidence ?? _readNativeImageEvidence;

  static const MethodChannel _documentChannel = MethodChannel(
    'dev.nanoai/pdf_text',
  );

  final ImageLabeler _labelImage;
  final ImageEvidenceReader _readImageEvidence;
  final int maxBytes;

  static Future<Map<dynamic, dynamic>?> _readNativeImageEvidence(
    String path,
  ) async {
    try {
      return await _documentChannel.invokeMapMethod<dynamic, dynamic>(
        'readMessageImage',
        {'path': path},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<String?> describe(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final length = await file.length();
      if (length <= 0 || length > maxBytes) return null;

      final nativeEvidence = await _readImageEvidence(path);
      final ocrText = '${nativeEvidence?['text'] ?? ''}'.trim();
      final nativeLabels = nativeEvidence?['labels'];
      final rawLabels = nativeLabels is List && nativeLabels.isNotEmpty
          ? nativeLabels
          : await _labelImage(await file.readAsBytes());
      final labels = <String>[];
      for (final raw in rawLabels) {
        if (raw is! Map) continue;
        final label = '${raw['label'] ?? ''}'.trim();
        final confidence = (raw['confidence'] as num?)?.toDouble();
        if (label.isEmpty || confidence == null || confidence < 0.5) continue;
        labels.add('$label (${(confidence * 100).round()}%)');
        if (labels.length == 6) break;
      }
      if (labels.isEmpty && ocrText.isEmpty) return null;

      final observations = <String>[];
      if (ocrText.isNotEmpty) {
        observations.add('Texto OCR observado:\n$ocrText');
      }
      if (labels.isNotEmpty) {
        observations.add('Etiquetas generales: ${labels.join(', ')}');
      }
      final coverage = '${nativeEvidence?['coverage'] ?? ''}'.trim();
      final limits = coverage.isEmpty
          ? 'El OCR y las etiquetas no equivalen a comprensión visual completa.'
          : '$coverage; no equivale a comprensión visual completa.';
      return '[Observación visual local: ${observations.join('\n')}]\n$limits';
    } catch (_) {
      return null;
    }
  }
}

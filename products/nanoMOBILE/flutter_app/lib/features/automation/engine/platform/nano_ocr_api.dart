/// Frontera nativa de OCR (A9). El nativo captura pantalla (AccessibilityService
/// takeScreenshot) + recorta región + ML Kit Text Recognition en UN paso; aquí
/// se exponen las abstracciones DIP ([ScreenImageProvider] + [OcrBackend]).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/nano_runtime_api.dart'
    show NanoRuntimeChannels;
import '../perception/mux/ocr_contracts.dart';
import '../perception/nano_snapshot.dart' show NanoBounds;

/// Transporte MethodChannel del OCR (canal `com.nanoai/agent`, método
/// `ocrRegion`). Devuelve lista de {text, bounds} o null si falla.
class NanoOcrApi {
  static final NanoOcrApi instance = NanoOcrApi();
  static const _agent = MethodChannel(NanoRuntimeChannels.agent);

  Future<List<dynamic>?> ocrRegion(List<int>? bounds) async {
    try {
      return await _agent.invokeListMethod<dynamic>('ocrRegion', {
        'bounds': bounds,
      });
    } catch (e) {
      debugPrint('[ocr] ocrRegion error: $e');
      return null;
    }
  }
}

/// Captura de pantalla. En A9 el screenshot se captura en nativo DENTRO del
/// recognize (un solo paso); este provider solo propaga la región (bounds) al
/// [MlKitOcrBackend]. Los bytes intermedios no cruzan el MethodChannel.
class AccessibilityScreenImageProvider implements ScreenImageProvider {
  const AccessibilityScreenImageProvider();

  @override
  Future<ScreenImageResult> capture({NanoBounds? region}) async {
    return ScreenImageResult.ok(
      ScreenImage(
        bounds:
            region ?? const NanoBounds(left: 0, top: 0, right: 0, bottom: 0),
        width: 0,
        height: 0,
        pngBytes: Uint8List(0),
      ),
    );
  }
}

/// OCR on-device (ML Kit bundled). Usa la región del [ScreenImage] para que el
/// nativo capture + recorte + reconozca en un paso. Confidence fija 0.85: ML Kit
/// no expone confianza granular fiable (documentado).
class MlKitOcrBackend implements OcrBackend {
  MlKitOcrBackend({NanoOcrApi? api}) : _api = api ?? NanoOcrApi.instance;

  final NanoOcrApi _api;

  @override
  Future<OcrResult> recognize(OcrRequest request) async {
    final b = request.image.bounds;
    final region = (b.width == 0 && b.height == 0)
        ? null
        : [b.left, b.top, b.right, b.bottom];
    final raw = await _api.ocrRegion(region);
    if (raw == null) return const OcrResult(observations: []);
    final observations = raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) {
          final text = m['text'] as String? ?? '';
          final list = m['bounds'] as List? ?? const [];
          return OcrObservation(
            text: text,
            bounds: list.length >= 4
                ? NanoBounds.fromList(list.cast<dynamic>())
                : const NanoBounds(left: 0, top: 0, right: 0, bottom: 0),
            confidence: 0.85,
          );
        })
        .where((o) => o.text.isNotEmpty)
        .toList(growable: false);
    return OcrResult(observations: observations);
  }
}

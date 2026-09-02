/// OcrBackend / ScreenImageProvider (A9) — puertos de lectura visual de texto.
///
/// OCR es percepción, NO autoridad. El texto reconocido es OBSERVACIÓN NO
/// CONFIABLE: nunca goal, instrucción, policy, capability, privilege, tool ni
/// CandidateAction.
library;

import 'dart:typed_data';

import '../nano_snapshot.dart' show NanoBounds;

/// Imagen de pantalla (bytes PNG). [bounds] es la región capturada (crop o
/// full-screen); [width]/[height] son las dimensiones reales en px.
class ScreenImage {
  final NanoBounds bounds;
  final int width;
  final int height;
  final Uint8List pngBytes;

  const ScreenImage({
    required this.bounds,
    required this.width,
    required this.height,
    required this.pngBytes,
  });
}

class ScreenImageResult {
  final bool captured;
  final ScreenImage? image;
  final String? error;

  const ScreenImageResult.ok(this.image) : captured = true, error = null;

  const ScreenImageResult.failure(this.error) : captured = false, image = null;
}

/// Captura imagen de pantalla (crop de [region] si se da, o full-screen).
abstract interface class ScreenImageProvider {
  Future<ScreenImageResult> capture({NanoBounds? region});
}

/// Solicitud de OCR sobre una imagen ya capturada.
class OcrRequest {
  final ScreenImage image;
  const OcrRequest({required this.image});
}

/// Una observación de texto reconocido (texto + bounds + confidence).
/// [bounds] es relativo a la imagen de la que salió.
class OcrObservation {
  final String text;
  final NanoBounds bounds;
  final double confidence;

  const OcrObservation({
    required this.text,
    required this.bounds,
    required this.confidence,
  });
}

class OcrResult {
  final List<OcrObservation> observations;
  const OcrResult({required this.observations});
}

/// Reconoce texto en una imagen. Implementación concreta en platform.
abstract interface class OcrBackend {
  Future<OcrResult> recognize(OcrRequest request);
}

import Flutter
import UIKit
import Vision

/// Manejador de capacidades de agente y visión OCR: com.nanoai/agent.
/// Implementa OCR local mediante Apple Vision y garantiza respuestas de tipo seguro.
internal final class NanoAgentHandler: NanoChannelHandler {
  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.nanoai/agent", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handle(call: call, result: result)
    }
  }

  func detach() {
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      // El sandbox de iOS aísla a Nano de la UI de terceros
      result([
        "enabled": false,
        "platform": "ios",
        "accessibilitySupported": false,
        "visionOcrSupported": true,
        "reason": "iOS sandbox restricts cross-app inspection. Local Vision OCR is available."
      ])

    case "dumpScreen", "findNodes":
      // IMPORTANTE: Devuelve lista vacía [Any] para coincidir con Dart invokeListMethod
      result([])

    case "dumpSnapshot":
      result([:])

    case "ocrRegion":
      handleOcr(call: call, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Ejecuta reconocimiento de texto sobre imagen mediante Apple Vision offline.
  /// Acepta ruta de archivo ('path') o datos binarios ('bytes') de la imagen.
  private func handleOcr(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    var cgImage: CGImage?

    if let path = args?["path"] as? String, let uiImage = UIImage(contentsOfFile: path) {
      cgImage = uiImage.cgImage
    } else if let data = (args?["bytes"] as? FlutterStandardTypedData)?.data, let uiImage = UIImage(data: data) {
      cgImage = uiImage.cgImage
    }

    guard let targetImage = cgImage else {
      result([])
      return
    }

    let request = VNRecognizeTextRequest { (request, error) in
      guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
        result([])
        return
      }

      let width = Double(targetImage.width)
      let height = Double(targetImage.height)

      let detected: [[String: Any]] = observations.compactMap { obs in
        guard let candidate = obs.topCandidates(1).first else { return nil }
        let box = obs.boundingBox
        // Conversión de coordenadas normalizadas de Vision (origen abajo-izq) a pixels
        let x = Int(box.origin.x * width)
        let y = Int((1.0 - box.origin.y - box.size.height) * height)
        let w = Int(box.size.width * width)
        let h = Int(box.size.height * height)

        return [
          "text": candidate.string,
          "confidence": candidate.confidence,
          "bounds": [x, y, x + w, y + h]
        ]
      }
      result(detected)
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    DispatchQueue.global(qos: .userInitiated).async {
      let handler = VNImageRequestHandler(cgImage: targetImage, options: [:])
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async { result([]) }
      }
    }
  }
}

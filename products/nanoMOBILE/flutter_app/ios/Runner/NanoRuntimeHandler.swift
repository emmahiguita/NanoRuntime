import Flutter
import UIKit

/// Manejador del canal de runtime: com.nanoai/runtime.
/// Responsable de reportar la versión del protocolo y capacidades reales de iOS.
internal final class NanoRuntimeHandler: NanoChannelHandler {
  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.nanoai/runtime", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handle(call: call, result: result)
    }
  }

  func detach() {
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  /// Procesa solicitudes de handshake y catálogo de capacidades.
  /// No declara capacidades ficticias ni simuladas; reporta la realidad del sandbox iOS.
  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getRuntimeVersion":
      // Coincide con NanoRuntimeApi.supportedRuntimeVersion = 1
      result(1)

    case "getCapabilities":
      // Capacidades factuales y reales soportadas en este host iOS
      result([
        "device-metrics",
        "device-permissions",
        "apple-vision-ocr",
        "speech-recognition",
        "speech-synthesis",
        "local-sqlite-store",
        "whatsapp-url-scheme"
      ])

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

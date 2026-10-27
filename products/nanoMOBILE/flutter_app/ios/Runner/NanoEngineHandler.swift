import Flutter
import UIKit

/// Manejador del ciclo de vida del motor de inferencia: com.nanoai/engine.
/// Reporta el estado operativo del motor en iOS y coordina paradas seguras.
internal final class NanoEngineHandler: NanoChannelHandler {
  private var channel: FlutterMethodChannel?
  private var isRunning = false

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.nanoai/engine", binaryMessenger: messenger)
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
    case "state":
      // Coincide con NanoRuntimeApi.engineState()
      result([
        "status": isRunning ? "running" : "ready",
        "backend": "web-cloud",
        "platform": "ios"
      ])

    case "health":
      result([
        "healthy": true,
        "platform": "ios",
        "memoryPressure": ProcessInfo.processInfo.thermalState == .critical
      ])

    case "start":
      isRunning = true
      result([
        "ok": true,
        "status": "running"
      ])

    case "stop":
      isRunning = false
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

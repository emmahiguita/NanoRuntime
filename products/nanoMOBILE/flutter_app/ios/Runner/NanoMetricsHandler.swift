import Flutter
import UIKit
import MachO

/// Manejador de telemetría y métricas de hardware: com.nanoai/device_metrics.
/// Obtiene datos reales del kernel Mach, subsistema de archivos y batería en iOS.
internal final class NanoMetricsHandler: NanoChannelHandler {
  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.nanoai/device_metrics", binaryMessenger: messenger)
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
    case "getMetrics":
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let metrics = self?.collectMetrics() ?? [:]
        DispatchQueue.main.async { result(metrics) }
      }

    case "getDeviceIdentity":
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let identity = self?.collectIdentity() ?? [:]
        DispatchQueue.main.async { result(identity) }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Recopila uso de memoria RAM, batería, almacenamiento y estado térmico.
  private func collectMetrics() -> [String: Any?] {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let batteryLevel = UIDevice.current.batteryLevel
    let batteryPct = batteryLevel >= 0 ? Double(batteryLevel * 100) : -1.0
    let isCharging = (UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full)

    let totalRamMb = Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0)

    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / 4)
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    let usedRamMb = (kerr == KERN_SUCCESS) ? Double(taskInfo.resident_size) / (1024.0 * 1024.0) : 0.0
    let ramAvailableMb = max(0.0, totalRamMb - usedRamMb)

    var storageTotalGb: Double = 0.0
    var storageFreeGb: Double = 0.0
    if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
      if let total = attrs[.systemSize] as? NSNumber {
        storageTotalGb = total.doubleValue / (1024.0 * 1024.0 * 1024.0)
      }
      if let free = attrs[.systemFreeSize] as? NSNumber {
        storageFreeGb = free.doubleValue / (1024.0 * 1024.0 * 1024.0)
      }
    }

    let thermalStateStr: String
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: thermalStateStr = "nominal"
    case .fair: thermalStateStr = "fair"
    case .serious: thermalStateStr = "serious"
    case .critical: thermalStateStr = "critical"
    @unknown default: thermalStateStr = "unknown"
    }

    return [
      "ramAvailableMb": ramAvailableMb,
      "ramTotalMb": totalRamMb,
      "batteryPct": batteryPct,
      "isCharging": isCharging,
      "storageTotalGb": storageTotalGb,
      "storageFreeGb": storageFreeGb,
      "cpuTempC": nil,
      "cpuCores": ProcessInfo.processInfo.activeProcessorCount,
      "thermalState": thermalStateStr
    ]
  }

  /// Recopila metadatos verificables del dispositivo iOS físico o simulador.
  private func collectIdentity() -> [String: Any?] {
    #if targetEnvironment(simulator)
    let isPhysical = false
    #else
    let isPhysical = true
    #endif

    return [
      "manufacturer": "Apple",
      "model": UIDevice.current.model,
      "productName": UIDevice.current.name,
      "osVersion": UIDevice.current.systemVersion,
      "deviceType": "ios",
      "isPhysicalDevice": isPhysical
    ]
  }
}

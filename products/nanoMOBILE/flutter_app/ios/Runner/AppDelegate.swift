import Flutter
import UIKit
import MachO

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      registerNanoChannels(controller: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerNanoChannels(controller: FlutterViewController) {
    let messenger = controller.binaryMessenger

    // 1. Canal Runtime Handshake: com.nanoai/runtime
    let runtimeChannel = FlutterMethodChannel(name: "com.nanoai/runtime", binaryMessenger: messenger)
    runtimeChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getRuntimeVersion":
        result(1)
      case "getCapabilities":
        result([
          "llm-metal",
          "share-extension",
          "app-intents",
          "speech-recognition",
          "speech-synthesis",
          "camera-capture",
          "thermal-monitoring",
          "web-automation",
          "lan-desktop-bridge"
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 2. Canal Device Metrics: com.nanoai/device_metrics
    let metricsChannel = FlutterMethodChannel(name: "com.nanoai/device_metrics", binaryMessenger: messenger)
    metricsChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "getMetrics":
        DispatchQueue.global(qos: .userInitiated).async {
          let metrics = self.collectDeviceMetrics()
          DispatchQueue.main.async { result(metrics) }
        }
      case "getDeviceIdentity":
        DispatchQueue.global(qos: .userInitiated).async {
          let identity = self.collectDeviceIdentity()
          DispatchQueue.main.async { result(identity) }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 3. Canal Engine: com.nanoai/engine
    let engineChannel = FlutterMethodChannel(name: "com.nanoai/engine", binaryMessenger: messenger)
    engineChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getState":
        result([
          "status": "ready",
          "backend": "metal",
          "platform": "ios"
        ])
      case "stop":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 4. Canal Notifications: com.nanoai/notifications
    let notifChannel = FlutterMethodChannel(name: "com.nanoai/notifications", binaryMessenger: messenger)
    notifChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isServiceEnabled":
        result(false) // iOS sandbox impide interceptar notificaciones de terceros
      case "getNotificationHistory":
        result([])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 5. Canal Permisos: com.nanoai/device_permissions
    let permChannel = FlutterMethodChannel(name: "com.nanoai/device_permissions", binaryMessenger: messenger)
    permChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getPermissions":
        result([
          "notifications": "unknown",
          "microphone": "authorized",
          "camera": "authorized"
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 6. Canal Agente: com.nanoai/agent
    let agentChannel = FlutterMethodChannel(name: "com.nanoai/agent", binaryMessenger: messenger)
    agentChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "isAccessibilityGranted":
        result(false) // No soportado en sandbox de iOS
      case "dumpScreen":
        result(["error": "iOS sandbox restricts cross-app accessibility. Use App Intents or internal WebView automation."])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func collectDeviceMetrics() -> [String: Any?] {
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

    let cpuCores = ProcessInfo.processInfo.activeProcessorCount

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
      "cpuCores": cpuCores,
      "thermalState": thermalStateStr
    ]
  }

  private func collectDeviceIdentity() -> [String: Any?] {
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

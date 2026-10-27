import Flutter
import UIKit
import UserNotifications

/// Manejador de notificaciones locales y restricciones en iOS: com.nanoai/notifications.
/// Gestiona notificaciones propias de Nano y declara la restricción del sandbox
/// que impide interceptar notificaciones de terceros (WhatsApp, etc.).
internal final class NanoNotificationsHandler: NanoChannelHandler {
  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.nanoai/notifications", binaryMessenger: messenger)
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
    case "getStatus", "isServiceEnabled":
      // El sandbox de Apple prohíbe interceptar notificaciones de otras apps
      result([
        "enabled": false,
        "platform": "ios",
        "thirdPartyNotificationAccess": false,
        "reason": "iOS sandbox blocks cross-app notification listeners."
      ])

    case "requestAccess":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }

    case "list", "getNotificationHistory":
      // Lista vacía tipada para evitar TypeErrors en Dart
      result([])

    case "cleanupInbox":
      result(0)

    case "reply":
      result([
        "ok": false,
        "error": "iOS sandbox prevents automated third-party notification replies."
      ])

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

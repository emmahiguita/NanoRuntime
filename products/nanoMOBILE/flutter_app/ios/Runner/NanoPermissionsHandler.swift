import Flutter
import UIKit
import AVFoundation
import Speech
import Photos

/// Manejador de permisos de hardware y privacidad: com.nanoai/device_permissions.
/// Gestiona consultas e invocaciones de permisos respetando las APIs de Apple.
internal final class NanoPermissionsHandler: NanoChannelHandler {
  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.nanoai/device_permissions", binaryMessenger: messenger)
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
    case "getAll":
      result(allPermissionsStatus())

    case "getPermission":
      let name = (call.arguments as? [String: Any])?["permission"] as? String ?? ""
      result(["permission": name, "status": checkPermission(name: name)])

    case "requestPermission":
      let name = (call.arguments as? [String: Any])?["permission"] as? String ?? ""
      requestPermission(name: name) { granted in
        result(granted)
      }

    case "openUrl":
      if let urlStr = (call.arguments as? [String: Any])?["url"] as? String,
         let url = URL(string: urlStr) {
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      } else {
        result(false)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func allPermissionsStatus() -> [String: String] {
    return [
      "microphone": checkPermission(name: "microphone"),
      "camera": checkPermission(name: "camera"),
      "speech": checkPermission(name: "speech"),
      "photos": checkPermission(name: "photos")
    ]
  }

  private func checkPermission(name: String) -> String {
    switch name.lowercased() {
    case "microphone":
      switch AVAudioSession.sharedInstance().recordPermission {
      case .granted: return "authorized"
      case .denied: return "denied"
      case .undetermined: return "not_determined"
      @unknown default: return "unknown"
      }

    case "camera":
      switch AVCaptureDevice.authorizationStatus(for: .video) {
      case .authorized: return "authorized"
      case .denied, .restricted: return "denied"
      case .notDetermined: return "not_determined"
      @unknown default: return "unknown"
      }

    case "speech":
      switch SFSpeechRecognizer.authorizationStatus() {
      case .authorized: return "authorized"
      case .denied, .restricted: return "denied"
      case .notDetermined: return "not_determined"
      @unknown default: return "unknown"
      }

    case "photos":
      if #available(iOS 14, *) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited: return "authorized"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "not_determined"
        @unknown default: return "unknown"
        }
      } else {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized: return "authorized"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "not_determined"
        @unknown default: return "unknown"
        }
      }

    default:
      return "unsupported"
    }
  }

  private func requestPermission(name: String, completion: @escaping (Bool) -> Void) {
    switch name.lowercased() {
    case "microphone":
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        DispatchQueue.main.async { completion(granted) }
      }
    case "camera":
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async { completion(granted) }
      }
    case "speech":
      SFSpeechRecognizer.requestAuthorization { status in
        DispatchQueue.main.async { completion(status == .authorized) }
      }
    case "photos":
      if #available(iOS 14, *) {
        PHPhotoLibrary.requestAuthorization { status in
          DispatchQueue.main.async { completion(status == .authorized || status == .limited) }
        }
      } else {
        PHPhotoLibrary.requestAuthorization { status in
          DispatchQueue.main.async { completion(status == .authorized) }
        }
      }
    default:
      completion(false)
    }
  }
}

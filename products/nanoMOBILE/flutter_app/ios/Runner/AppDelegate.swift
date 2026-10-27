import Flutter
import UIKit

/// AppDelegate principal de NanoAI en iOS.
/// Punto de entrada del ciclo de vida de la aplicación y registro de canales nativos.
@main
@objc class AppDelegate: FlutterAppDelegate {
  private let registrar = NanoChannelRegistrar()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      registrar.registerAll(with: controller)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    registrar.detachAll()
    super.applicationWillTerminate(application)
  }
}

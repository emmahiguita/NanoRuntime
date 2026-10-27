import Flutter
import UIKit

/// Protocolo base para cada manejador de canal nativo iOS.
/// Permite modularizar la responsabilidad de cada Platform Channel bajo SOLID.
internal protocol NanoChannelHandler: AnyObject {
  func register(with messenger: FlutterBinaryMessenger)
  func detach()
}

/// Coordinador central de registro de Platform Channels en iOS.
/// Conecta los handlers especializados desacoplados de AppDelegate.
internal final class NanoChannelRegistrar {
  private var handlers: [NanoChannelHandler] = []

  /// Registra todos los canales nativos de NanoAI para el engine de Flutter.
  func registerAll(with controller: FlutterViewController) {
    let messenger = controller.binaryMessenger

    handlers = [
      NanoRuntimeHandler(),
      NanoMetricsHandler(),
      NanoEngineHandler(),
      NanoPermissionsHandler(),
      NanoAgentHandler(),
      NanoNotificationsHandler(),
      NanoSpeechHandler(),
      NanoDataStudioHandler()
    ]

    for handler in handlers {
      handler.register(with: messenger)
    }
  }

  /// Libera referencias a canales cuando el ciclo de vida de la vista finaliza.
  func detachAll() {
    for handler in handlers {
      handler.detach()
    }
    handlers.removeAll()
  }
}

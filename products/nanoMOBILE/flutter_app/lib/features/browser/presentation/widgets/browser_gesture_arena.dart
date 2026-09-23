import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Gestor de Arena de Reconocimiento de Gestos para el Navegador Web de Nano AI.
/// 
/// - ¿Qué hace?: Determina la prioridad de captura de toques y gestos entre la textura
///   nativa del [InAppWebView] y el layout deslizante de ventanas múltiples en Flutter.
/// - ¿Cómo funciona?: Cuando [isInteractive] o [isMaximized] es verdadero, otorga
///   [EagerGestureRecognizer] al WebView para permitir interactuar con la página web
///   (hacer scroll interno, reproducir videos, pulsar botones). Cuando está en modo
///   navegación de ventanas ([isInteractive] falso), retorna un conjunto vacío de gestos,
///   permitiendo que los toques y arrastres verticales pasen limpiamente al [ListView]
///   o [ScrollController] del layout general para bajar entre ventanas sin atascos.
/// - ¿Por qué?: Resuelve el conflicto donde páginas pesadas como YouTube secuestran
///   incondicionalmente el puntero táctil, impidiendo al usuario deslizar el layout
///   para ver y operar sus demás pestañas. Cumple SOLID (Principio de Responsabilidad Única)
///   y garantiza un código modular menor a 200 líneas.
class BrowserGestureArena {
  const BrowserGestureArena._();

  /// Genera la fábrica de reconocedores de gestos según el estado de la ventana.
  /// 
  /// - [isMaximized]: Si la ventana ocupa toda la pantalla, la interacción web es prioritaria.
  /// - [isInteractive]: Si el usuario activó explícitamente el modo de interacción web
  ///   en la tarjeta dentro de la lista apilada.
  /// - [forcePassThrough]: Si se requiere forzar el paso de gestos al contenedor padre.
  static Set<Factory<OneSequenceGestureRecognizer>> buildGestureRecognizers({
    required bool isMaximized,
    required bool isInteractive,
    bool forcePassThrough = false,
  }) {
    // Si se fuerza el paso al layout o la ventana no está en modo interactivo ni maximizada,
    // retornamos conjunto vacío para que el ListView de Flutter capture el desplazamiento vertical.
    if (forcePassThrough || (!isMaximized && !isInteractive)) {
      return const <Factory<OneSequenceGestureRecognizer>>{};
    }

    // En modo interactivo o maximizado, el WebView reclama los gestos de puntero y de pellizco multitáctil.
    return <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
    };
  }
}

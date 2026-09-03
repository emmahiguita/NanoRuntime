/// EDGE-01 — Estado del overlay del búho (puro, sin plataforma).
///
/// El overlay nativo solo dibuja [NanoEdgeContent]: texto ya resuelto por
/// Dart. Nada en este archivo toca MethodChannel, árbol de accesibilidad ni
/// gestos.
library;

import 'system_context_provider.dart';

/// Contenido textual que el overlay muestra. Llega fusionado por los paneles
/// de contexto (EDGE-03); el overlay nunca deriva contenido por sí mismo.
final class NanoEdgeContent {
  const NanoEdgeContent({required this.title, required this.body});

  final String title;
  final String body;
}

/// Modo visual del overlay.
enum NanoEdgeMode {
  /// Sin ventana en pantalla.
  hidden,

  /// Búho colapsado sobre la app en foreground.
  bubble,

  /// Panel expandido con [NanoEdgeContent].
  panel,
}

/// Eventos del overlay hacia Dart (EventChannel edge_events).
sealed class NanoEdgeEvent {
  const NanoEdgeEvent();
}

/// El usuario tocó el búho colapsado: el consumidor decide qué contenido
/// mostrar (típicamente el SystemContextSnapshot vigente).
final class NanoEdgeBubbleTapped extends NanoEdgeEvent {
  const NanoEdgeBubbleTapped();
}

/// El usuario cerró el panel: el overlay volvió a burbuja.
final class NanoEdgePanelDismissed extends NanoEdgeEvent {
  const NanoEdgePanelDismissed();
}

/// Parsea un evento crudo del EventChannel. Desconocido → null (el canal
/// nunca debe romper al consumidor).
NanoEdgeEvent? nanoEdgeEventFromMap(Map<dynamic, dynamic> map) =>
    switch (map['event']) {
      'bubbleTapped' => const NanoEdgeBubbleTapped(),
      'panelDismissed' => const NanoEdgePanelDismissed(),
      _ => null,
    };

/// Estado completo del overlay: modo visual + contexto resuelto aguas arriba
/// (EDGE-02/EDGE-03). El overlay nativo solo dibuja lo que aquí llega; los
/// paneles lo CONSUMEN para producir [NanoEdgeContent].
final class NanoEdgeState {
  const NanoEdgeState({
    this.mode = NanoEdgeMode.hidden,
    this.snapshot,
    this.conversationContact,
  });

  final NanoEdgeMode mode;

  /// Snapshot de contexto del sistema vigente (null = aún sin observar).
  final SystemContextSnapshot? snapshot;

  /// Contacto/conversación inferida para la app en foreground (si aplica).
  final String? conversationContact;
}

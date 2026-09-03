/// EDGE-01/02/03 — NanoEdgeCoordinator: el glue del búho.
///
/// Cadena (solo lectura, cero ejecución):
///   tap del búho (EventChannel)
///     → SystemContextProvider.current()  (fusión de fuentes existentes)
///     → ContextPanelRegistry.resolve(foreground)
///     → ContextPanel.contentFor(...)     (puro)
///     → NanoEdgeController.showPanel     (overlay nativo dibuja)
///
/// Este coordinator NO ejecuta acciones de automatización: el overlay v1
/// es contexto, no un camino de ejecución (los caminos reales siguen siendo
/// los del AutomationCoordinator).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/nano_runtime_api_provider.dart';

import 'assistant_role.dart';
import 'nano_edge_controller.dart';
import 'nano_edge_state.dart';
import 'panels/context_panel_registry.dart';
import 'system_context_provider.dart';

final class NanoEdgeCoordinator {
  NanoEdgeCoordinator({
    required NanoEdgeController controller,
    required SystemContextProvider context,
    this.panels = defaultContextPanelRegistry,
  }) : _controller = controller,
       _context = context;

  final NanoEdgeController _controller;
  final SystemContextProvider _context;
  final ContextPanelRegistry panels;

  StreamSubscription<NanoEdgeEvent>? _subscription;

  /// Escucha los eventos del overlay (de por vida). Idempotente.
  void start() {
    _subscription ??= _controller.events.listen(_onEvent);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onEvent(NanoEdgeEvent event) async {
    switch (event) {
      case NanoEdgeBubbleTapped():
        final snapshot = await _context.current();
        final panel = panels.resolve(snapshot.foregroundPackage);
        final content = panel.contentFor(
          NanoEdgeState(mode: NanoEdgeMode.panel, snapshot: snapshot),
        );
        await _controller.showPanel(content);
      case NanoEdgePanelDismissed():
        break; // el overlay nativo ya volvió a burbuja por su cuenta
    }
  }
}

/// Instancia única del coordinator del búho. Arranca al leerse por primera
/// vez (escucha de por vida, igual que notificationEventRouterProvider).
final nanoEdgeCoordinatorProvider = Provider<NanoEdgeCoordinator>((ref) {
  final coordinator = NanoEdgeCoordinator(
    controller: ref.watch(nanoEdgeControllerProvider),
    context: ref.watch(systemContextProvider),
  )..start();
  ref.onDispose(coordinator.stop);
  return coordinator;
});

/// Provider del SystemContextProvider (EDGE-02): fusión read-only sobre
/// NanoRuntimeApi + la sesión de asistencia (ROLE-01).
final systemContextProvider = Provider<SystemContextProvider>(
  (ref) => RuntimeSystemContextProvider(
    api: ref.watch(nanoRuntimeApiProvider),
    assistantRole: ref.watch(assistantRoleManagerProvider),
  ),
);

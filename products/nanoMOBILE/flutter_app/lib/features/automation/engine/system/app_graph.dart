/// AppGraph foundation (A2) — identidad/capacidad factual de una app instalada.
///
/// SOLO capacidades realmente descubiertas, con proveniencia. NO infiere
/// "WhatsApp instalado → puede responder" (eso vendrá de discovery de
/// notificaciones/UI, en fases posteriores).
library;

import 'system_models.dart';

/// Capacidades factuales de una app. Mínimo viable en A2.
enum AppCapability { launch, systemApp }

/// Proveniencia de una capacidad: de dónde salió la afirmación.
class AppCapabilityEvidence {
  final AppCapability capability;
  final String source;
  const AppCapabilityEvidence(this.capability, this.source);
}

/// Nodo del AppGraph: una app instalada + sus capacidades con evidencia.
class AppGraphNode {
  final InstalledApp app;
  final Set<AppCapability> capabilities;
  final Map<AppCapability, AppCapabilityEvidence> evidence;

  const AppGraphNode({
    required this.app,
    required this.capabilities,
    required this.evidence,
  });

  /// Nodo derivado de una app launcher descubierta por el PackageManager.
  factory AppGraphNode.fromInstalledApp(InstalledApp app) {
    final caps = <AppCapability>{
      if (app.launchable) AppCapability.launch,
      if (app.system) AppCapability.systemApp,
    };
    final evidence = <AppCapability, AppCapabilityEvidence>{
      if (app.launchable)
        AppCapability.launch: const AppCapabilityEvidence(
          AppCapability.launch,
          'launcherIntent',
        ),
      if (app.system)
        AppCapability.systemApp: const AppCapabilityEvidence(
          AppCapability.systemApp,
          'applicationInfoFlags',
        ),
    };
    return AppGraphNode(app: app, capabilities: caps, evidence: evidence);
  }
}

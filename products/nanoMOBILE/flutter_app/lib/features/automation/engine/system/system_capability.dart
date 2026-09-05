/// SystemCapability (A3) — taxonomía tipada de capacidades del dispositivo.
///
/// Una capability responde "¿el mecanismo PUEDE existir/usarse?" — NO responde
/// "¿Nano tiene autorización?" (eso es Policy/IntentFirewall, fases posteriores).
/// Capability != Authority.
///
/// Las capabilities marcadas con "futura" NO tienen backend en A3 y se reportan
/// `unsupported` (nunca `available`) hasta que exista evidencia real.
library;

/// Capacidades factuales del sistema. Mínimo útil para el modelo A3.
enum SystemCapability {
  // ── Inventario (A2) ──
  readDeviceProfile,
  listLaunchableApps,
  launchApps,

  // ── Device actions (A1) — requieren Accessibility ──
  globalBack,
  globalHome,
  globalRecents,
  openNotifications,
  openQuickSettings,

  // ── Notificaciones ──
  readNotifications,
  replyNotifications,

  // ── Accesibilidad ──
  observeAccessibility,
  interactAccessibility,

  // ── Destinos de sistema (A3, allowlist no-duplicada) ──
  openSystemSettings,
  openWifiSettings,
  openBluetoothSettings,

  // ── Linux ──
  linuxExecution,

  // ── Futuras (sin backend de ejecución; nunca `available`) ──
  // DEVICE-PROFILE-01: shizuku movida a implementada (A14.3 ShizukuCapabilityProbe
  // + A14.4 PackageActionService). Su availability la reporta SOLO ese probe.
  mediaProjection,
  developerAdb,
  shizuku,
  deviceOwner,
  root,
}

/// Proveniencia de una afirmación factual. NUNCA usar LLM/OCR/Vision/texto de
/// pantalla como evidencia autoritativa de capability (eso es observacional).
enum SystemEvidenceSource {
  packageManager,
  deviceBuild,
  accessibilityService,
  notificationListener,
  androidSdk,
  manifest,
  runtimeChannel,
  linuxRuntime,
  explicitConfiguration,
}

/// Evidencia de una afirmación factual (source + clave).
class SystemEvidence {
  final SystemEvidenceSource source;
  final String key;
  const SystemEvidence(this.source, this.key);
}

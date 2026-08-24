/// Preflight del benchmark C14-A.
///
/// Antes de ejecutar 10-20 tareas, verifica que TODA la pila esté viva. Si
/// falta una dependencia (p. ej. el modelo GGUF no está cargado), aborta con
/// un [PreflightCode] en vez de producir diez tests rojos que parecen errores
/// del agente. La lógica es pura (recibe booleans) → testeable sin device; el
/// cableado a providers vive en `c14_runner.dart`.
library;

/// Código de la PRIMERA dependencia que falta (bloquea el run).
enum PreflightCode {
  runtimeDead,
  modelNotLoaded,
  accessibilityOff,
  coordinatorNotReady,
  policyNotConfigured,
  deviceLocked,
  screenNotInteractive,
}

class PreflightCheck {
  final String name;
  final bool ok;
  final String detail;
  const PreflightCheck({
    required this.name,
    required this.ok,
    required this.detail,
  });
}

class C14PreflightResult {
  final bool pass;
  final List<PreflightCheck> checks;

  /// Código de la dependencia que falta (null si [pass]). El runner/UI lo
  /// muestra y aborta antes de ejecutar.
  final PreflightCode? failCode;

  const C14PreflightResult({
    required this.pass,
    required this.checks,
    this.failCode,
  });
}

class C14Preflight {
  const C14Preflight();

  Future<C14PreflightResult> run({
    required bool runtimeAlive,
    required bool modelLoaded,
    required bool accessibilityEnabled,
    required bool coordinatorReady,
    required bool policyConfigured,
    required bool deviceUnlocked,
    required bool screenInteractive,
  }) async {
    final checks = <PreflightCheck>[
      PreflightCheck(
        name: 'Runtime vivo',
        ok: runtimeAlive,
        detail: runtimeAlive
            ? 'engine /health OK'
            : 'engine muerto o no respondió',
      ),
      PreflightCheck(
        name: 'Modelo cargado',
        ok: modelLoaded,
        detail: modelLoaded
            ? 'GGUF cargado'
            : 'sin modelo (degraded / no GGUF)',
      ),
      PreflightCheck(
        name: 'Accesibilidad activa',
        ok: accessibilityEnabled,
        detail: accessibilityEnabled
            ? 'servicio activo'
            : 'sin árbol semántico',
      ),
      PreflightCheck(
        name: 'Coordinator listo',
        ok: coordinatorReady,
        detail: coordinatorReady ? 'DI resuelta' : 'no se pudo construir',
      ),
      PreflightCheck(
        name: 'Política configurada',
        ok: policyConfigured,
        detail: policyConfigured ? 'nivel de autonomía' : 'sin modo',
      ),
      PreflightCheck(
        name: 'Device desbloqueado',
        ok: deviceUnlocked,
        detail: deviceUnlocked ? 'keyguard off' : 'pantalla bloqueada',
      ),
      PreflightCheck(
        name: 'Pantalla interactiva',
        ok: screenInteractive,
        detail: screenInteractive ? 'interactive/awake' : 'no interactiva',
      ),
    ];

    final failIndex = checks.indexWhere((c) => !c.ok);
    return C14PreflightResult(
      pass: failIndex == -1,
      checks: checks,
      failCode: failIndex == -1 ? null : _codeFor(checks[failIndex].name),
    );
  }

  static PreflightCode _codeFor(String name) => switch (name) {
    'Runtime vivo' => PreflightCode.runtimeDead,
    'Modelo cargado' => PreflightCode.modelNotLoaded,
    'Accesibilidad activa' => PreflightCode.accessibilityOff,
    'Coordinator listo' => PreflightCode.coordinatorNotReady,
    'Política configurada' => PreflightCode.policyNotConfigured,
    'Device desbloqueado' => PreflightCode.deviceLocked,
    _ => PreflightCode.screenNotInteractive,
  };
}

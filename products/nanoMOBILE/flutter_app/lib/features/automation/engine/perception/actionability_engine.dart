/// Actionability Engine — verificación del estado de un nodo antes de actuar.
///
/// Filosofía Playwright: antes de cada acción se comprueba que el objetivo
/// existe, es único, visible, habilitado, estable, puede recibir la acción y
/// pertenece a la app esperada. Un fallo en cualquiera de los checks aborta
/// con motivo legible — nunca un gesto a ciegas.
///
/// Motor puro: sin MethodChannel — testeable con fixtures.
library;

import 'nano_snapshot.dart';

/// Tipo de acción que se quiere ejecutar sobre el nodo.
enum ActionKind { tap, input }

/// Estado de actionability de un nodo para una acción concreta.
class ActionabilityState {
  final bool exists;

  /// Único: el resolve no era ambiguo (gap ≥ umbral). Lo decide el
  /// Selector Engine; aquí se recibe.
  final bool unique;
  final bool visible;
  final bool enabled;

  /// Estable: re-resolución con bounds dentro de delta (StabilityChecker).
  final bool stable;

  /// tap → clickable; input → editable y con foco.
  final bool receivesAction;

  /// snapshot.package coincide con el package esperado del selector.
  final bool expectedPackage;

  /// Primer motivo de fallo, en español (null si todo ok).
  final String? failureReason;

  const ActionabilityState({
    required this.exists,
    required this.unique,
    required this.visible,
    required this.enabled,
    required this.stable,
    required this.receivesAction,
    required this.expectedPackage,
    this.failureReason,
  });

  /// AND de todo: solo true cuando la acción es segura.
  bool get actionable =>
      exists &&
      unique &&
      visible &&
      enabled &&
      stable &&
      receivesAction &&
      expectedPackage;

  /// Checks estáticos sobre el nodo ya resuelto. [unique] viene del
  /// Selector Engine; [stable] se verifica aparte con [StabilityChecker]
  /// (este check inicial lo asume true — el executor lo completa).
  static ActionabilityState check({
    required ActionKind kind,
    required NanoNode node,
    required bool unique,
    required String snapshotPackage,
    String? expectedPackage,
  }) {
    final exists = node.bounds.width > 0 && node.bounds.height > 0;
    final visible = node.visible;
    final enabled = node.enabled;
    final expectedPackageOk =
        expectedPackage == null ||
        expectedPackage.isEmpty ||
        expectedPackage == snapshotPackage;
    final receivesAction = switch (kind) {
      ActionKind.tap => node.clickable,
      ActionKind.input => node.editable && node.focused,
    };

    String? reason;
    if (!exists) {
      reason = 'Nodo sin bounds válidos.';
    } else if (!unique) {
      reason = 'Objetivo ambiguo: el selector resolvió con empate.';
    } else if (!visible) {
      reason = 'Nodo no visible.';
    } else if (!enabled) {
      reason = 'Nodo deshabilitado.';
    } else if (!expectedPackageOk) {
      reason =
          'Package inesperado: se esperaba "$expectedPackage", '
          'actual "$snapshotPackage".';
    } else if (!receivesAction) {
      reason = switch (kind) {
        ActionKind.tap => 'Nodo no clickable para tap.',
        ActionKind.input =>
          'Nodo no editable o sin foco para input (hace falta tap de foco).',
      };
    }

    return ActionabilityState(
      exists: exists,
      unique: unique,
      visible: visible,
      enabled: enabled,
      stable: true, // se re-verifica con StabilityChecker en el executor
      receivesAction: receivesAction,
      expectedPackage: expectedPackageOk,
      failureReason: reason,
    );
  }
}

/// Verificación de estabilidad: re-resolver el selector sobre un snapshot
/// fresco y comparar bounds con el original. Estable si el centro no se movió
/// más de [maxCenterDeltaPx] y el tamaño no varió más de [maxSizeChangeRatio].
///
/// No asume índices estables entre dumps: la re-resolución pasa por el
/// Selector Engine de nuevo.
class StabilityChecker {
  /// ~1% del alto de pantalla en 1080×2400, por debajo del touch slop.
  final int maxCenterDeltaPx;

  /// Tamaño del nodo estable dentro de ±10%.
  final double maxSizeChangeRatio;

  /// Espera entre snapshot y re-snapshot (settle UI + rebind ColorOS).
  final Duration wait;

  const StabilityChecker({
    this.maxCenterDeltaPx = 24,
    this.maxSizeChangeRatio = 0.10,
    this.wait = const Duration(milliseconds: 300),
  });

  /// true si [reResolved] (mismo nodo re-resuelto) sigue en la misma
  /// posición/tamaño que [original]. false si el re-resolve falló (null) o
  /// los bounds se movieron más allá de los umbrales.
  bool isStable({required NanoNode original, required NanoNode? reResolved}) {
    if (reResolved == null) return false;
    final dx = (reResolved.bounds.centerX - original.bounds.centerX).abs();
    final dy = (reResolved.bounds.centerY - original.bounds.centerY).abs();
    if (dx > maxCenterDeltaPx || dy > maxCenterDeltaPx) return false;

    final w = original.bounds.width;
    final h = original.bounds.height;
    if (w <= 0 || h <= 0) return false;
    final wRatio = (reResolved.bounds.width - w).abs() / w;
    final hRatio = (reResolved.bounds.height - h).abs() / h;
    return wRatio <= maxSizeChangeRatio && hRatio <= maxSizeChangeRatio;
  }
}

/// ActionVerifier — verificación de POSTCONDICIONES tras cada acción.
///
/// El ejecutor es fuerte verificando ANTES de actuar (resolve → actionability
/// → settle → re-resolve). Este módulo cierra la otra mitad del ciclo:
/// después del gesto, el éxito NO se infiere del `true` de dispatchGesture —
/// se toma un snapshot fresco y se comprueba el estado esperado:
///
///   action → wait settle → new snapshot → verify expected state
///
/// Flujo: [ActionVerifier.verify] sondea con [ActionExpectation.pollInterval]
/// hasta [ActionExpectation.timeout]. Restricciones duras (forbiddenText,
/// wrongPackage) fallan inmediatamente; condiciones pendientes al vencer el
/// plazo devuelven [VerificationStatus.timeout].
///
/// Puro: la fuente de snapshots se inyecta ([snapshotFn]) — testeable con
/// fixtures sin MethodChannel.
library;

import '../perception/nano_selector.dart';
import '../perception/nano_snapshot.dart';
import '../perception/selector_engine.dart';

/// Postcondiciones de una acción. Todas opcionales: la ausencia de criterios
/// es una expectativa trivialmente verificada (compat con acciones de solo
/// lectura sin estado esperado conocido).
class ActionExpectation {
  /// Package que debe estar en primer plano tras la acción (ej.
  /// `com.android.settings` tras launch_app).
  final String? expectedPackage;

  /// Selector que debe resolver tras la acción (ej. `text=Bluetooth` tras
  /// navegar a la pantalla Bluetooth).
  final NanoSelector? mustAppear;

  /// Selector que NO debe resolver tras la acción (ej. el diálogo que se
  /// cerró).
  final NanoSelector? mustDisappear;

  /// Texto que debe ser visible en algún nodo (contains, case-insensitive).
  final String? expectedText;

  /// Texto que NO debe ser visible; si aparece, fallo inmediato.
  final String? forbiddenText;

  /// Exige que el snapshot cambió respecto al previo a la acción (firma de
  /// nodos visibles: labels + bounds). Requiere pasar [ActionVerifier.verify]
  /// el `preSnapshot`.
  final bool mustChangeSnapshot;

  /// Plazo máximo total de verificación.
  final Duration timeout;

  /// Intervalo entre sondeos dentro del plazo.
  final Duration pollInterval;

  const ActionExpectation({
    this.expectedPackage,
    this.mustAppear,
    this.mustDisappear,
    this.expectedText,
    this.forbiddenText,
    this.mustChangeSnapshot = false,
    this.timeout = const Duration(seconds: 4),
    this.pollInterval = const Duration(milliseconds: 300),
  });

  /// Copia con overrides (para construir expectativas a partir de un
  /// timeout base común).
  ActionExpectation copyWith({
    String? expectedPackage,
    NanoSelector? mustAppear,
    NanoSelector? mustDisappear,
    String? expectedText,
    String? forbiddenText,
    bool? mustChangeSnapshot,
    Duration? timeout,
    Duration? pollInterval,
  }) {
    return ActionExpectation(
      expectedPackage: expectedPackage ?? this.expectedPackage,
      mustAppear: mustAppear ?? this.mustAppear,
      mustDisappear: mustDisappear ?? this.mustDisappear,
      expectedText: expectedText ?? this.expectedText,
      forbiddenText: forbiddenText ?? this.forbiddenText,
      mustChangeSnapshot: mustChangeSnapshot ?? this.mustChangeSnapshot,
      timeout: timeout ?? this.timeout,
      pollInterval: pollInterval ?? this.pollInterval,
    );
  }

  /// True si hay al menos una postcondición que comprobar.
  bool get hasCriteria =>
      (expectedPackage != null && expectedPackage!.isNotEmpty) ||
      mustAppear != null ||
      mustDisappear != null ||
      (expectedText != null && expectedText!.isNotEmpty) ||
      (forbiddenText != null && forbiddenText!.isNotEmpty) ||
      mustChangeSnapshot;

  /// Descripción legible para traces y feedback.
  String toDebugString() {
    final parts = <String>[
      if (expectedPackage != null) 'pkg=$expectedPackage',
      if (mustAppear != null) 'mustAppear=${mustAppear!.toDebugString()}',
      if (mustDisappear != null)
        'mustDisappear=${mustDisappear!.toDebugString()}',
      if (expectedText != null) 'text~=$expectedText',
      if (forbiddenText != null) 'forbidden~=$forbiddenText',
      if (mustChangeSnapshot) 'mustChangeSnapshot',
    ];
    return parts.join(', ');
  }
}

/// Estado terminal de una verificación.
enum VerificationStatus {
  /// Todas las postcondiciones se cumplen.
  verified,

  /// Una postcondición se evaluó y es falsa (ej. forbiddenText visible,
  /// package distinto del esperado en el sondeo final).
  notVerified,

  /// Plazo agotado con condiciones pendientes (pantalla lenta, animación
  /// larga). Ambiguo por naturaleza: NO asumir éxito.
  timeout,

  /// El package en primer plano no es el esperado.
  wrongPackage,

  /// El canal de accesibilidad no responde (servicio off o rebind).
  serviceUnavailable,
}

/// Resultado de [ActionVerifier.verify] con evidencia.
class VerificationOutcome {
  final VerificationStatus status;

  /// Motivo legible en español (qué condición falló o quedó pendiente).
  final String reason;

  /// Snapshot final como evidencia (null si el canal murió).
  final NanoSnapshot? snapshot;

  const VerificationOutcome({
    required this.status,
    required this.reason,
    this.snapshot,
  });

  bool get isVerified => status == VerificationStatus.verified;

  @override
  String toString() => 'VerificationOutcome(${status.name}: $reason)';
}

/// Contrato mínimo del verificador de postcondiciones (DIP): lo que
/// [AgentLoop] necesita. [ActionVerifier] lo implementa.
abstract interface class AgentVerifier {
  Future<VerificationOutcome> verify(
    ActionExpectation expectation, {
    NanoSnapshot? preSnapshot,
  });
}

/// Verificador de postcondiciones. Sondea snapshots hasta satisfacer la
/// expectativa o vencer el plazo.
class ActionVerifier implements AgentVerifier {
  ActionVerifier({
    required Future<NanoSnapshot?> Function() snapshotFn,
    NanoSelectorEngine? engine,
  }) : _snapshotFn = snapshotFn,
       _engine = engine ?? NanoSelectorEngine();

  final Future<NanoSnapshot?> Function() _snapshotFn;
  final NanoSelectorEngine _engine;

  /// Verifica [expectation]. [preSnapshot] solo se usa para
  /// [ActionExpectation.mustChangeSnapshot].
  @override
  Future<VerificationOutcome> verify(
    ActionExpectation expectation, {
    NanoSnapshot? preSnapshot,
  }) async {
    if (!expectation.hasCriteria) {
      return const VerificationOutcome(
        status: VerificationStatus.verified,
        reason: 'Sin postcondiciones declaradas.',
      );
    }

    final deadline = DateTime.now().add(expectation.timeout);
    NanoSnapshot? lastSnap;
    String pending = '';

    while (true) {
      lastSnap = await _snapshotFn();

      // Canal muerto: sin sondeos ciegos — falla tipado inmediato.
      if (lastSnap == null) {
        return const VerificationOutcome(
          status: VerificationStatus.serviceUnavailable,
          reason: 'Canal de accesibilidad sin respuesta tras la acción.',
        );
      }

      if (!lastSnap.isEmpty) {
        final outcome = _checkOnce(expectation, lastSnap, preSnapshot);
        if (outcome != null) return outcome;
        pending = _pendingList(expectation, lastSnap, preSnapshot).join('; ');
      } else {
        pending = 'Snapshot vacío: sin ventana activa (rebind en curso).';
      }

      if (DateTime.now().isAfter(deadline)) {
        return VerificationOutcome(
          status: VerificationStatus.timeout,
          reason:
              'Plazo de ${expectation.timeout.inMilliseconds}ms agotado — '
              'pendiente: $pending',
          snapshot: lastSnap,
        );
      }
      await Future<void>.delayed(expectation.pollInterval);
    }
  }

  /// Evalúa todas las condiciones contra [snap]. null = todo pendiente o
  /// cumplido-hasta-ahora (seguir sondeando); non-null = veredicto terminal.
  VerificationOutcome? _checkOnce(
    ActionExpectation e,
    NanoSnapshot snap,
    NanoSnapshot? pre,
  ) {
    // Restricciones duras: fallo inmediato, sin reintentos.
    if (e.forbiddenText != null && e.forbiddenText!.isNotEmpty) {
      if (_containsVisibleText(snap, e.forbiddenText!)) {
        return VerificationOutcome(
          status: VerificationStatus.notVerified,
          reason:
              'Texto prohibido "${e.forbiddenText}" visible tras la '
              'acción.',
          snapshot: snap,
        );
      }
    }

    if (e.expectedPackage != null && e.expectedPackage!.isNotEmpty) {
      final pkg = snap.package;
      // Ventanas OEM pueden no exponer package (""): no confirma ni refuta
      // — se sigue sondeando; solo un package distinto y no vacío refuta.
      if (pkg.isNotEmpty && pkg != e.expectedPackage) {
        return VerificationOutcome(
          status: VerificationStatus.wrongPackage,
          reason:
              'Package esperado "${e.expectedPackage}", en primer plano '
              '"$pkg".',
          snapshot: snap,
        );
      }
    }

    // Condiciones de espera: si TODAS las evaluables se cumplen → verified.
    final pending = _pendingList(e, snap, pre);

    if (e.expectedPackage != null &&
        e.expectedPackage!.isNotEmpty &&
        snap.package.isEmpty) {
      pending.add('package no expuesto por la ventana');
    }
    if (e.mustAppear != null &&
        !_engine.resolve(e.mustAppear!, snap).isResolved) {
      pending.add('mustAppear=${e.mustAppear!.toDebugString()} sin resolver');
    }
    if (e.mustDisappear != null &&
        _engine.resolve(e.mustDisappear!, snap).isResolved) {
      pending.add(
        'mustDisappear=${e.mustDisappear!.toDebugString()} '
        'sigue presente',
      );
    }
    if (e.expectedText != null &&
        e.expectedText!.isNotEmpty &&
        !_containsVisibleText(snap, e.expectedText!)) {
      pending.add('texto "${e.expectedText}" no visible');
    }
    if (e.mustChangeSnapshot && pre != null) {
      if (_signature(snap) == _signature(pre)) {
        pending.add('el snapshot no cambió respecto al previo');
      }
    } else if (e.mustChangeSnapshot && pre == null) {
      // Sin preSnapshot no se puede evaluar el cambio: se declara no
      // verificable en vez de asumir el cambio.
      return VerificationOutcome(
        status: VerificationStatus.notVerified,
        reason: 'mustChangeSnapshot requiere preSnapshot y no se aportó.',
        snapshot: snap,
      );
    }

    if (pending.isEmpty) {
      return VerificationOutcome(
        status: VerificationStatus.verified,
        reason: 'Postcondiciones cumplidas: ${e.toDebugString()}',
        snapshot: snap,
      );
    }
    return null;
  }

  /// Motivo de lo que quedó pendiente en el último sondeo (para el timeout).
  List<String> _pendingList(
    ActionExpectation e,
    NanoSnapshot snap,
    NanoSnapshot? pre,
  ) {
    if (snap.isEmpty) return const ['snapshot vacío (sin ventana activa)'];
    return <String>[
      if (e.expectedPackage != null &&
          e.expectedPackage!.isNotEmpty &&
          snap.package.isEmpty)
        'package no expuesto por la ventana',
      if (e.mustAppear != null &&
          !_engine.resolve(e.mustAppear!, snap).isResolved)
        'mustAppear=${e.mustAppear!.toDebugString()} sin resolver',
      if (e.mustDisappear != null &&
          _engine.resolve(e.mustDisappear!, snap).isResolved)
        'mustDisappear=${e.mustDisappear!.toDebugString()} sigue presente',
      if (e.expectedText != null &&
          e.expectedText!.isNotEmpty &&
          !_containsVisibleText(snap, e.expectedText!))
        'texto "${e.expectedText}" no visible',
      if (e.mustChangeSnapshot &&
          pre != null &&
          _signature(snap) == _signature(pre))
        'el snapshot no cambió respecto al previo',
    ];
  }

  /// contains case-insensitive sobre texto/descripción de nodos visibles.
  bool _containsVisibleText(NanoSnapshot snap, String needle) {
    final n = needle.toLowerCase();
    for (final node in snap.visibleNodes) {
      if (node.text.toLowerCase().contains(n) ||
          node.description.toLowerCase().contains(n)) {
        return true;
      }
    }
    return false;
  }

  /// Firma de contenido visible: detecta cambios de pantalla (set de labels
  /// + bounds). Dos snapshots con la misma firma se consideran iguales.
  String _signature(NanoSnapshot snap) {
    final parts = snap.visibleNodes
        .map((n) => '${n.label}@${n.bounds}')
        .join('|');
    return '${snap.package}#$parts';
  }
}

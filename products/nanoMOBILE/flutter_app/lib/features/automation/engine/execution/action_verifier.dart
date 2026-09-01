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
/// hasta [ActionExpectation.timeout]. `forbiddenText` falla inmediatamente;
/// una transición de package se observa hasta estabilizarse, pues Android puede
/// exponer por unos instantes la aplicación anterior o el launcher.
///
/// Puro: la fuente de snapshots se inyecta ([snapshotFn]) — testeable con
/// fixtures sin MethodChannel.
library;

import '../perception/nano_selector.dart';
import '../perception/nano_snapshot.dart';
import '../perception/selector_engine.dart';
import 'platform_verification.dart';

enum ExpectedTextMatch { contains, exact }

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

  /// Texto que debe ser visible (contains, case-insensitive). Cuando
  /// [expectedTextTarget] está definido se busca exclusivamente en ese nodo
  /// re-resuelto, no en el historial ni en otro control de la pantalla.
  final String? expectedText;

  /// Selector estable del control que debe contener [expectedText].
  final NanoSelector? expectedTextTarget;

  /// `setText` exige igualdad completa; otros consumidores conservan contains
  /// para postcondiciones de contenido visible no editable.
  final ExpectedTextMatch expectedTextMatch;

  /// Texto que NO debe ser visible; si aparece, fallo inmediato.
  final String? forbiddenText;

  /// Exige que el snapshot cambió respecto al previo a la acción (firma de
  /// nodos visibles: labels + bounds). Requiere pasar [ActionVerifier.verify]
  /// el `preSnapshot`.
  final bool mustChangeSnapshot;

  /// Postcondiciones de PLATAFORMA (A14.5): hechos verificados contra el estado
  /// real del sistema (app en primer plano, archivo existe, proceso ausente),
  /// no contra el "OK" del backend. Vacío = legacy UI-only (compat).
  final List<PlatformPredicate> platformPredicates;

  /// Plazo máximo total de verificación.
  final Duration timeout;

  /// Intervalo entre sondeos dentro del plazo.
  final Duration pollInterval;

  const ActionExpectation({
    this.expectedPackage,
    this.mustAppear,
    this.mustDisappear,
    this.expectedText,
    this.expectedTextTarget,
    this.expectedTextMatch = ExpectedTextMatch.contains,
    this.forbiddenText,
    this.mustChangeSnapshot = false,
    this.platformPredicates = const [],
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
    NanoSelector? expectedTextTarget,
    ExpectedTextMatch? expectedTextMatch,
    String? forbiddenText,
    bool? mustChangeSnapshot,
    List<PlatformPredicate>? platformPredicates,
    Duration? timeout,
    Duration? pollInterval,
  }) {
    return ActionExpectation(
      expectedPackage: expectedPackage ?? this.expectedPackage,
      mustAppear: mustAppear ?? this.mustAppear,
      mustDisappear: mustDisappear ?? this.mustDisappear,
      expectedText: expectedText ?? this.expectedText,
      expectedTextTarget: expectedTextTarget ?? this.expectedTextTarget,
      expectedTextMatch: expectedTextMatch ?? this.expectedTextMatch,
      forbiddenText: forbiddenText ?? this.forbiddenText,
      mustChangeSnapshot: mustChangeSnapshot ?? this.mustChangeSnapshot,
      platformPredicates: platformPredicates ?? this.platformPredicates,
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
      mustChangeSnapshot ||
      platformPredicates.isNotEmpty;

  /// True si hay criterios de UI (snapshot) que exijan el bucle de sondeo.
  bool get hasUiCriteria =>
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
      if (expectedText != null)
        'text${expectedTextMatch == ExpectedTextMatch.exact ? '==' : '~='}$expectedText'
            '${expectedTextTarget == null ? '' : '@${expectedTextTarget!.toDebugString()}'}',
      if (forbiddenText != null) 'forbidden~=$forbiddenText',
      if (mustChangeSnapshot) 'mustChangeSnapshot',
      for (final p in platformPredicates) p.toDebugString(),
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

  /// La percepción fue parcial y no permite probar una ausencia.
  incompleteEvidence,
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
    PlatformStateReader? platformReader,
  }) : _snapshotFn = snapshotFn,
       _engine = engine ?? NanoSelectorEngine(),
       _platformReader = platformReader;

  final Future<NanoSnapshot?> Function() _snapshotFn;
  final NanoSelectorEngine _engine;

  /// Lector de estado de plataforma (A14.5). null = no se pueden verificar
  /// postcondiciones de plataforma (se declara no-verificable, nunca éxito).
  final PlatformStateReader? _platformReader;

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

    // A14.5 — postcondiciones de plataforma: se evalúan como hechos factuales
    // (no UI). Sin lector → no-verificable (honesto, nunca éxito supuesto).
    if (expectation.platformPredicates.isNotEmpty) {
      final reader = _platformReader;
      if (reader == null) {
        return const VerificationOutcome(
          status: VerificationStatus.serviceUnavailable,
          reason:
              'La acción declara postcondiciones de plataforma pero no hay '
              'lector de estado de plataforma.',
        );
      }
      final pr = await evaluateAllOf(expectation.platformPredicates, reader);
      if (pr is PlatformPredicateUnsatisfied) {
        return VerificationOutcome(
          status: VerificationStatus.notVerified,
          reason: 'Postcondición de plataforma NO cumplida: ${pr.reason}',
        );
      }
      if (pr is PlatformPredicateUnavailable) {
        return VerificationOutcome(
          status: VerificationStatus.serviceUnavailable,
          reason: 'Postcondición de plataforma no observable: ${pr.reason}',
        );
      }
      // Plataforma satisfecha. Si NO hay criterios de UI, la acción quedó
      // verificada por plataforma (no hay nada más que sondee un snapshot).
      if (!expectation.hasUiCriteria) {
        return VerificationOutcome(
          status: VerificationStatus.verified,
          reason:
              'Postcondiciones de plataforma cumplidas: '
              '${expectation.toDebugString()}',
        );
      }
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
        final expectedPackage = expectation.expectedPackage;
        if (!lastSnap.truncated &&
            expectedPackage != null &&
            expectedPackage.isNotEmpty &&
            lastSnap.package.isNotEmpty &&
            lastSnap.package != expectedPackage) {
          return VerificationOutcome(
            status: VerificationStatus.wrongPackage,
            reason:
                'Package actual "${lastSnap.package}", esperando '
                '"$expectedPackage".',
            snapshot: lastSnap,
          );
        }
        return VerificationOutcome(
          status: lastSnap.truncated
              ? VerificationStatus.incompleteEvidence
              : VerificationStatus.timeout,
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
    // Restricción dura: fallo inmediato, sin reintentos.
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

    if (e.mustChangeSnapshot && pre == null) {
      // Sin preSnapshot no se puede evaluar el cambio: se declara no
      // verificable en vez de asumir el cambio.
      return VerificationOutcome(
        status: VerificationStatus.notVerified,
        reason: 'mustChangeSnapshot requiere preSnapshot y no se aportó.',
        snapshot: snap,
      );
    }

    // Condiciones de espera: si TODAS las evaluables se cumplen → verified.
    final pending = _pendingList(e, snap, pre);

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
    final incomplete = snap.truncated;
    return <String>[
      if (e.expectedPackage != null &&
          e.expectedPackage!.isNotEmpty &&
          snap.package.isEmpty)
        'package no expuesto por la ventana',
      if (e.expectedPackage != null &&
          e.expectedPackage!.isNotEmpty &&
          snap.package.isNotEmpty &&
          snap.package != e.expectedPackage)
        'package actual "${snap.package}", esperando '
            '"${e.expectedPackage}"',
      if (e.mustAppear != null &&
          !_engine.resolve(e.mustAppear!, snap).isResolved)
        incomplete
            ? 'snapshot incompleto no prueba mustAppear=${e.mustAppear!.toDebugString()}'
            : 'mustAppear=${e.mustAppear!.toDebugString()} sin resolver',
      if (e.mustDisappear != null &&
          _engine.resolve(e.mustDisappear!, snap).isResolved)
        'mustDisappear=${e.mustDisappear!.toDebugString()} sigue presente',
      if (e.mustDisappear != null &&
          !_engine.resolve(e.mustDisappear!, snap).isResolved &&
          incomplete)
        'snapshot incompleto no prueba la ausencia de mustDisappear=${e.mustDisappear!.toDebugString()}',
      if (e.expectedText != null &&
          e.expectedText!.isNotEmpty &&
          !_hasExpectedText(e, snap))
        incomplete
            ? 'snapshot incompleto no prueba expectedText="${e.expectedText}"'
            : 'texto "${e.expectedText}" no visible en '
                  '${e.expectedTextTarget?.toDebugString() ?? 'la pantalla'}',
      if (e.forbiddenText != null &&
          e.forbiddenText!.isNotEmpty &&
          !_containsVisibleText(snap, e.forbiddenText!) &&
          incomplete)
        'snapshot incompleto no prueba la ausencia de forbiddenText="${e.forbiddenText}"',
      if (e.mustChangeSnapshot &&
          pre != null &&
          _signature(snap) == _signature(pre))
        'el snapshot no cambió respecto al previo',
    ];
  }

  /// contains case-insensitive sobre texto/descripción de nodos visibles.
  bool _containsVisibleText(NanoSnapshot snap, String needle) {
    final n = _normalizeComparableText(needle);
    for (final node in snap.visibleNodes) {
      if (_nodeContainsText(node, n)) {
        return true;
      }
    }
    return false;
  }

  bool _hasExpectedText(ActionExpectation expectation, NanoSnapshot snap) {
    final expected = expectation.expectedText;
    if (expected == null || expected.isEmpty) return true;

    final target = expectation.expectedTextTarget;
    if (target == null) {
      if (expectation.expectedTextMatch == ExpectedTextMatch.contains) {
        return _containsVisibleText(snap, expected);
      }
      return snap.visibleNodes.any(
        (node) => _nodeMatchesExactText(node, expected),
      );
    }

    final resolved = _engine.resolve(target, snap);
    if (!resolved.isResolved || resolved.best == null) return false;
    return expectation.expectedTextMatch == ExpectedTextMatch.exact
        ? _nodeMatchesExactText(resolved.best!.node, expected)
        : _nodeContainsText(resolved.best!.node, expected.toLowerCase());
  }

  bool _nodeMatchesExactText(NanoNode node, String expected) {
    final normalized = _normalizeComparableText(expected);
    return _normalizeComparableText(node.text) == normalized ||
        _normalizeComparableText(node.description) == normalized;
  }

  bool _nodeContainsText(NanoNode node, String normalizedNeedle) =>
      _normalizeComparableText(node.text).contains(normalizedNeedle) ||
      _normalizeComparableText(node.description).contains(normalizedNeedle);

  /// Android y algunas apps insertan marcadores Unicode invisibles dentro de
  /// EditText (p. ej. U+200B en el SearchView de WhatsApp). No representan
  /// contenido escrito por el usuario y no deben convertir un ACTION_SET_TEXT
  /// correcto en timeout. Se conservan letras, signos y espacios visibles.
  String _normalizeComparableText(String value) => value
      .replaceAll('\u00A0', ' ')
      .replaceAll(
        RegExp('[\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]'),
        '',
      )
      .trim()
      .toLowerCase();

  /// Firma de contenido visible: detecta cambios de pantalla (set de labels
  /// + bounds). Dos snapshots con la misma firma se consideran iguales.
  String _signature(NanoSnapshot snap) {
    final parts = snap.visibleNodes
        .map((n) => '${n.label}@${n.bounds}')
        .join('|');
    return '${snap.package}#$parts';
  }
}

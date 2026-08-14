/// Selector Engine ponderado — resolución de [NanoSelector] sobre un
/// [NanoSnapshot] del árbol de accesibilidad.
///
/// Filosofía Playwright: criterios semánticos con puntuación ponderada en vez
/// de XPath estructural o "primer nodo con contains". Dos candidatos con
/// puntuación pareja (gap < [ScoringConstants.ambiguityGap]) producen
/// AMBIGUOUS_TARGET y el ejecutor NO toca nada.
///
/// Motor puro: snapshot → ResolveOutcome. Sin MethodChannel — testeable con
/// fixtures.
library;

import 'agent_result.dart';
import 'nano_selector.dart';
import 'nano_snapshot.dart';

/// Constantes de scoring y umbrales. Referencia canónica del motor.
abstract final class ScoringConstants {
  static const int resourceIdExact = 100;
  static const int descriptionExact = 90;

  /// Texto coincide Y rol coincide (75 + 10). El bonus de rol por sí solo
  /// vale [roleBonus].
  static const int roleBonus = 10;

  static const int textExact = 75;
  static const int textFuzzy = 65; // contains / regex
  static const int editableMatch = 45;
  static const int editableFirstPosition = 15; // 45 + 15 = 60 el 1er campo
  static const int clickableMatch = 10; // discriminador, análogo a role
  static const int nearStrongAnchor = 50;
  static const int ocr = 35; // gancho documentado — NO aplicado en v1
  static const int centerRegion = 10;

  /// Score mínimo para que un candidato entre al ranking. Bajo un match
  /// primario (75); descarta evidencia débil aislada (centerRegion 10 solo
  /// no llega).
  static const int minResolvedScore = 40;

  /// Gap de ambigüedad: si el score del candidato Nº [expectedCount] está a
  /// menos de esto del siguiente, no hay evidencia diferenciadora → ambiguous.
  /// Coste de tap erróneo ≫ coste de rechazar → conservador.
  static const int ambiguityGap = 10;

  /// Ancla fuerte para el criterio near: solo nodos con score base ≥ esto
  /// (resourceId 100 o desc 90) anclan vecinos.
  static const int anchorMinScore = 90;

  /// Near: gap máximo en el eje principal (≈2× touch-target padding; una fila
  /// de ListView en 1080×2400 mide 60-150px — 64 mantiene vecindad de fila).
  static const int nearMaxGapPx = 64;

  /// Near: solapamiento mínimo en el eje secundario (label→campo comparten
  /// casi todo el ancho de la fila).
  static const double nearMinOverlap = 0.5;

  /// centerRegion: centro del nodo dentro de ±12% de min(w,h) del centro de
  /// pantalla (1080×2400 → ~130px).
  static const double centerRegionRatio = 0.12;
}

/// Motor de resolución ponderada. Puro: snapshot → outcome. Sin canal.
class NanoSelectorEngine {
  NanoSelectorEngine({
    this.ambiguityGap = ScoringConstants.ambiguityGap,
    this.minResolvedScore = ScoringConstants.minResolvedScore,
  });

  final int ambiguityGap;
  final int minResolvedScore;

  /// Resuelve [selector] contra [snapshot].
  ///
  /// Reglas deterministas:
  /// 1. package restringido y distinto → notFound (precondición dura).
  /// 2. Nodos no visibles o no habilitados quedan fuera (ruido para acciones).
  /// 3. resourceId especificado y sin match → nodo excluido (ancla canónica:
  ///    un match de texto con id equivocado apunta al nodo erróneo).
  /// 4. near: candidatos cercanos a anclas fuertes (score base ≥ 90) ganan
  ///    +50 por proximidad geométrica (sin OCR en v1).
  /// 5. Filtro minScore → sort desc → clasificación por gap.
  ResolveOutcome resolve(NanoSelector selector, NanoSnapshot snapshot) {
    selector.validate();

    if (selector.isPackageConstrained &&
        selector.packageName != snapshot.package) {
      return ResolveOutcome(
        status: ResolveStatus.notFound,
        candidates: const [],
        reason: 'Paquete esperado "${selector.packageName}", actual '
            '"${snapshot.package}".',
      );
    }

    // Score base de todos los candidatos válidos (sin filtro aún).
    final base = <ScoreEntry>[];
    for (final node in snapshot.nodes) {
      final entry = _scoreNode(selector, node, snapshot);
      if (entry != null) base.add(entry);
    }

    // Bonus near: candidatos próximos a anclas del sub-selector near.
    final withNear = _applyNearBonus(selector, base, snapshot);

    final ranked = withNear
        .where((e) => e.score >= minResolvedScore)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (ranked.isEmpty) {
      return ResolveOutcome(
        status: ResolveStatus.notFound,
        candidates: const [],
        reason: 'Sin nodos que alcancen el umbral ($minResolvedScore pts) '
            'para ${selector.toDebugString()}.',
      );
    }

    final top5 = ranked.take(5).toList();
    return _classify(selector, ranked, top5);
  }

  // ── Scoring por nodo ─────────────────────────────────────────────────────

  /// Puntúa [node] contra [selector]. null = excluido del ranking
  /// (invisible/deshabilitado o resourceId sin match).
  ScoreEntry? _scoreNode(
    NanoSelector selector,
    NanoNode node,
    NanoSnapshot snapshot,
  ) {
    if (!node.visible || !node.enabled) return null;

    final criteria = <String>[];
    var score = 0;

    // resourceId: ancla canónica. Si se especifica y no coincide, el nodo
    // queda fuera aunque el texto coincida.
    final wantId = selector.resourceId;
    if (wantId != null && wantId.isNotEmpty) {
      if (node.id != wantId) return null;
      score += ScoringConstants.resourceIdExact;
      criteria.add('resourceId:+100');
    }

    // contentDescription (mismo matcher que text).
    final wantDesc = selector.description;
    if (wantDesc != null && wantDesc.isNotEmpty) {
      if (_matches(wantDesc, node.description, selector.textMatcher)) {
        score += ScoringConstants.descriptionExact;
        criteria.add('desc:+90');
      }
    }

    // Texto + bonus de rol.
    final wantText = selector.text;
    if (wantText != null && wantText.isNotEmpty) {
      if (_matches(wantText, node.text, selector.textMatcher)) {
        final points = selector.textMatcher == TextMatcher.exact
            ? ScoringConstants.textExact
            : ScoringConstants.textFuzzy;
        score += points;
        criteria.add(selector.textMatcher == TextMatcher.exact
            ? 'textExact:+75'
            : 'textFuzzy:+65');
        if (selector.role != null &&
            RoleDerivation.fromClassName(node.type) == selector.role) {
          score += ScoringConstants.roleBonus;
          criteria.add('role:+10');
        }
      }
    } else if (selector.role != null &&
        RoleDerivation.fromClassName(node.type) == selector.role) {
      // Rol sin texto: evidencia débil por sí sola.
      score += ScoringConstants.roleBonus;
      criteria.add('role:+10');
    }

    // editable + posición (1er editable visible en orden de árbol).
    final wantEditable = selector.editable;
    if (wantEditable != null) {
      if (node.editable == wantEditable) {
        score += ScoringConstants.editableMatch;
        criteria.add('editable:+45');
        if (wantEditable) {
          final editables = snapshot.visibleEditables();
          if (editables.isNotEmpty && editables.first.index == node.index) {
            score += ScoringConstants.editableFirstPosition;
            criteria.add('firstEditable:+15');
          }
        }
      }
    }

    // clickable: discriminador (misma clase de evidencia que role).
    final wantClickable = selector.clickable;
    if (wantClickable != null && node.clickable == wantClickable) {
      score += ScoringConstants.clickableMatch;
      criteria.add('clickable:+10');
    }

    // centerRegion: nodo cerca del centro de la pantalla.
    if (_isCenterRegion(node, snapshot)) {
      score += ScoringConstants.centerRegion;
      criteria.add('center:+10');
    }

    // OCR: gancho para v2 (pipeline OCR/VLM). Devuelve 0 en v1.
    score += _ocrContribution(node);

    return ScoreEntry(node: node, score: score, matchedCriteria: criteria);
  }

  /// Gancho OCR: en v1 no hay modelo de visión cargado — siempre 0. Se
  /// documenta para que el criterio quede declarado y trazable.
  int _ocrContribution(NanoNode node) => 0;

  // ── Near / centro ────────────────────────────────────────────────────────

  /// +50 a candidatos próximos a un ancla resuelta por [NanoSelector.near].
  ///
  /// Las anclas son los nodos que resuelven el sub-selector `near` (score >
  /// 0 tras _scoreNode) — el patrón label→campo: `editable=true,
  /// near: desc=Usuario`. Exige no-solapamiento en el eje principal: un
  /// contenedor raíz que envuelve todo el árbol no ancla a sus hijos.
  List<ScoreEntry> _applyNearBonus(
    NanoSelector selector,
    List<ScoreEntry> base,
    NanoSnapshot snapshot,
  ) {
    final nearSel = selector.near;
    if (nearSel == null) return base;

    final anchors = <NanoNode>[];
    for (final node in snapshot.nodes) {
      if (!node.visible || !node.enabled) continue;
      final entry = _scoreNode(nearSel, node, snapshot);
      if (entry != null && entry.score > 0) anchors.add(node);
    }
    if (anchors.isEmpty) return base;

    final out = <ScoreEntry>[];
    for (final entry in base) {
      var bonus = 0;
      for (final anchor in anchors) {
        if (anchor.index == entry.node.index) continue;
        if (_nearVertical(entry.node.bounds, anchor.bounds) ||
            _nearHorizontal(entry.node.bounds, anchor.bounds)) {
          bonus = ScoringConstants.nearStrongAnchor;
          break;
        }
      }
      out.add(
        bonus > 0
            ? ScoreEntry(
                node: entry.node,
                score: entry.score + bonus,
                matchedCriteria: [...entry.matchedCriteria, 'near:+50'],
              )
            : entry,
      );
    }
    return out;
  }

  /// Gap vertical ≤ 64px, ≥ 50% de solapamiento horizontal y CERO solape
  /// vertical (label→campo: filas adyacentes, no anidadas). Solape en el eje
  /// principal da gap -1 → descartado (el root que envuelve todo no ancla).
  bool _nearVertical(NanoBounds a, NanoBounds b) {
    final yGap = (b.top >= a.bottom)
        ? b.top - a.bottom
        : (a.top >= b.bottom)
            ? a.top - b.bottom
            : -1;
    return yGap >= 0 &&
        yGap <= ScoringConstants.nearMaxGapPx &&
        a.xOverlapRatio(b) >= ScoringConstants.nearMinOverlap;
  }

  /// Gap horizontal ≤ 64px, ≥ 50% de solapamiento vertical y CERO solape
  /// horizontal (campo|label: columnas adyacentes, no anidadas).
  bool _nearHorizontal(NanoBounds a, NanoBounds b) {
    final xGap = (b.left >= a.right)
        ? b.left - a.right
        : (a.left >= b.right)
            ? a.left - b.right
            : -1;
    return xGap >= 0 &&
        xGap <= ScoringConstants.nearMaxGapPx &&
        _yOverlapRatio(a, b) >= ScoringConstants.nearMinOverlap;
  }

  double _yOverlapRatio(NanoBounds a, NanoBounds b) {
    final overlapStart = a.top > b.top ? a.top : b.top;
    final overlapEnd = a.bottom < b.bottom ? a.bottom : b.bottom;
    final overlap = overlapEnd - overlapStart;
    if (overlap <= 0) return 0;
    final minHeight = a.height < b.height ? a.height : b.height;
    if (minHeight <= 0) return 0;
    return overlap / minHeight;
  }

  /// Centro del nodo dentro de ±12% de min(w,h) del centro de pantalla.
  /// Tamaño de pantalla aproximado por el bounds máximo del snapshot (el root
  /// suele cubrir toda la ventana) — sin fuente adicional del canal.
  bool _isCenterRegion(NanoNode node, NanoSnapshot snapshot) {
    var sw = 0;
    var sh = 0;
    for (final n in snapshot.nodes) {
      if (n.bounds.right > sw) sw = n.bounds.right;
      if (n.bounds.bottom > sh) sh = n.bounds.bottom;
    }
    if (sw <= 0 || sh <= 0) return false;
    final maxDelta =
        (sw < sh ? sw : sh) * ScoringConstants.centerRegionRatio;
    final dx = (node.bounds.centerX - sw / 2).abs();
    final dy = (node.bounds.centerY - sh / 2).abs();
    return dx <= maxDelta && dy <= maxDelta;
  }

  // ── Clasificación ────────────────────────────────────────────────────────

  /// Aplica el gap de ambigüedad sobre el ranking completo.
  ResolveOutcome _classify(
    NanoSelector selector,
    List<ScoreEntry> ranked,
    List<ScoreEntry> top5,
  ) {
    final expected = selector.expectedCount;
    if (ranked.length <= expected) {
      final best = ranked.first;
      return ResolveOutcome(
        status: ResolveStatus.resolved,
        candidates: top5,
        reason: 'Resuelto: "${best.node.label}" (${best.score} pts).',
      );
    }
    final boundary = ranked[expected - 1].score - ranked[expected].score;
    if (boundary < ambiguityGap) {
      final a = ranked[expected - 1];
      final b = ranked[expected];
      return ResolveOutcome(
        status: ResolveStatus.ambiguous,
        candidates: top5,
        reason: 'Ambiguo: "${a.node.label}" (${a.score}) vs '
            '"${b.node.label}" (${b.score}) — gap $boundary < '
            '$ambiguityGap. No se ejecuta.',
      );
    }
    final best = ranked.first;
    return ResolveOutcome(
      status: ResolveStatus.resolved,
      candidates: top5,
      reason: 'Resuelto: "${best.node.label}" (${best.score} pts).',
    );
  }

  // ── Matcher ──────────────────────────────────────────────────────────────

  bool _matches(String want, String actual, TextMatcher matcher) {
    return switch (matcher) {
      TextMatcher.exact => actual.trim() == want.trim(),
      TextMatcher.contains =>
        actual.toLowerCase().contains(want.toLowerCase()),
      TextMatcher.regex => RegExp(want).hasMatch(actual),
    };
  }
}

/// Estado factual de la superficie que Automation observa antes de navegar.
library;

import 'semantic/screen_graph.dart';
import 'semantic/semantic_role.dart';

/// Forma estructural dominante que puede afirmarse desde el grafo observado.
///
/// Los valores describen estructura, no una aplicación ni la intención del
/// usuario. [unknown] evita inventar una clasificación cuando falta evidencia.
enum CurrentSurfaceKind { unknown, dialog, editable, collection, content }

/// Identidad comparable de una entidad observada. Conserva el nombre real y
/// elimina únicamente decoraciones locales que la app agrega a la conversación
/// propia, porque WhatsApp no siempre indexa esos sufijos en su buscador.
String normalizeNavigationEntity(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceFirst(
      RegExp(r'\s*\((?:tú|tu|you|yo|me)\)\s*$', caseSensitive: false),
      '',
    )
    .trim();

String navigationEntityKey(String value) =>
    normalizeNavigationEntity(value).toLowerCase();

/// Evidencia semántica concreta que justifica una clasificación de superficie.
final class SituationEvidence {
  SituationEvidence({
    required this.objectId,
    required this.role,
    required this.confidence,
    required List<SemanticEvidenceSource> sources,
  }) : sources = List.unmodifiable(sources);

  final String objectId;
  final SemanticRole role;
  final double confidence;
  final List<SemanticEvidenceSource> sources;
}

/// Captura explícita de dónde se encuentra Automation.
///
/// [structuralEvidence] conserva el grafo observado completo y
/// [classificationEvidence] mantiene la trazabilidad de toda clasificación
/// positiva. El contrato no infiere destinos ni objetivos de navegación.
final class CurrentSituation {
  CurrentSituation({
    required this.structuralEvidence,
    required this.surfaceKind,
    required List<SituationEvidence> classificationEvidence,
    String? entity,
    List<SituationEvidence> entityEvidence = const [],
    required DateTime observedAt,
  }) : classificationEvidence = List.unmodifiable(classificationEvidence),
       entity = _normalizeEntity(entity),
       entityEvidence = List.unmodifiable(entityEvidence),
       observedAt = observedAt.toUtc() {
    final classified = surfaceKind != CurrentSurfaceKind.unknown;
    if (classified != this.classificationEvidence.isNotEmpty) {
      throw ArgumentError(
        'Una superficie clasificada requiere evidencia; unknown no debe '
        'inventarla.',
      );
    }
    _validateEvidence(this.classificationEvidence, 'clasificación');

    final identifiesEntity = this.entity != null;
    if (identifiesEntity != this.entityEvidence.isNotEmpty) {
      throw ArgumentError(
        'Una entidad observada requiere evidencia; una entidad ausente no '
        'debe inventarla.',
      );
    }
    _validateEvidence(this.entityEvidence, 'entidad');
    if (identifiesEntity && !_entityIsObserved(this.entity!)) {
      throw ArgumentError(
        'La entidad actual no aparece en la evidencia observada.',
      );
    }
  }

  final ScreenGraph structuralEvidence;
  final CurrentSurfaceKind surfaceKind;
  final List<SituationEvidence> classificationEvidence;
  final String? entity;
  final List<SituationEvidence> entityEvidence;
  final DateTime observedAt;

  String get packageName => structuralEvidence.package;
  bool get isComplete => structuralEvidence.complete;
  bool get hasStructuralEvidence => !structuralEvidence.isEmpty;
  bool get isClassified => surfaceKind != CurrentSurfaceKind.unknown;

  void _validateEvidence(List<SituationEvidence> evidenceList, String owner) {
    for (final evidence in evidenceList) {
      final observed = structuralEvidence.objectById(evidence.objectId);
      if (observed == null ||
          observed.role != evidence.role ||
          observed.confidence != evidence.confidence ||
          observed.evidence.isEmpty ||
          !_sameSources(observed.evidence, evidence.sources)) {
        throw ArgumentError(
          'La $owner contiene evidencia ajena al ScreenGraph.',
        );
      }
    }
  }

  bool _entityIsObserved(String value) {
    final expected = _identityKey(value);
    for (final evidence in entityEvidence) {
      final observed = structuralEvidence.objectById(evidence.objectId)!;
      if ({
        observed.label,
        observed.text,
        observed.description,
      }.any((candidate) => _identityKey(candidate) == expected)) {
        return true;
      }
    }
    return false;
  }

  static String? _normalizeEntity(String? value) {
    final normalized = value == null ? null : normalizeNavigationEntity(value);
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String _identityKey(String value) => navigationEntityKey(value);

  static bool _sameSources(
    List<SemanticEvidenceSource> observed,
    List<SemanticEvidenceSource> claimed,
  ) {
    if (observed.length != claimed.length) return false;
    for (var index = 0; index < observed.length; index++) {
      if (observed[index] != claimed[index]) return false;
    }
    return true;
  }
}

typedef CurrentSituationSource = Future<CurrentSituation?> Function();

/// NanoUiObject (A7) — objeto semántico de UI derivado de un nodo Accessibility.
///
/// Inmutable. `id` es estable DENTRO del snapshot (basado en el ordinal del
/// árbol); no promete estabilidad entre sesiones (eso es ObjectMemory V2/A12).
/// `checkable` no se modela: el snapshot nativo expone el estado efectivo
/// (`checked`/`selected`), suficiente para no reactivar destinos actuales.
library;

import '../nano_snapshot.dart' show NanoBounds;
import 'semantic_role.dart';

class NanoUiObject {
  final String id;
  final SemanticRole role;
  final String label;
  final String text;
  final String description;
  final NanoBounds bounds;
  final bool enabled;
  final bool visible;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final bool checked;
  final bool selected;
  final bool focusable;
  final bool focused;
  final String nativeClass;
  final String resourceId;
  final String? parentId;
  final double confidence;
  final List<SemanticEvidenceSource> evidence;

  /// Ordinal del nodo fuente en el snapshot (para trazar de vuelta).
  final int sourceIndex;
  final String packageName;
  final int windowId;
  final int windowType;
  final int displayId;
  final String rootIdentity;
  final int siblingIndex;

  const NanoUiObject({
    required this.id,
    required this.role,
    required this.label,
    required this.text,
    required this.description,
    required this.bounds,
    required this.enabled,
    required this.visible,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.checked,
    this.selected = false,
    required this.focusable,
    required this.focused,
    required this.nativeClass,
    required this.resourceId,
    required this.parentId,
    required this.confidence,
    required this.evidence,
    required this.sourceIndex,
    this.packageName = '',
    this.windowId = 0,
    this.windowType = 1,
    this.displayId = 0,
    this.rootIdentity = '',
    this.siblingIndex = 0,
  });

  bool get isEditableRole =>
      role == SemanticRole.textField ||
      role == SemanticRole.searchField ||
      role == SemanticRole.passwordField;

  NanoUiObject copyWith({
    SemanticRole? role,
    double? confidence,
    List<SemanticEvidenceSource>? evidence,
  }) {
    return NanoUiObject(
      id: id,
      role: role ?? this.role,
      label: label,
      text: text,
      description: description,
      bounds: bounds,
      enabled: enabled,
      visible: visible,
      clickable: clickable,
      editable: editable,
      scrollable: scrollable,
      checked: checked,
      selected: selected,
      focusable: focusable,
      focused: focused,
      nativeClass: nativeClass,
      resourceId: resourceId,
      parentId: parentId,
      confidence: confidence ?? this.confidence,
      evidence: List.unmodifiable(evidence ?? this.evidence),
      sourceIndex: sourceIndex,
      packageName: packageName,
      windowId: windowId,
      windowType: windowType,
      displayId: displayId,
      rootIdentity: rootIdentity,
      siblingIndex: siblingIndex,
    );
  }
}

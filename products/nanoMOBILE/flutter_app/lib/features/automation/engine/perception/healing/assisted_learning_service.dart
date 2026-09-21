// assisted_learning_service.dart
//
// Servicio de aprendizaje asistido para componentes no resueltos automáticamente.
// - ¿Qué hace?: Permite que el usuario identifique un elemento en pantalla cuando
//   la auto-reparación no alcanza el umbral de confianza (>0.75).
// - ¿Cómo funciona?: Extrae la identidad semántica funcional (roles, textos, resourceIds,
//   adyacencias) del nodo seleccionado por el usuario y lo registra en DynamicSurfaceStore
//   asociado a la versión de la app.
// - ¿Por qué?: No guarda coordenadas absolutas fijas (las cuales cambian con resolución,
//   rotación o teclado) y no otorga autorizaciones indefinidas a ciegas.

library;

import '../semantic/nano_ui_object.dart';
import '../semantic/screen_graph.dart';
import '../semantic/semantic_role.dart';
import '../surface_profiles.dart';
import '../surface_resolvers.dart';
import 'dynamic_surface_store.dart';

/// Resultado del proceso de aprendizaje asistido.
final class AssistedLearningResult {
  final ResolvedSurface? surface;
  final bool success;
  final String message;

  const AssistedLearningResult.success({
    required this.surface,
    required this.message,
  }) : success = true;

  const AssistedLearningResult.rejected({
    required this.message,
  })  : surface = null,
        success = false;
}

/// Servicio de aprendizaje asistido para componentes no resueltos.
final class AssistedLearningService {
  AssistedLearningService({DynamicSurfaceStore? store})
      : _store = store ?? globalDynamicSurfaceStore;

  final DynamicSurfaceStore _store;

  /// Registra la selección asistida del usuario y aprende su identidad funcional.
  AssistedLearningResult learnUserSelection({
    required ScreenGraph graph,
    required NanoUiObject selectedObject,
    required SurfaceElementKind kind,
    String? appVersion,
  }) {
    // 1. Validar pertenencia al paquete en primer plano
    final pkg = graph.package.trim().toLowerCase();
    if (selectedObject.packageName.isNotEmpty &&
        selectedObject.packageName.trim().toLowerCase() != pkg) {
      return const AssistedLearningResult.rejected(
        message: 'El elemento seleccionado no pertenece a la aplicación en primer plano.',
      );
    }

    // 2. Validar idoneidad funcional según el tipo de superficie requerida
    if (kind == SurfaceElementKind.messageInput || kind == SurfaceElementKind.searchInput) {
      if (!selectedObject.editable && !selectedObject.isEditableRole) {
        return const AssistedLearningResult.rejected(
          message: 'El elemento seleccionado no admite entrada de texto.',
        );
      }
    } else if (kind == SurfaceElementKind.sendAction || kind == SurfaceElementKind.confirmAction) {
      final isClickable = selectedObject.clickable ||
          selectedObject.role == SemanticRole.button ||
          selectedObject.role == SemanticRole.iconButton;
      if (!isClickable) {
        return const AssistedLearningResult.rejected(
          message: 'El elemento seleccionado no es un botón ni componente accionable.',
        );
      }
    }

    // 3. Extraer términos semánticos representativos (nunca coordenadas)
    final terms = <String>{};
    if (selectedObject.description.trim().isNotEmpty) {
      terms.add(selectedObject.description.trim().toLowerCase());
    }
    if (selectedObject.text.trim().isNotEmpty) {
      terms.add(selectedObject.text.trim().toLowerCase());
    }
    if (selectedObject.label.trim().isNotEmpty) {
      terms.add(selectedObject.label.trim().toLowerCase());
    }
    if (selectedObject.resourceId.trim().isNotEmpty) {
      terms.add(selectedObject.resourceId.trim().toLowerCase());
    }

    if (terms.isEmpty) {
      // Si no tiene texto accesible ni id, se guarda el rol estructural con contenedor
      terms.add(selectedObject.role.name.toLowerCase());
    }

    // 4. Registrar en el almacén dinámico asociado a la versión de la app
    _store.registerHealedElement(
      packageName: pkg,
      kind: kind,
      roles: {selectedObject.role},
      terms: terms.toList(growable: false),
      allowClickableContainer: selectedObject.clickable,
      appVersion: appVersion,
    );

    final selector = surfaceSelectorFor(selectedObject);
    final surface = ResolvedSurface(
      selectedObject,
      selector,
      'assisted-learned: validado por usuario (${terms.first})',
    );

    return AssistedLearningResult.success(
      surface: surface,
      message: 'Componente aprendido exitosamente para $pkg (regla semántica: $selector).',
    );
  }
}

/// Identidad activa de una conversación observada.
library;

import 'current_situation.dart';
import 'semantic/nano_ui_object.dart';
import 'semantic/screen_graph.dart';
import 'semantic/semantic_role.dart';

/// Identidad + evidencia que la demostró en el grafo actual.
final class EntityIdentity {
  const EntityIdentity(this.entity, this.evidence);

  final String entity;
  final List<SituationEvidence> evidence;
}

/// Resuelve la identidad ACTIVA desde la estructura observada: el nombre del
/// chat en el header/toolbar de una superficie editable (conversación) o de
/// contenido (perfil, detalle de llamada, visor multimedia). El texto visible
/// incidental (mensajes, resultados, pestañas, subtítulos de estado) nunca es
/// identidad. null = identidad no demostrable (lista, búsqueda o header
/// ilegible) — nunca se inventa.
///
/// INVARIANTE: VISIBLE TARGET TEXT IS NOT AUTOMATICALLY ACTIVE ENTITY IDENTITY.
final class EntityIdentityResolver {
  const EntityIdentityResolver();

  EntityIdentity? resolve(
    ScreenGraph graph,
    CurrentSurfaceKind surfaceKind,
  ) {
    if (surfaceKind != CurrentSurfaceKind.editable &&
        surfaceKind != CurrentSurfaceKind.content) {
      return null;
    }

    final names = <NanoUiObject>[];
    for (final toolbar in graph.objects) {
      if (!toolbar.visible || toolbar.role != SemanticRole.toolbar) continue;
      _collectNames(graph, toolbar, names);
    }
    if (names.length != 1) return null;

    final name = names.single;
    final value = name.text.isNotEmpty ? name.text : name.description;
    final normalized = normalizeNavigationEntity(value);
    if (normalized.isEmpty) return null;
    return EntityIdentity(
      normalized,
      [
        SituationEvidence(
          objectId: name.id,
          role: name.role,
          confidence: name.confidence,
          sources: name.evidence,
        ),
      ],
    );
  }

  void _collectNames(
    ScreenGraph graph,
    NanoUiObject toolbar,
    List<NanoUiObject> out,
  ) {
    var frontier = <NanoUiObject>[toolbar];
    final visited = <String>{toolbar.id};
    for (var depth = 0; depth < 4 && frontier.isNotEmpty; depth++) {
      final next = <NanoUiObject>[];
      for (final node in frontier) {
        for (final child in graph.childrenOf(node.id)) {
          if (!visited.add(child.id)) continue;
          if (_isNameCandidate(child)) out.add(child);
          next.add(child);
        }
      }
      frontier = next;
    }
  }

  bool _isNameCandidate(NanoUiObject object) {
    if (!object.visible || object.editable || object.isEditableRole) {
      return false;
    }
    final hay = '${object.label} ${object.text} ${object.description}'
        .trim()
        .toLowerCase();
    if (hay.isEmpty) return false;
    // Botones de acción del header (retroceso, menú, llamada, búsqueda).
    if (_actionTerms.any(hay.contains)) return false;
    // Subtítulos de estado debajo del nombre ("en línea", "escribiendo...").
    if (_statusTerms.any(hay.contains)) return false;
    return true;
  }

  static const _actionTerms = [
    'volver',
    'atrás',
    'atras',
    'navegar hacia arriba',
    'back',
    'up navigation',
    'regresar',
    'retroceder',
    'navigate back',
    'go back',
    'más opciones',
    'mas opciones',
    'more options',
    'menu',
    'menú',
    'opciones',
    'options',
    'llamada de voz',
    'videollamada',
    'llamada de video',
    'voice call',
    'video call',
    'llamada',
    'call',
    'mensaje',
    'message',
    'información',
    'info',
    'information',
    'buscar',
    'search',
    'ajustes',
    'settings',
    'cerrar',
    'close',
    'cancelar',
    'cancel',
    'descartar',
    'dismiss',
    'silenciar',
    'mute',
    'archivar',
    'archive',
    'bloquear',
    'block',
    'reportar',
    'report',
    'fijar',
    'pin',
    'perfil',
    'profile',
    'adjuntar',
    'attach',
    'cámara',
    'camera',
    'galería',
    'gallery',
    'documento',
    'document',
    'emoji',
    'sticker',
    'pagar',
    'pay',
  ];

  static const _statusTerms = [
    'en línea',
    'en linea',
    'online',
    'escribiendo',
    'typing',
    'última vez',
    'ultima vez',
    'last seen',
    'conectado',
    'connected',
    'presionando',
    'pressing',
    'activo ahora',
    'active now',
    'recientemente',
    'recently',
    'última conexión',
    'last connection',
    'conectado hace',
    'en una llamada',
    'in a call',
    'en llamada',
    'grabando',
    'recording',
    'disponible',
    'available',
  ];
}

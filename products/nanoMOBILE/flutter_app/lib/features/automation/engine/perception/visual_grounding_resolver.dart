import 'dart:ui';

/// Roles funcionales inferidos visualmente para componentes sin texto accesible.
enum VisualRole {
  search('Acción de búsqueda (lupa)'),
  attach('Adjuntar archivo o medio (clip)'),
  voice('Entrada de voz o grabación (micrófono)'),
  send('Enviar mensaje o confirmación (flecha/círculo)'),
  spinner('Indicador de carga en progreso (spinner)'),
  modal('Diálogo o ventana emergente superpuesta'),
  keyboard('Teclado virtual activo en pantalla'),
  unknown('Componente no clasificado');

  final String description;
  const VisualRole(this.description);
}

/// Evidencia visual de un componente identificado en pantalla.
class VisualElementEvidence {
  final VisualRole role;
  final Rect boundingBox;
  final double confidence;
  final String? matchedText;

  const VisualElementEvidence({
    required this.role,
    required this.boundingBox,
    this.confidence = 0.8,
    this.matchedText,
  });
}

/// Resolutor de correspondencia semántica entre elementos visuales y nodos accesibles.
///
/// Principios SOLID:
/// - SRP: Responsabilidad única de inferir roles funcionales a partir de evidencia visual y OCR.
/// - OCP: Extensible para nuevos clasificadores visuales sin alterar la estructura del ScreenGraph.
class VisualGroundingResolver {
  const VisualGroundingResolver();

  /// Infiere el rol funcional de un componente sin texto a partir de indicios OCR o visuales.
  VisualElementEvidence inferRole({
    required Rect bounds,
    String? contentDescription,
    String? resourceId,
    List<String> adjacentOcrTokens = const [],
  }) {
    final desc = (contentDescription ?? '').toLowerCase();
    final res = (resourceId ?? '').toLowerCase();
    final tokens = adjacentOcrTokens.map((t) => t.toLowerCase()).toList();

    // 1. Detección de Búsqueda (Lupa)
    if (_matchesKeywords(desc, res, tokens, ['search', 'buscar', 'lupa', 'query', 'pesquisar', 'find'])) {
      return VisualElementEvidence(
        role: VisualRole.search,
        boundingBox: bounds,
        confidence: 0.9,
      );
    }

    // 2. Detección de Adjuntar (Clip)
    if (_matchesKeywords(desc, res, tokens, ['attach', 'clip', 'adjuntar', 'archivo', 'media', 'anexo', 'anexar', 'file'])) {
      return VisualElementEvidence(
        role: VisualRole.attach,
        boundingBox: bounds,
        confidence: 0.85,
      );
    }

    // 3. Detección de Micrófono / Voz
    if (_matchesKeywords(desc, res, tokens, ['voice', 'mic', 'microfono', 'micrófono', 'audio', 'record', 'gravar', 'voz'])) {
      return VisualElementEvidence(
        role: VisualRole.voice,
        boundingBox: bounds,
        confidence: 0.9,
      );
    }

    // 4. Detección de Enviar (Flecha / Círculo)
    if (_matchesKeywords(desc, res, tokens, ['send', 'enviar', 'submit', 'arrow_forward', 'post', 'share', 'encaminhar'])) {
      return VisualElementEvidence(
        role: VisualRole.send,
        boundingBox: bounds,
        confidence: 0.9,
      );
    }

    // 5. Detección de Carga / Spinner
    if (_matchesKeywords(desc, res, tokens, ['loading', 'progress', 'spinner', 'cargando', 'carregando', 'esperando'])) {
      return VisualElementEvidence(
        role: VisualRole.spinner,
        boundingBox: bounds,
        confidence: 0.85,
      );
    }

    // 6. Detección de Modal
    if (_matchesKeywords(desc, res, tokens, ['dialog', 'modal', 'alerta', 'popup', 'aviso', 'confirmar'])) {
      return VisualElementEvidence(
        role: VisualRole.modal,
        boundingBox: bounds,
        confidence: 0.8,
      );
    }

    return VisualElementEvidence(
      role: VisualRole.unknown,
      boundingBox: bounds,
      confidence: 0.3,
    );
  }

  /// Comprueba si el componente actual se encuentra dentro de un cuadro modal.
  bool isInsideModal(Rect componentBounds, Rect? modalBounds) {
    if (modalBounds == null) return false;
    return modalBounds.contains(componentBounds.center);
  }

  bool _matchesKeywords(
    String desc,
    String res,
    List<String> tokens,
    List<String> keywords,
  ) {
    for (final kw in keywords) {
      if (desc.contains(kw) || res.contains(kw)) return true;
      if (tokens.any((t) => t.contains(kw))) return true;
    }
    return false;
  }
}

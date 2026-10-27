/// Edición pura del cuerpo: preserva encabezado, botones, ejemplos y pie.
/// No interpreta ni aprueba recursos remotos; Meta valida el payload final.
abstract final class MetaTemplateContent {
  static String body(List<Map<String, dynamic>> components) {
    for (final component in components) {
      if (component['type'] == 'BODY') {
        return component['text'] as String? ?? '';
      }
    }
    return '';
  }

  /// Copia solo el componente editado, sin borrar ejemplos de variables.
  static List<Map<String, dynamic>> withBody(
    List<Map<String, dynamic>> components,
    String text,
  ) {
    final result = <Map<String, dynamic>>[
      for (final component in components)
        if (component['type'] == 'BODY')
          {...component, 'text': text}
        else
          {...component},
    ];
    final found = components.any((component) => component['type'] == 'BODY');
    if (!found) result.add({'type': 'BODY', 'text': text});
    return result;
  }
}

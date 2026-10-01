/// QUÉ: aporta identidad verificable de la aplicación, separada del modelo.
/// CÓMO: reconoce consultas sobre Nano y agrega solo el proveedor/archivo reales.
/// POR QUÉ: evita buscar otra entidad «Nano» en Internet o inventar conexiones.
library;

abstract final class NanoIdentityContext {
  static const description =
      'NanoAI (Nano) es una aplicación Android con un asistente de IA, chat '
      'y agentes Personal y Negocios. El modelo y sus conexiones se '
      'configuran por separado.';

  static final _productQuestion = RegExp(
    r'\b(?:qu[eé]\s+es|qu[eé]\s+hace|c[oó]mo\s+funciona|'
    r'para\s+qu[eé]\s+sirve|h[aá]blame\s+de|expl[ií]came)\s+'
    r'(?:el\s+)?(?:nano(?:\s+ai|\s+mobile)?|nanoai)\b',
    caseSensitive: false,
  );
  static final _modelQuestion = RegExp(
    r'\b(?:(?:qu[eé]|cu[aá]l)\s+(?:es\s+)?(?:tu|este)\s+modelo|'
    r'qu[eé]\s+modelo\s+(?:usas|utilizas|tienes)|'
    r'conectad[oa]\s+a\s+qwen)\b',
    caseSensitive: false,
  );

  /// Reconoce identidad local; otras preguntas factuales conservan su búsqueda.
  static bool matches(String text) =>
      _productQuestion.hasMatch(text) || _modelQuestion.hasMatch(text);

  /// Incluye configuración observada, sin confundir archivo elegido con nube.
  static String promptBlock({String? modelPath, required String provider}) {
    final file = modelPath?.split(RegExp(r'[/\\]')).last.trim() ?? '';
    return <String>[
      '<DATOS REALES DE NANO>',
      description,
      'Proveedor configurado para este turno: $provider.',
      if (file.isNotEmpty) 'Archivo de modelo local seleccionado: $file.',
      'Un nombre de modelo no demuestra conexión a sus servidores. '
          'Describe capacidades o acciones activas solo con evidencia.',
      '</DATOS REALES DE NANO>',
    ].join('\n');
  }
}

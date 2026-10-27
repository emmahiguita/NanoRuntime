// QUÉ HACE: Conserva la única medición hecha en el OPPO de desarrollo.
// CÓMO FUNCIONA: Busca por nombre exacto y evita prestar resultados a otra variante.
// POR QUÉ: Una ejecución observada no permite generalizar velocidad a otros teléfonos.
library;

// Guarda solo datos medidos, sin mezclar estimaciones o benchmarks ajenos.
class MobileHardwareBenchmark {
  final String modelName;
  final String phoneTested;
  final String soc;
  final double tokensPerSec;
  final double ttftSeconds;
  final String sampleNote;

  const MobileHardwareBenchmark({
    required this.modelName,
    required this.phoneTested,
    required this.soc,
    required this.tokensPerSec,
    required this.ttftSeconds,
    required this.sampleNote,
  });
}

// Registro local de una prueba; no representa un promedio ni una promesa.
class MobileHardwareBenchmarkRegistry {
  static const List<MobileHardwareBenchmark> localProbes = [
    MobileHardwareBenchmark(
      modelName: 'Qwen3-0.6B-Instruct (LiteRT)',
      phoneTested: 'OPPO CPH2557',
      soc: 'MediaTek MT6833',
      tokensPerSec: 7.53,
      ttftSeconds: 12.2,
      sampleNote: 'Una ejecución observada; no es promedio ni garantía.',
    ),
  ];

  // La igualdad exacta impide atribuir el dato a un archivo GGUF u otra variante.
  static MobileHardwareBenchmark? findForModel(String name) {
    for (final probe in localProbes) {
      if (probe.modelName.toLowerCase() == name.toLowerCase()) return probe;
    }
    return null;
  }
}

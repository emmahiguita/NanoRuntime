/// MemoryBudget (A15) — ciclo de vida HOT/WARM/COLD de modelos residentes.
///
/// Filosofía Nano: NO mantener simultáneamente LLM grande + VLM + OCR pesado +
/// STT residentes. La automatización básica funciona SIN Vision cargada.
library;

enum ModelComponent { llm, vlm, ocr, stt, tts }

enum ResidencyState { hot, warm, cold }

class MemoryBudget {
  final Map<ModelComponent, ResidencyState> _residency;

  const MemoryBudget(this._residency);

  /// Budget por defecto: LLM hot (núcleo), OCR warm (on-demand), VLM/STT/TTS
  /// cold (no residentes). La automatización básica NO necesita Vision.
  static const MemoryBudget defaultBudget = MemoryBudget({
    ModelComponent.llm: ResidencyState.hot,
    ModelComponent.ocr: ResidencyState.warm,
    ModelComponent.vlm: ResidencyState.cold,
    ModelComponent.stt: ResidencyState.cold,
    ModelComponent.tts: ResidencyState.cold,
  });

  bool isResident(ModelComponent c) => stateOf(c) == ResidencyState.hot;

  bool isWarm(ModelComponent c) => stateOf(c) == ResidencyState.warm;

  ResidencyState stateOf(ModelComponent c) =>
      _residency[c] ?? ResidencyState.cold;
}

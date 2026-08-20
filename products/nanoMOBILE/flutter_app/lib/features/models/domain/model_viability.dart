/// Viabilidad de un modelo en el dispositivo — autoridad de presentación.
///
/// Los umbrales replican EXACTAMENTE los del RuntimePlanner (Rust,
/// `assess_viability`): 0.7 / 1.0 / 2.0 sobre la relación
/// RAM-requerida / RAM-del-dispositivo. Es el fallback SÍNCRONO que se usa
/// cuando el motor no está disponible; cuando lo está, la autoridad real es
/// `POST /api/viability` (ver `LLMEngineClient.assessModelViability`).
library;

enum ModelViability { fast, balanced, streaming, extreme }

/// Clasificación local alineada con Rust. No es la autoridad: solo el
/// placeholder offline hasta que el motor responda el veredicto real.
ModelViability viabilityFor(double requiredRamGb, double deviceTotalRamGb) {
  if (deviceTotalRamGb <= 0) return ModelViability.fast;
  final ratio = requiredRamGb / deviceTotalRamGb;
  if (ratio <= 0.7) return ModelViability.fast;
  if (ratio <= 1.0) return ModelViability.balanced;
  if (ratio <= 2.0) return ModelViability.streaming;
  return ModelViability.extreme;
}

/**
 * Utilidad técnica de estimación de VRAM y políticas de ciclo de vida (Model Fitting).
 * Aplica fórmulas de offload de capas en base a pesos y KV Cache.
 */

/**
 * Calcula el ajuste de memoria y requerimiento de offload.
 * Fórmula: VRAM = Weights + (Context * 32 * 2 bytes) + 512MB buffer
 * @param {string} modelName Nombre o identificador del modelo GGUF.
 * @param {number} contextLength Ventana de contexto configurada (por defecto 4096).
 * @returns {object} Reporte de adecuación con requerimientos y política recomendada.
 */
export function calculateModelFit(modelName, contextLength = 4096) {
  const name = (modelName || '').toLowerCase();
  const weightsMb = name.includes('8b') ? 4720 : name.includes('mini') ? 2280 : 3840;
  const kvCacheMb = Math.round(((contextLength * 32 * 2) / (1024 * 1024)) * 100);
  const overheadBuffer = 512;
  const totalRequiredMb = weightsMb + kvCacheMb + overheadBuffer;

  return {
    model: modelName,
    weights_mb: weightsMb,
    kv_cache_mb: kvCacheMb,
    buffer_mb: overheadBuffer,
    total_vram_required_mb: totalRequiredMb,
    recommended_offload_layers:
      totalRequiredMb < 8192 ? '100% GPU Offload (33 capas)' : 'Offload Híbrido (20 GPU / 13 CPU)',
    ttl_policy: totalRequiredMb < 4096 ? 'PINNED' : 'BALANCED',
  };
}

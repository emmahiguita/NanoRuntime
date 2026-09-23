/**
 * Motor Cognitivo Mock para Modo Desarrollo (DEV_MOCK_MODE).
 * ATENCIÓN: Solo se ejecuta si window.DEV_MOCK_MODE === true.
 * Prohibido su uso como fallback silencioso en producción.
 */

export function generateCognitiveResponse({ prompt, model, deepThink, webContext, attachments }) {
  const p = (prompt || '').toLowerCase();
  let think = '';
  let answer = '';

  const hasAttachment = attachments && attachments.length > 0;

  if (hasAttachment) {
    const file = attachments[0];
    think = `1. Analizar archivo adjunto local: "${file.name}" (${file.size} bytes).
2. Procesar contexto inyectado en entorno de pruebas.`;
    answer = `[MOCK DEV] Archivo **\`${file.name}\`** analizado en modo desarrollo local.`;
  } else if (webContext && webContext.includes('Dirección IP')) {
    think = '1. Formatear IP detectada en modo test.';
    answer = `[MOCK DEV] Telemetría de red: ${webContext.trim()}`;
  } else if (p.includes('arquitectura') || p.includes('rust') || p.includes('nanoruntime')) {
    think = '1. Describir arquitectura modular NanoRuntime.';
    answer = `[MOCK DEV] NanoRuntime utiliza Rust con InferenceBackend trait y RuntimeSupervisor desacoplado.`;
  } else if (p.includes('fit') || p.includes('vram')) {
    think = '1. Explicar cálculo de VRAM.';
    answer = `[MOCK DEV] Fórmula de VRAM: Weights + KV Cache + 512 MB buffer.`;
  } else {
    think = `1. Generar respuesta simulada para test de interfaz con modelo: ${model}.`;
    answer = `[MOCK DEV] Respuesta simulada en modo de pruebas local para el prompt: "${prompt}".`;
  }

  if (deepThink) {
    return `<think>\n${think}\n</think>\n\n${answer}`;
  }
  return answer;
}

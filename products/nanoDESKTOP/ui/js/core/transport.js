/**
 * transport.js — Fachada de Transporte Unificada DIP (< 200 LOC)
 *
 * QUÉ HACE: expone telemetría e inferencia al resto de la UI:
 *   - `chatPromptStream` (delegado al pipeline de transport_streaming.js)
 *   - `getSystemStatus` / `listModels` / `generateText`
 * CÓMO FUNCIONA: usa Tauri IPC o REST local; si fallan, informa el error real.
 *   No sustituye inferencia fallida por respuestas simuladas.
 * POR QUÉ: DIP — la UI depende de esta fachada y nunca del protocolo concreto
 *   (IPC nativo vs HTTP). El streaming se extrajo para mantener cada archivo
 *   por debajo de 200 líneas y una única responsabilidad (SRP).
 */
import { searchWebKnowledge, isQueryDemandingWeb } from './web_search_helper.js';
import { calculateModelFit } from './model_fitter.js';
import { streamChatPrompt } from './transport_streaming.js';
import { listLocalModels, activateLocalModel } from './local_model_api.js';

export class TransportClient {
  constructor() {
    this.isTauri = typeof window !== 'undefined' && Boolean(window.__TAURI__);
    // En navegador web usa el origin actual (ej: http://127.0.0.1:8080)
    this.webBaseUrl = typeof window !== 'undefined' && window.location?.origin?.startsWith('http')
      ? window.location.origin
      : 'http://127.0.0.1:8080';
    // Capacidades de búsqueda web expuestas a la UI (delegación directa)
    this.searchWebKnowledge = searchWebKnowledge;
    this.isQueryDemandingWeb = isQueryDemandingWeb;
    this.calculateModelFit = calculateModelFit;
    // Registro de controladores de cancelación activos por requestId (evita race conditions)
    this.activeControllers = new Map();
    this.selectedModelPath = '';
  }

  /**
   * Retrocompatibilidad: expone el último controller activo si existe.
   */
  get abortController() {
    const controllers = Array.from(this.activeControllers.values());
    return controllers.length > 0 ? controllers[controllers.length - 1] : null;
  }

  /**
   * Cancela la espera por requestId; la detención del motor nativo no está confirmada.
   * @param {string} [requestId]
   * @returns {boolean}
   */
  abort(requestId) {
    if (requestId) {
      const controller = this.activeControllers.get(requestId);
      if (controller) {
        controller.abort();
        this.activeControllers.delete(requestId);
        return true;
      }
      return false;
    }
    let abortedAny = false;
    for (const controller of this.activeControllers.values()) {
      controller.abort();
      abortedAny = true;
    }
    this.activeControllers.clear();
    return abortedAny;
  }

  /**
   * Streaming de inferencia de chat. Delegado por completo al pipeline
   * (Tauri o REST); esta clase solo actúa como punto de entrada.
   */
  async chatPromptStream(options) {
    return streamChatPrompt(this, { ...options, model: options.model || this.selectedModelPath });
  }

  /** Selecciona un archivo existente; los nombres de presentación nunca son rutas. */
  async activateModel(path) { return activateLocalModel(this, path); }

  /**
   * Telemetría del sistema: RAM real por Tauri, o metadatos del runtime REST.
   * Nunca lanza: si todo falla retorna estado 'offline' explícito.
   */
  async getSystemStatus() {
    if (this.isTauri) {
      try {
        const raw = await window.__TAURI__.core.invoke('nano_system_status');
        return {
          os_name: raw.os_name, arch: raw.arch, cpu_arch: raw.arch,
          total_ram_mb: raw.total_ram_mb, used_ram_mb: raw.used_ram_mb,
          available_ram_mb: raw.available_ram_mb, runtime_version: raw.runtime_version,
          gpu_usage_pct: null, status: raw.status || 'online',
          model_loaded: raw.model_loaded ?? null,
          model_name: raw.model_name ?? null,
        };
      } catch (e) { console.warn('[Transport] Error telemetría Tauri:', e); }
    }

    try {
      const res = await fetch(`${this.webBaseUrl}/api/status`, { signal: AbortSignal.timeout(15000) });
      if (res.ok) {
        const data = await res.json();
        const isRunning = data.model_loaded === true || data.model_status === 'ready';
        return {
          os_name: data.os_name ?? null,
          arch: data.arch ?? null,
          cpu_arch: data.arch ?? null,
          total_ram_mb: data.total_ram_mb ?? null,
          used_ram_mb: data.used_ram_mb ?? null,
          available_ram_mb: data.available_ram_mb ?? null,
          runtime_version: data.version ?? null,
          gpu_usage_pct: null,
          status: isRunning ? 'online' : 'offline',
          context_size: data.context_size ?? null,
          model_loaded: Boolean(data.model_loaded),
          model_size_mb: data.model_size_mb ?? null,
          model_name: data.model_name ?? null,
          model_path: data.model_path ?? data.model ?? null,
          model_status: data.model_status ?? null,
          model_error: data.model_error ?? null,
          tier: data.tier || 'local',
          tok_s: data.tok_s ?? null,
          viability: data.viability ?? null,
          uptime_seconds: data.uptime_seconds || 0,
        };
      }
    } catch (error) { console.warn('[Transport] Telemetría REST no disponible:', error.message); }

    return {
      os_name: null, arch: null, cpu_arch: null, total_ram_mb: null,
      used_ram_mb: null, available_ram_mb: null, runtime_version: null,
      gpu_usage_pct: null, status: 'offline',
      model_loaded: false,
    };
  }

  /** Modelos de disco por IPC o catálogo del servidor; no emplea filas de ejemplo. */
  async listModels() {
    if (this.isTauri) {
      try {
        const res = await window.__TAURI__.core.invoke('nano_list_models');
        if (Array.isArray(res)) return res;
      } catch (e) { console.warn('[Transport] Error list models:', e); }
    }
    if (!this.isTauri) return listLocalModels(this);
    return [];
  }

  /**
   * Inferencia de texto de una sola respuesta (sin streaming visible).
   * Envuelve chatPromptStream en una promesa con el texto final completo.
   */
  async generateText(options) {
    const prompt = options.prompt || '';
    const model = options.model_path || this.selectedModelPath;
    const start = performance.now();
    // Un agente puede elegir otro archivo del catálogo; confirma el cambio antes de inferir.
    options.signal?.throwIfAborted();
    if (model && model !== this.selectedModelPath) await this.activateModel(model);
    options.signal?.throwIfAborted();

    return new Promise((resolve, reject) => {
      this.chatPromptStream({
        prompt, model, maxTokens: options.max_tokens || 128,
        signal: options.signal, requestId: options.requestId,
        history: options.history || [], sessionId: options.session_id || null,
        onDone: (m) => resolve({ text: m.text, inference_time_ms: performance.now() - start, tok_s: m.tok_s ?? null }),
        onError: reject,
      }).catch(reject);
    });
  }
}

export const transport = new TransportClient();

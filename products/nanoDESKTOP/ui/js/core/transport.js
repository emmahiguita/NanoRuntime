/**
 * transport.js — Capa de Transporte Unificada DIP (< 200 LOC)
 * QUÉ HACE: Gestiona streaming de tokens con el backend (Tauri IPC / REST) y telemetría.
 * CÓMO FUNCIONA: Prioriza Tauri IPC. Fallback a HTTP REST. Fallback mock en DEV_MOCK_MODE.
 * POR QUÉ: DIP — Frontend desacoplado del protocolo de transporte de inferencia.
 */
import { searchWebKnowledge, isQueryDemandingWeb } from './web_search_helper.js';
import { calculateModelFit } from './model_fitter.js';
import { generateCognitiveResponse } from './mock_cognitive.js';

export class TransportClient {
  constructor() {
    this.isTauri = typeof window !== 'undefined' && Boolean(window.__TAURI__);
    this.webBaseUrl = 'http://localhost:8080';
    this.abortController = null;
    this.searchWebKnowledge = searchWebKnowledge;
    this.isQueryDemandingWeb = isQueryDemandingWeb;
    this.calculateModelFit = calculateModelFit;
  }

  async chatPromptStream({
    prompt, model = 'qwen.gguf', maxTokens = 512, webSearch = false,
    deepThink = true, attachedFiles = [], onToken = () => {}, onDone = () => {}, onError = () => {},
  }) {
    this.abortController = new AbortController();
    const startTime = performance.now();

    try {
      let webContext = '';
      if (webSearch || this.isQueryDemandingWeb(prompt)) {
        try {
          const res = await this.searchWebKnowledge(prompt);
          if (res?.found) webContext = `\n\n[Web Grounding - ${res.source}]:\n${res.snippet}\n`;
        } catch (e) { console.warn('[Transport] Error web search:', e); }
      }

      let attachContext = '';
      if (attachedFiles?.length > 0) {
        attachContext = attachedFiles.map((f) => `\n[Archivo: ${f.name}]:\n${f.content.slice(0, 3000)}`).join('\n');
      }

      const fullPrompt = `${attachContext}${webContext}\n${prompt}`.trim();

      // 1. Streaming real por eventos IPC en Tauri Desktop
      if (this.isTauri) {
        const { invoke } = window.__TAURI__.core;
        const { listen } = window.__TAURI__.event;
        const requestId = globalThis.crypto?.randomUUID?.()
          ?? `nano-${Date.now()}-${Math.random().toString(16).slice(2)}`;
        let unlistenToken = null, unlistenDone = null, unlistenError = null;

        const cleanup = () => {
          const listeners = [unlistenToken, unlistenDone, unlistenError];
          unlistenToken = null;
          unlistenDone = null;
          unlistenError = null;
          listeners.forEach((unlisten) => {
            if (unlisten) unlisten();
          });
        };

        let resolveDone;
        let rejectDone;
        const donePromise = new Promise((resolve, reject) => {
          resolveDone = resolve;
          rejectDone = reject;
        });

        try {
          unlistenToken = await listen('chat-token', (e) => {
            if (e.payload?.request_id !== requestId) return;
            onToken(e.payload.token, { elapsed: (performance.now() - startTime) / 1000 });
          });

          unlistenDone = await listen('chat-done', (e) => {
            if (e.payload?.request_id !== requestId) return;
            const sec = (performance.now() - startTime) / 1000;
            try {
              onDone({ text: e.payload.text, tok_s: e.payload.tok_s, time: `${sec.toFixed(2)}s`, model: e.payload.model });
              resolveDone();
            } catch (error) {
              rejectDone(error);
            }
          });

          unlistenError = await listen('chat-error', (e) => {
            if (e.payload?.request_id !== requestId) return;
            rejectDone(new Error(e.payload.message));
          });

          await Promise.all([
            invoke('nano_chat_prompt_stream', {
              input: { prompt: fullPrompt, model_path: model, max_tokens: maxTokens, request_id: requestId },
            }),
            donePromise,
          ]);
          return;
        } finally {
          cleanup();
        }
      }

      // 2. Inferencia en Servidor Web REST HTTP
      try {
        const resp = await fetch(`${this.webBaseUrl}/api/chat`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ prompt: fullPrompt, max_tokens: maxTokens }),
          signal: this.abortController.signal,
        });

        if (resp.ok) {
          const data = await resp.json();
          onToken(data.response, { tok_s: data.tok_s || 0 });
          const sec = (performance.now() - startTime) / 1000;
          onDone({ text: data.response, tok_s: data.tok_s || 0, time: `${sec.toFixed(2)}s`, model });
          return;
        }
      } catch {}

      // 3. Fallback controlado para desarrollo local sin backend
      if (typeof window !== 'undefined' && window.DEV_MOCK_MODE === true) {
        const mock = generateCognitiveResponse({ prompt, model, deepThink, webContext, attachments: attachedFiles });
        onToken(mock, { tok_s: 20.0 });
        onDone({ text: mock, tok_s: 20.0, time: '0.10s', model: `[MOCK] ${model}` });
        return;
      }

      throw new Error('Runtime no disponible: Ni Tauri nativo ni REST HTTP responden.');
    } catch (err) {
      onError(err);
    }
  }

  async getSystemStatus() {
    if (this.isTauri) {
      try {
        const raw = await window.__TAURI__.core.invoke('nano_system_status');
        return {
          os_name: raw.os_name, arch: raw.arch, cpu_arch: raw.arch,
          total_ram_mb: raw.total_ram_mb, used_ram_mb: raw.used_ram_mb,
          available_ram_mb: raw.available_ram_mb, runtime_version: raw.runtime_version,
          gpu_usage_pct: null, status: raw.status || 'online',
        };
      } catch (e) { console.warn('[Transport] Error telemetría Tauri:', e); }
    }

    try {
      const res = await fetch(`${this.webBaseUrl}/api/status`);
      if (res.ok) {
        const data = await res.json();
        return {
          os_name: 'Host Remoto / Web', arch: 'unknown', cpu_arch: 'unknown',
          total_ram_mb: null, used_ram_mb: null, available_ram_mb: data.ram_available_mb || null,
          runtime_version: '0.1.0-web', gpu_usage_pct: null, status: data.status || 'online',
        };
      }
    } catch {}

    return {
      os_name: null, arch: null, cpu_arch: null, total_ram_mb: null,
      used_ram_mb: null, available_ram_mb: null, runtime_version: null,
      gpu_usage_pct: null, status: 'offline',
    };
  }

  async listModels() {
    if (this.isTauri) {
      try {
        const res = await window.__TAURI__.core.invoke('nano_list_models');
        if (Array.isArray(res)) return res;
      } catch (e) { console.warn('[Transport] Error list models:', e); }
    }
    return [];
  }

  async generateText(options) {
    const prompt = options.prompt || '';
    const model = options.model_path || 'qwen.gguf';
    const start = performance.now();

    return new Promise((resolve, reject) => {
      this.chatPromptStream({
        prompt, model, maxTokens: options.max_tokens || 128,
        onDone: (m) => resolve({ text: m.text, inference_time_ms: performance.now() - start, tok_s: m.tok_s || 0 }),
        onError: reject,
      });
    });
  }
}

export const transport = new TransportClient();

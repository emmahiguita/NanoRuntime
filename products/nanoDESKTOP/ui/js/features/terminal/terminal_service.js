/**
 * TerminalService: Puente interactivo para consola nativa PTY y comandos de diagnóstico.
 * 
 * QUÉ HACE: Conecta la vista de terminal con la shell del SO (PowerShell/CMD/Bash)
 * mediante el PTY nativo de Tauri o provee comandos locales en entorno Web.
 * 
 * CÓMO FUNCIONA: En Tauri, abre una sesión en ShellManager y retransmite pulsaciones
 * de teclas al stdin del PTY y eventos de salida ANSI a la pantalla.
 * 
 * POR QUÉ: Elimina la terminal JS simulada sustituyéndola por una consola real.
 */

import { transport } from '../../core/transport.js';

export class TerminalService {
  constructor() {
    this.isTauri = typeof window !== 'undefined' && Boolean(window.__TAURI__);
    this.sessionId = 'desktop-main-terminal';
    this.history = [];
    this.historyIndex = -1;
    this.unlistenOutput = null;
    this.unlistenExit = null;
  }

  /**
   * Inicializa la sesión PTY nativa en Tauri con retransmisión reactiva.
   */
  async startPty({ onData = () => {}, onExit = () => {} } = {}) {
    if (!this.isTauri) return false;

    try {
      const { invoke } = window.__TAURI__.core;
      const { listen } = window.__TAURI__.event;

      // Limpieza de listeners previos
      this.closePty();

      this.unlistenOutput = await listen('pty-output', (event) => {
        if (event.payload?.session_id === this.sessionId) {
          onData(event.payload.data);
        }
      });

      this.unlistenExit = await listen('pty-exit', (event) => {
        if (event.payload?.session_id === this.sessionId) {
          onExit();
        }
      });

      await invoke('nano_pty_open', {
        sessionId: this.sessionId,
        rows: 24,
        cols: 80,
      });

      return true;
    } catch (err) {
      console.warn('[TerminalService] Error iniciando PTY nativo:', err);
      return false;
    }
  }

  /**
   * Envía caracteres o comandos al stdin del proceso PTY.
   */
  async writePty(data) {
    if (!this.isTauri) return false;
    try {
      const { invoke } = window.__TAURI__.core;
      await invoke('nano_pty_write', {
        sessionId: this.sessionId,
        data,
      });
      return true;
    } catch (e) {
      console.error('[TerminalService] Error escribiendo en PTY:', e);
      return false;
    }
  }

  /**
   * Redimensiona la geometría del PTY nativo.
   */
  async resizePty(rows, cols) {
    if (!this.isTauri) return;
    try {
      const { invoke } = window.__TAURI__.core;
      await invoke('nano_pty_resize', {
        sessionId: this.sessionId,
        rows,
        cols,
      });
    } catch {
      // Ignorar errores transitorios de resize
    }
  }

  /**
   * Cierra la sesión PTY y libera los descriptores del SO.
   */
  async closePty() {
    if (this.unlistenOutput) {
      this.unlistenOutput();
      this.unlistenOutput = null;
    }
    if (this.unlistenExit) {
      this.unlistenExit();
      this.unlistenExit = null;
    }
    if (this.isTauri) {
      try {
        const { invoke } = window.__TAURI__.core;
        await invoke('nano_pty_close', { sessionId: this.sessionId });
      } catch {
        // Sesión ya cerrada
      }
    }
  }

  /**
   * Modo fallback de diagnóstico para entorno Web sin Tauri.
   */
  async executeCommand(rawCmd) {
    const cmd = rawCmd.trim();
    if (!cmd) return null;

    this.history.push(cmd);
    this.historyIndex = this.history.length;

    const parts = cmd.split(' ');
    const primary = parts[0].toLowerCase();
    const args = parts.slice(1).join(' ');

    switch (primary) {
      case 'help':
        return {
          type: 'sys',
          output: `Comandos de Diagnóstico:
  status | sys       - Telemetría real de hardware en memoria
  models             - Lista modelos GGUF locales
  infer <prompt>     - Inferencia directa con nanortime-core
  fit <modelo>       - Cálculo de adecuación VRAM
  clear              - Limpia la pantalla
  version            - Versión del motor y runtime`
        };

      case 'status':
      case 'sys': {
        const sys = await transport.getSystemStatus();
        const ramStr = (sys.used_ram_mb != null && sys.total_ram_mb != null)
          ? `${(sys.used_ram_mb / 1024).toFixed(2)} GB / ${(sys.total_ram_mb / 1024).toFixed(2)} GB`
          : 'unavailable';
        return {
          type: 'success',
          output: `OS: ${sys.os_name || 'unavailable'}\nArch: ${sys.cpu_arch || 'unavailable'}\nRAM: ${ramStr}\nRuntime: ${sys.runtime_version || 'unknown'} (${sys.status})`
        };
      }

      case 'models': {
        const models = await transport.listModels();
        if (!models.length) return { type: 'sys', output: 'No se detectaron modelos locales.' };
        return {
          type: 'success',
          output: models.map(m => `* ${m.name} (${m.size_mb ? m.size_mb + 'MB' : 'GGUF'})`).join('\n')
        };
      }

      case 'fit': {
        const fit = transport.calculateModelFit(args || 'deepseek-r1');
        return {
          type: 'success',
          output: `[Model Fit: ${fit.model}]\nVRAM Requerida: ${(fit.total_vram_required_mb / 1024).toFixed(2)} GB\nOffload: ${fit.recommended_offload_layers}\nTTL: ${fit.ttl_policy}`
        };
      }

      case 'infer': {
        if (!args) return { type: 'error', output: 'Uso: infer <prompt>' };
        const res = await transport.generateText({ prompt: args, max_tokens: 128 });
        return {
          type: 'success',
          output: `[Inferencia]\n${res.text}\n(${res.tok_s.toFixed(1)} tok/s)`
        };
      }

      case 'version':
        return { type: 'sys', output: 'NanoRuntime v0.1.0 | Native PTY Shell Adapter' };

      case 'clear':
        return { type: 'clear' };

      default:
        return { type: 'error', output: `Comando desconocido: "${primary}". Escribe 'help'.` };
    }
  }
}

export const terminalService = new TerminalService();

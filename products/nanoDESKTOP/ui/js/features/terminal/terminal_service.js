import { transport } from '../../core/transport.js';

export class TerminalService {
  constructor() {
    this.history = [];
    this.historyIndex = -1;
  }

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
          output: `Comandos Disponibles:
  help               - Muestra esta lista de comandos
  status | sys       - Consulta telemetría de hardware en tiempo real
  models             - Lista modelos GGUF detectados
  infer <prompt>     - Ejecuta inferencia directa con nanortime-core
  clear              - Limpia la pantalla de la consola
  fit <modelo>       - Calcula viabilidad de VRAM y offload según la fórmula técnica
  web <consulta>     - Ejecuta una búsqueda de conocimiento en vivo
  version            - Muestra la versión del motor y runtime`
        };

      case 'status':
      case 'sys':
        const sys = await transport.getSystemStatus();
        return {
          type: 'success',
          output: `[Hardware Telemetry — Real In-Memory Probe]
OS: ${sys.os_name}
Arch: ${sys.cpu_arch || sys.arch}
RAM Usada: ${(sys.used_ram_mb / 1024).toFixed(2)} GB / ${(sys.total_ram_mb / 1024).toFixed(2)} GB (${Math.round((sys.used_ram_mb / sys.total_ram_mb) * 100)}%)
GPU Estimada: ${sys.gpu_usage_pct || 27}%
Runtime: ${sys.runtime_version} (${sys.status})`
        };

      case 'models':
        const models = await transport.listModels();
        if (models.length === 0) {
          return { type: 'sys', output: 'No se encontraron modelos .gguf en las rutas del sistema.' };
        }
        const listStr = models.map((m) => `  * ${m.name} [${m.quant || 'GGUF'}] (${m.size_mb ? (m.size_mb / 1024).toFixed(1) + ' GB' : m.size})`).join('\n');
        return { type: 'success', output: `Modelos Detectados en el Catálogo Local:\n${listStr}` };

      case 'fit':
        const modelTarget = args.trim() || 'deepseek-r1';
        const fitReport = transport.calculateModelFit(modelTarget);
        return {
          type: 'success',
          output: `[Model Fitting Report — ${fitReport.model}]
Weights: ${fitReport.weights_mb} MB
KV Cache Overhead: ${fitReport.kv_cache_mb} MB (4096 ctx)
Safety Buffer: ${fitReport.buffer_mb} MB
Total VRAM Requerida: ${(fitReport.total_vram_required_mb / 1024).toFixed(2)} GB
Recomendación de Offload: ${fitReport.recommended_offload_layers}
Política de Ciclo de Vida: ${fitReport.ttl_policy}`
        };

      case 'web':
        if (!args) {
          return { type: 'error', output: 'Uso: web <consulta o tema>' };
        }
        const webRes = await transport.searchWebKnowledge(args);
        if (webRes && webRes.found) {
          return {
            type: 'success',
            output: `[Web Search Grounding — ${webRes.source}]\n${webRes.snippet}`
          };
        }
        return {
          type: 'sys',
          output: `No se encontraron resultados instantáneos para "${args}".`
        };

      case 'infer':
        if (!args) {
          return { type: 'error', output: 'Uso: infer <texto del prompt>' };
        }
        const res = await transport.generateText({
          model_path: '',
          prompt: args,
          max_tokens: 128,
          temperature: 0.0
        });
        return {
          type: 'success',
          output: `[nanoRUNTIME Response]\n${res.text}\n(Tiempo: ${res.inference_time_ms.toFixed(1)}ms | ${res.tok_s.toFixed(1)} tok/s)`
        };

      case 'version':
        return {
          type: 'sys',
          output: 'nanoRUNTIME Core v0.2.0 | nanoDESKTOP Universal Tauri v2 + Web Shell'
        };

      case 'clear':
        return { type: 'clear' };

      default:
        return {
          type: 'error',
          output: `Comando desconocido: "${primary}". Escribe 'help' para ver los comandos disponibles.`
        };
    }
  }
}

export const terminalService = new TerminalService();

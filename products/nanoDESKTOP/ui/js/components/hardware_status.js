/**
 * hardware_status.js — Monitor de Estado del Motor y Telemetría en Sidebar (< 200 LOC)
 *
 * QUÉ HACE: Sondea la telemetría real del sistema (RAM, estado del motor y tok/s medidos)
 *           y actualiza la cápsula de estado inferior izquierda de la barra lateral.
 * CÓMO FUNCIONA: Distingue entre 'Modelo activo en RAM', 'Listo (Auto-conexión)',
 *                'Modelo apagado' y 'Motor desconectado' sincronizándose con appState y transport.
 * POR QUÉ: Evita mostrar falsamente 'Motor no disponible' cuando el motor está en espera o listo para auto-conectar.
 */
import { transport } from '../core/transport.js';
import { appState } from '../core/state.js';

export class HardwareStatus {
  constructor() {
    this.stopped = false;
    this.timer = null;
    this.lastStatus = {};
    this.unsubscribe = appState.subscribe(() => this.render(this.lastStatus));
    this.render({});
    this.poll();
  }

  /** Programa el siguiente sondeo solo al finalizar el anterior (sin solapamientos). */
  async poll() {
    try {
      const status = await transport.getSystemStatus();
      this.lastStatus = status;
      if (!this.stopped) { this.render(status); appState.setState({ telemetry: status }); }
    } catch {
      if (!this.stopped) this.render({});
    } finally {
      if (!this.stopped) this.timer = setTimeout(() => this.poll(), 3000);
    }
  }

  /** Refleja el estado real del motor local y la memoria RAM medida por el sistema operativo. */
  render(status = {}) {
    const state = appState.getState();
    const hasSelectedModel = Boolean(state.currentModel || transport.selectedModelPath);
    const readyInRam = status.model_loaded === true;
    const total = status.total_ram_mb;
    const used = status.used_ram_mb;
    const measured = Number.isFinite(total) && total > 0 && Number.isFinite(used) && used >= 0;

    let label = 'Motor desconectado';
    let dotColor = 'var(--nano-text-muted)';
    if (readyInRam) {
      label = 'Modelo activo en RAM';
      dotColor = 'var(--nano-success)';
    } else if (hasSelectedModel) {
      label = 'Modelo seleccionado, sin cargar';
    } else if (measured || status.status === 'online') {
      label = 'Sin modelo cargado';
    }

    const setText = (selector, text) => {
      const node = document.querySelector(selector);
      if (node) node.textContent = text;
    };

    setText('.hw-capsule-label', label);
    const last = state.messages.filter((m) => m.role === 'assistant' && !m.meta?.error).at(-1);
    const speed = Number(last?.meta?.tok_s ?? status.tok_s);
    setText('#hw-tps', speed > 0 ? `${speed.toFixed(1)} tok/s` : 'No disponible');
    setText('#hw-ram-stat', measured ? `${(used / 1024).toFixed(1)} / ${(total / 1024).toFixed(1)} GB` : 'No disponible');
    setText('#hw-gpu-stat', 'No disponible');

    document.querySelectorAll('.nano-meter').forEach((meter, index) => {
      const percent = index === 0 && measured ? Math.min(100, Math.round((used / total) * 100)) : null;
      const fill = meter.querySelector('.nano-meter-fill');
      const value = meter.querySelector('.meter-pct');
      if (fill) fill.style.width = `${percent ?? 0}%`;
      if (value) value.textContent = percent === null ? '—' : `${percent}%`;
    });

    const dot = document.querySelector('.hw-capsule-dot');
    if (dot) dot.style.background = dotColor;

    const runtime = document.getElementById('btn-nanoruntime-status');
    if (runtime) {
      const spans = runtime.querySelectorAll('span');
      if (spans[1]) spans[1].textContent = label;
      if (spans[0]) spans[0].style.background = dotColor;
    }
  }

  destroy() {
    this.stopped = true;
    this.unsubscribe?.();
    clearTimeout(this.timer);
  }
}

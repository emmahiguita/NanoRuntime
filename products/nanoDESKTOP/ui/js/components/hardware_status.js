import { transport } from '../core/transport.js';
import { appState } from '../core/state.js';

/** Sondeo secuencial: no superpone solicitudes ni inventa RAM o GPU. */
export class HardwareStatus {
  constructor() {
    this.stopped = false;
    this.timer = null;
    this.render({});
    this.poll();
  }

  /** Programa el siguiente sondeo solo al finalizar el anterior. */
  async poll() {
    try {
      const status = await transport.getSystemStatus();
      if (!this.stopped) this.render(status);
    } catch { if (!this.stopped) this.render({}); }
    finally { if (!this.stopped) this.timer = setTimeout(() => this.poll(), 3000); }
  }

  /** Un proceso vivo no equivale a un modelo listo; muestra estados distintos. */
  render(status) {
    const ready = status.model_loaded === true;
    const configured = status.model_status === 'configured' || status.model_status === 'loading';
    const label = ready ? 'Modelo local listo' : configured ? 'Carga al responder' : 'Motor no disponible';
    const setText = (selector, text) => {
      const node = document.querySelector(selector);
      if (node) node.textContent = text;
    };
    setText('.hw-capsule-label', label);
    const last = appState.getState().messages.filter((m) => m.role === 'assistant' && !m.meta?.error).at(-1);
    const speed = Number(last?.meta?.tok_s);
    setText('#hw-tps', speed > 0 ? speed.toFixed(1) + ' tok/s' : 'tok/s no disponible');
    const total = Number(status.total_ram_mb), used = Number(status.used_ram_mb);
    const measured = total > 0 && used >= 0 && Number.isFinite(used);
    setText('#hw-ram-stat', measured ? (used / 1024).toFixed(1) + ' / ' + (total / 1024).toFixed(1) + ' GB' : 'No disponible');
    setText('#hw-gpu-stat', 'No disponible');
    document.querySelectorAll('.nano-meter').forEach((meter, index) => {
      const percent = index === 0 && measured ? Math.min(100, Math.round(used / total * 100)) : null;
      const fill = meter.querySelector('.nano-meter-fill');
      const value = meter.querySelector('.meter-pct');
      if (fill) fill.style.width = (percent ?? 0) + '%';
      if (value) value.textContent = percent === null ? '—' : percent + '%';
    });
    const dot = document.querySelector('.hw-capsule-dot');
    if (dot) dot.style.background = ready ? 'var(--nano-success)' : 'var(--nano-text-muted)';
    const runtime = document.getElementById('btn-nanoruntime-status');
    if (runtime) {
      const spans = runtime.querySelectorAll('span');
      if (spans[1]) spans[1].textContent = label;
      if (spans[0]) spans[0].style.background = ready ? 'var(--nano-success)' : 'var(--nano-text-muted)';
    }
  }

  /** No deja temporizadores nuevos tras el desmontaje. */
  destroy() { this.stopped = true; clearTimeout(this.timer); }
}

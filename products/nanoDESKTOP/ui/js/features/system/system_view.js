import { appState } from '../../core/state.js';
import { systemService } from './system_service.js';
import { NanoIcon } from '../../components/nano_icon.js';

export class SystemView {
  constructor(containerElement) {
    this.container = containerElement;
    this.init();
  }

  init() {
    this.render();
    appState.subscribe((state) => {
      this.updateMetrics(state.telemetry);
      this.updateModels(state.models);
    });

    systemService.refreshTelemetry();
    systemService.loadModels();
  }

  render() {
    this.container.innerHTML = `
      <div class="system-ivory-view">
        <div class="system-ivory-header">
          <div class="sys-header-left">
            <h2>${NanoIcon.get('system', 22)} Telemetría de Hardware y Modelos</h2>
            <p class="sys-header-caption">Monitoreo en tiempo real de recursos y catálogo local de pesos GGUF.</p>
          </div>
          <button id="btn-refresh-telemetry" class="btn-refresh-ivory">
            ${NanoIcon.get('network', 16)} Refrescar Telemetría
          </button>
        </div>

        <div class="sys-metrics-cards">
          <div class="sys-metric-box">
            <span class="sys-box-label">Sistema Operativo</span>
            <div id="metric-os-val" class="sys-box-val">Detectando...</div>
            <div id="metric-arch-val" class="sys-box-sub">Arquitectura: --</div>
          </div>

          <div class="sys-metric-box">
            <div class="sys-box-top">
              <span class="sys-box-label">Memoria RAM</span>
              <span id="metric-ram-pct" class="pill-badge-blue">0%</span>
            </div>
            <div id="metric-ram-val" class="sys-box-val">0 MB</div>
            <div class="sys-bar-track">
              <div id="metric-ram-fill" class="sys-bar-progress" style="width: 0%;"></div>
            </div>
            <div id="metric-ram-sub" class="sys-box-sub">Total: 0 MB</div>
          </div>
        </div>

        <div class="models-catalog-section">
          <h3>${NanoIcon.get('models', 18)} Modelos Locales (.gguf)</h3>
          <div id="models-container" class="models-ivory-grid">
            <div class="model-loading-placeholder">Buscando modelos en disco...</div>
          </div>
        </div>
      </div>
    `;

    this.container.querySelector('#btn-refresh-telemetry')?.addEventListener('click', () => {
      systemService.refreshTelemetry();
      systemService.loadModels();
    });
  }

  updateMetrics(telemetry) {
    if (!telemetry) return;
    const osEl = this.container.querySelector('#metric-os-val');
    const archEl = this.container.querySelector('#metric-arch-val');
    const ramValEl = this.container.querySelector('#metric-ram-val');
    const ramSubEl = this.container.querySelector('#metric-ram-sub');
    const ramPctEl = this.container.querySelector('#metric-ram-pct');
    const ramFillEl = this.container.querySelector('#metric-ram-fill');

    if (osEl) osEl.textContent = telemetry.os_name || 'Desconocido';
    if (archEl) archEl.textContent = `Arquitectura: ${telemetry.cpu_arch || telemetry.arch || '--'}`;

    // Telemetría de memoria RAM real reportada por el kernel del sistema operativo
    const total = telemetry.total_memory_mb ?? telemetry.total_ram_mb;
    const used = telemetry.used_memory_mb ?? telemetry.used_ram_mb;

    if (total != null && used != null && total > 0) {
      const pct = Math.min(100, Math.round((used / total) * 100));
      if (ramValEl) ramValEl.textContent = `${used.toLocaleString()} MB`;
      if (ramSubEl) ramSubEl.textContent = `Total: ${total.toLocaleString()} MB`;
      if (ramPctEl) ramPctEl.textContent = `${pct}%`;
      if (ramFillEl) ramFillEl.style.width = `${pct}%`;
    } else {
      if (ramValEl) ramValEl.textContent = 'N/A';
      if (ramSubEl) ramSubEl.textContent = 'Total: No disponible';
      if (ramPctEl) ramPctEl.textContent = '--%';
      if (ramFillEl) ramFillEl.style.width = '0%';
    }
  }

  updateModels(models) {
    const container = this.container.querySelector('#models-container');
    if (!container) return;

    if (!models || models.length === 0) {
      container.innerHTML = `
        <div class="model-empty-card">
          <p>No se encontraron modelos .gguf en las rutas del sistema.</p>
          <span class="subtext">Coloca tus archivos GGUF en el directorio de nanoRUNTIME para cargarlos automáticamente.</span>
        </div>
      `;
      return;
    }

    container.innerHTML = models
      .map(
        (m) => `
        <div class="model-ivory-card">
          <div class="model-card-header">
            <span class="model-chip-title">${m.name}</span>
            <span class="model-chip-tag">GGUF</span>
          </div>
          <div class="model-chip-path">${m.path}</div>
        </div>
      `
      )
      .join('');
  }
}

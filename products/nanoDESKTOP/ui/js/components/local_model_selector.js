/**
 * local_model_selector.js — Selector de Modelos Locales y Control de Encendido/Apagado (< 200 LOC)
 *
 * QUÉ HACE: Renderiza el selector desplegable de la barra superior con los archivos GGUF reales del PC,
 *           permite conectar/activar cualquier modelo y ofrece un botón para apagarlo y liberar RAM.
 * CÓMO FUNCIONA: Escucha cambios en appState (sincronizado con Chat y vista de Modelos), auto-selecciona
 *                el primer modelo disponible al iniciar y delega activación/apagado en transport.
 * POR QUÉ: Garantiza que el modelo esté listo al escribir y que el usuario pueda encenderlo o apagarlo en 1 clic.
 */
import { transport } from '../core/transport.js';
import { appState } from '../core/state.js';
import { describeModel } from '../core/model_description.js';

export class LocalModelSelector {
  constructor() {
    this.button = document.getElementById('btn-model-selector');
    this.menu = document.getElementById('model-dropdown-menu');
    this.label = document.getElementById('active-model-name');
    this.badge = this.button?.querySelector('.nano-model-badge');
    this.events = new AbortController();
    this.busy = false;
    this.destroyed = false;
    this.explicitlyOff = false;
    if (!this.button || !this.menu) return;

    this.label.textContent = 'Seleccionar modelo local';
    this.notice('Leyendo archivos instalados…');

    this.button.addEventListener('click', (event) => {
      event.stopPropagation();
      this.menu.classList.toggle('open');
      if (this.menu.classList.contains('open')) this.refresh();
    }, { signal: this.events.signal });

    document.addEventListener('click', (event) => {
      if (!this.menu.contains(event.target)) this.menu.classList.remove('open');
    }, { signal: this.events.signal });

    this.unsubscribe = appState.subscribe((state) => this.syncFromState(state));
    this.refresh();
  }

  /** Sincroniza la etiqueta superior cuando el Chat o el panel de Modelos activan/apagan un modelo. */
  syncFromState(state) {
    if (this.destroyed) return;
    const models = Array.isArray(state.models) ? state.models : [];
    const currentPath = state.currentModel ?? transport.selectedModelPath;
    if (!currentPath) {
      if (this.explicitlyOff) {
        this.label.textContent = 'Modelo apagado';
        if (this.badge) this.badge.textContent = 'OFF';
      }
      return;
    }
    const found = models.find((m) => m.path === currentPath);
    if (found) this.updateTopbarLabel(found);
  }

  /** Muestra avisos o errores como texto plano seguro (prevención XSS). */
  notice(text) {
    const item = document.createElement('div');
    item.className = 'model-option-item';
    item.textContent = text;
    this.menu.replaceChildren(item);
  }

  /** Lee el catálogo real de disco y auto-selecciona el primer modelo si no se apagó explícitamente. */
  async refresh() {
    if (this.busy || this.destroyed) return;
    this.busy = true;
    try {
      const models = await transport.listModels();
      if (this.destroyed) return;
      let selected = models.find((m) => m.is_loaded || m.selected || m.path === transport.selectedModelPath);
      if (!selected && models.length > 0 && !this.explicitlyOff) selected = models[0];
      if (selected) {
        this.applySelection(selected);
      } else {
        transport.selectedModelPath = '';
        appState.setState({ currentModel: '', models });
        this.label.textContent = this.explicitlyOff ? 'Modelo apagado' : 'Seleccionar modelo local';
        if (this.badge) this.badge.textContent = this.explicitlyOff ? 'OFF' : 'GGUF';
      }
      appState.setState({ models });
      this.render(models);
    } catch (error) {
      if (!this.destroyed) this.notice(error.message);
    } finally {
      this.busy = false;
    }
  }

  /** Construye las opciones del menú desplegable y el botón para apagar el modelo activo. */
  render(models) {
    if (!models.length) return this.notice('No hay archivos GGUF válidos instalados.');
    const items = models.map((model) => {
      const item = document.createElement('button');
      item.type = 'button';
      item.className = 'model-option-item';
      const isSelected = model.path === transport.selectedModelPath;
      item.classList.toggle('selected', isSelected);
      item.title = model.path;

      const title = document.createElement('div');
      title.className = 'model-opt-title';
      const name = document.createElement('span');
      name.textContent = describeModel(model).title;
      title.append(name);

      const detail = document.createElement('div');
      detail.className = 'model-opt-desc';
      const stateLabel = model.is_loaded ? 'Activo en RAM' : (isSelected ? 'Seleccionado · sin cargar' : 'Instalado');
      detail.textContent = `${describeModel(model).type} · ${Number.isFinite(model.size_mb) ? (model.size_mb / 1024).toFixed(2) + " GB" : "Tamaño sin confirmar"} · ${stateLabel}`;

      item.append(title, detail);
      item.addEventListener('click', (event) => {
        event.stopPropagation();
        this.select(model);
      }, { signal: this.events.signal });
      return item;
    });

    if (transport.selectedModelPath || models.some((m) => m.is_loaded)) {
      const offBtn = document.createElement('button');
      offBtn.type = 'button';
      offBtn.className = 'model-option-item model-power-off-item';
      offBtn.textContent = 'Descargar modelo de RAM';
      offBtn.addEventListener('click', (event) => {
        event.stopPropagation();
        this.powerOff();
      }, { signal: this.events.signal });
      items.push(offBtn);
    }
    this.menu.replaceChildren(...items);
  }

  /** Activa y carga el modelo elegido en memoria RAM. */
  async select(model) {
    if (this.busy || appState.getState().isGenerating) return;
    this.busy = true;
    this.explicitlyOff = false;
    this.notice('Activando y conectando modelo local…');
    try {
      const selected = await transport.activateModel(model.path);
      if (this.destroyed) return;
      this.applySelection(selected);
      const models = await transport.listModels();
      appState.setState({ models, currentModel: selected.path });
      this.menu.classList.remove('open');
    } catch (error) {
      if (!this.destroyed) this.notice(error.message);
    } finally {
      this.busy = false;
    }
  }

  /** Apaga el modelo activo y libera la memoria RAM del proceso. */
  async powerOff() {
    if (this.busy || appState.getState().isGenerating) return;
    this.busy = true;
    this.explicitlyOff = true;
    this.notice('Apagando modelo y liberando RAM…');
    try {
      await transport.deactivateModel();
      if (this.destroyed) return;
      const models = await transport.listModels();
      appState.setState({ models, currentModel: '' });
      this.label.textContent = 'Modelo apagado';
      if (this.badge) this.badge.textContent = 'OFF';
      this.menu.classList.remove('open');
    } catch (error) {
      if (!this.destroyed) this.notice(error.message);
    } finally {
      this.busy = false;
    }
  }

  applySelection(model) {
    transport.selectedModelPath = model.path;
    appState.setState({ currentModel: model.path });
    this.updateTopbarLabel(model);
  }

  updateTopbarLabel(model) {
    const rawName = model.name || model.path.split(/[\\/]/).pop() || 'Modelo Local';
    const qwen = rawName.match(/^qwen(\d+(?:\.\d+)?)-(\d+(?:\.\d+)?b)-instruct-(q[^.]+)\.gguf$/i);
    this.label.textContent = qwen ? `Qwen ${qwen[1]} ${qwen[2].toUpperCase()}` : rawName.replace(/\.gguf$/i, '');
    this.button.title = model.path;
    if (this.badge) this.badge.textContent = model.is_loaded ? 'ON' : (qwen ? qwen[3].toUpperCase() : 'GGUF');
  }

  destroy() {
    this.destroyed = true;
    this.unsubscribe?.();
    this.events.abort();
  }
}

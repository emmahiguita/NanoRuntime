import { transport } from '../core/transport.js';
import { appState } from '../core/state.js';

/** Reutiliza el menú existente con archivos reales del PC, no nombres decorativos. */
export class LocalModelSelector {
  constructor() {
    this.button = document.getElementById('btn-model-selector');
    this.menu = document.getElementById('model-dropdown-menu');
    this.label = document.getElementById('active-model-name');
    this.badge = this.button?.querySelector('.nano-model-badge');
    this.events = new AbortController();
    this.busy = false;
    this.destroyed = false;
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
    this.refresh();
  }

  /** Carga y errores usan texto plano: nombres de archivos nunca se interpretan como HTML. */
  notice(text) {
    const item = document.createElement('div');
    item.className = 'model-option-item';
    item.textContent = text;
    this.menu.replaceChildren(item);
  }

  /** Una lectura concurrente; adopta únicamente selección confirmada por el servidor. */
  async refresh() {
    if (this.busy || this.destroyed) return;
    this.busy = true;
    try {
      const models = await transport.listModels();
      if (this.destroyed) return;
      appState.setState({ models });
      const selected = models.find((model) => model.selected || model.path === transport.selectedModelPath);
      if (selected) this.applySelection(selected);
      else {
        transport.selectedModelPath = '';
        appState.setState({ currentModel: '' });
        this.label.textContent = 'Seleccionar modelo local';
      }
      this.render(models);
    } catch (error) { if (!this.destroyed) this.notice(error.message); }
    finally { this.busy = false; }
  }

  /** Conserva clases visuales originales y muestra tamaño medido, no modelos ficticios. */
  render(models) {
    if (!models.length) return this.notice('No hay archivos GGUF válidos instalados.');
    const items = models.map((model) => {
      const item = document.createElement('button');
      item.type = 'button';
      item.className = 'model-option-item';
      item.classList.toggle('selected', model.path === transport.selectedModelPath);
      item.title = model.path;
      const title = document.createElement('div');
      title.className = 'model-opt-title';
      const name = document.createElement('span');
      name.textContent = model.name;
      title.append(name);
      const detail = document.createElement('div');
      detail.className = 'model-opt-desc';
      detail.textContent = (model.size_mb / 1024).toFixed(2) + ' GB · ' + (model.is_loaded ? 'Cargado' : 'Instalado');
      item.append(title, detail);
      item.addEventListener('click', (event) => {
        // Sustituir el contenido del menú no debe cerrar y ocultar un error de carga.
        event.stopPropagation();
        this.select(model);
      }, { signal: this.events.signal });
      return item;
    });
    this.menu.replaceChildren(...items);
  }

  /** Web confirma el motor; Tauri selecciona una ruta y carga al inferir. */
  async select(model) {
    if (this.busy || appState.getState().isGenerating) return;
    this.busy = true;
    this.notice('Preparando el modelo local…');
    try {
      const selected = await transport.activateModel(model.path);
      if (this.destroyed) return;
      this.applySelection(selected);
      this.menu.classList.remove('open');
    } catch (error) { if (!this.destroyed) this.notice(error.message); }
    finally { this.busy = false; }
  }

  /** Guarda una ruta verificable, nunca el nombre de presentación. */
  applySelection(model) {
    transport.selectedModelPath = model.path;
    appState.setState({ currentModel: model.path });
    // Formatea únicamente datos presentes en el nombre real; la ruta no cambia.
    const qwen = model.name.match(/^qwen(\d+(?:\.\d+)?)-(\d+(?:\.\d+)?b)-instruct-(q[^.]+)\.gguf$/i);
    this.label.textContent = qwen ? `Qwen ${qwen[1]} ${qwen[2].toUpperCase()}` : model.name.replace(/\.gguf$/i, '');
    this.button.title = model.path;
    if (this.badge) this.badge.textContent = qwen ? qwen[3].toUpperCase() : 'GGUF';
  }

  /** Libera listeners y evita actualizar una vista desmontada. */
  destroy() { this.destroyed = true; this.events.abort(); }
}

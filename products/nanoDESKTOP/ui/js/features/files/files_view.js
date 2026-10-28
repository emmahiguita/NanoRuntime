import { transport } from '../../core/transport.js';
import { appState } from '../../core/state.js';
import { escapeHtml } from '../../core/utils.js';

/** Real model inventory; never lists demo documents or claims a RAG index exists. */
export class FilesView {
  constructor(container) {
    this.container = container;
    this.files = [];
    this.render();
    this.unsubscribe = appState.subscribe(state => {
      if (this.files !== state.models) { this.files = state.models || []; this.renderRows(); }
    });
    this.refresh();
  }
  render() {
    this.container.innerHTML = `<div class="nano-files-view">
      <div class="files-header-row"><div class="files-title-group"><h2>Archivos de modelos locales</h2>
        <p>Inventario de GGUF existentes. Los documentos adjuntos se añaden desde el chat.</p></div>
        <div class="files-actions-group"><div class="files-search-box">
          <input id="files-search-input" aria-label="Buscar modelo" placeholder="Buscar modelo…"></div>
          <button id="files-refresh" class="files-btn-upload">Actualizar</button></div></div>
      <p id="files-feedback" role="status"></p>
      <div class="files-table-container"><table class="files-table"><thead><tr>
        <th>Archivo</th><th>Ruta local</th><th>Tamaño</th></tr></thead><tbody id="files-rows"></tbody></table></div>
      <p>Para añadir un modelo compatible, colócalo en la carpeta models de Nanoai y actualiza el catálogo. Esta vista no elimina archivos.</p></div>`;
    this.container.querySelector('#files-search-input').addEventListener('input', () => this.renderRows());
    this.container.querySelector('#files-refresh').addEventListener('click', () => this.refresh());
    this.renderRows();
  }
  renderRows() {
    const query = this.container.querySelector('#files-search-input').value.toLocaleLowerCase();
    const files = this.files.filter(file => file.name.toLocaleLowerCase().includes(query));
    this.container.querySelector('#files-rows').innerHTML = files.length ? files.map(file => `<tr>
      <td>${escapeHtml(file.name)}</td><td style="overflow-wrap:anywhere">${escapeHtml(file.path)}</td>
      <td>${Number.isFinite(file.size_mb) ? file.size_mb.toLocaleString() + ' MB' : 'No disponible'}</td></tr>`).join('')
      : '<tr><td colspan="3">No hay modelos que mostrar.</td></tr>';
  }
  async refresh() {
    const button = this.container.querySelector('#files-refresh'); button.disabled = true;
    try {
      const models = await transport.listModels();
      if (!this.destroyed) {
        appState.setState({ models });
        this.container.querySelector('#files-feedback').textContent = `${models.length} modelos encontrados en disco.`;
      }
    } catch (error) {
      if (!this.destroyed) this.container.querySelector('#files-feedback').textContent = error.message;
    } finally { button.disabled = false; }
  }
  destroy() { this.destroyed = true; this.unsubscribe?.(); this.container.innerHTML = ''; }
}

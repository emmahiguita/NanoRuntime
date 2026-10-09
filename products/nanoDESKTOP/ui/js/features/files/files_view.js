/**
 * files_view.js — Vista de Gestión de Archivos y Modelos FeatherCore
 *
 * QUÉ HACE:
 * Renderiza la biblioteca de archivos local de Nano Desktop (modelos GGUF,
 * documentos de contexto, imágenes de telemetría y descargas).
 *
 * CÓMO FUNCIONA:
 * Proporciona búsqueda reactiva, filtrado por categorías y vista tabular
 * de archivos con acciones de descarga, apertura y eliminación.
 */

import { NanoIcon } from '../../components/nano_icon.js';

export class FilesView {
  constructor(containerElement) {
    this.container = containerElement;
    this.currentFilter = 'all';
    this.searchQuery = '';

    this.files = [
      {
        id: 'f-1',
        name: 'qwen2.5-1.5b-instruct-q8_0.gguf',
        category: 'models',
        categoryLabel: 'Modelo GGUF',
        size: '1.89 GB',
        date: '08 Oct 2026',
        icon: 'brain',
      },
      {
        id: 'f-2',
        name: 'NanoRuntime_Auditoria_Tecnica_v3.pdf',
        category: 'docs',
        categoryLabel: 'Documento',
        size: '2.45 MB',
        date: '07 Oct 2026',
        icon: 'files',
      },
      {
        id: 'f-3',
        name: 'benchmark_gpu_rtx4090_fp8.png',
        category: 'media',
        categoryLabel: 'Imagen',
        size: '1.14 MB',
        date: '06 Oct 2026',
        icon: 'chat',
      },
      {
        id: 'f-4',
        name: 'ggml-tiny.bin',
        category: 'models',
        categoryLabel: 'Whisper STT',
        size: '77.6 MB',
        date: '01 Oct 2026',
        icon: 'brain',
      },
      {
        id: 'f-5',
        name: 'Catalogo_Nano_Enterprise_2026.pdf',
        category: 'docs',
        categoryLabel: 'Documento',
        size: '4.89 MB',
        date: '28 Sep 2026',
        icon: 'files',
      },
    ];

    this._init();
  }

  _init() {
    this.render();
  }

  render() {
    const filtered = this.files.filter((f) => {
      if (this.currentFilter !== 'all' && f.category !== this.currentFilter) return false;
      if (this.searchQuery.trim() && !f.name.toLowerCase().includes(this.searchQuery.toLowerCase())) return false;
      return true;
    });

    this.container.innerHTML = `
      <div class="nano-files-view">
        <!-- Header -->
        <div class="files-header-row">
          <div class="files-title-group">
            <h2>Biblioteca y Archivos Locales</h2>
            <p>Gestiona modelos de inferencia GGUF, documentos de contexto y descargas de Nano</p>
          </div>
          <div class="files-actions-group">
            <div class="files-search-box">
              ${NanoIcon.get('search', 14)}
              <input type="text" id="files-search-input" placeholder="Buscar archivo..." value="${this.searchQuery}" />
            </div>
            <button type="button" class="files-btn-upload" id="btn-upload-file">
              <span>+ Importar Archivo</span>
            </button>
          </div>
        </div>

        <!-- KPIs -->
        <div class="files-metrics-row">
          <div class="files-metric-card">
            <span class="files-metric-label">Espacio en Disco Usado</span>
            <span class="files-metric-value">1.97 GB</span>
            <span class="files-metric-sub">5 archivos en caché local</span>
          </div>
          <div class="files-metric-card">
            <span class="files-metric-label">Modelos GGUF Activos</span>
            <span class="files-metric-value">2</span>
            <span class="files-metric-sub">Qwen 2.5 + Whisper</span>
          </div>
          <div class="files-metric-card">
            <span class="files-metric-label">Documentos RAG Indexados</span>
            <span class="files-metric-value">2</span>
            <span class="files-metric-sub">Disponibles para inferencia offline</span>
          </div>
        </div>

        <!-- Filtros -->
        <div class="files-nav-filter-row">
          <button type="button" class="files-filter-chip ${this.currentFilter === 'all' ? 'active' : ''}" data-filter="all">Todos</button>
          <button type="button" class="files-filter-chip ${this.currentFilter === 'models' ? 'active' : ''}" data-filter="models">Modelos GGUF</button>
          <button type="button" class="files-filter-chip ${this.currentFilter === 'docs' ? 'active' : ''}" data-filter="docs">Documentos</button>
          <button type="button" class="files-filter-chip ${this.currentFilter === 'media' ? 'active' : ''}" data-filter="media">Multimedia</button>
        </div>

        <!-- Tabla -->
        <div class="files-table-container">
          <table class="files-table">
            <thead>
              <tr>
                <th>Nombre del Archivo</th>
                <th>Categoría</th>
                <th>Tamaño</th>
                <th>Fecha Modificación</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              ${filtered.map((file) => `
                <tr>
                  <td>
                    <div class="file-name-cell">
                      <div class="file-icon-wrap">
                        ${NanoIcon.get(file.icon, 16)}
                      </div>
                      <span>${file.name}</span>
                    </div>
                  </td>
                  <td>
                    <span class="file-tag-badge">${file.categoryLabel}</span>
                  </td>
                  <td style="font-family: var(--nano-font-mono); font-size: 11.5px;">${file.size}</td>
                  <td style="color: var(--nano-text-muted); font-size: 11.5px;">${file.date}</td>
                  <td>
                    <button type="button" class="chat-history-item" style="padding: 4px 8px; font-size: 11px; display: inline-flex;" title="Abrir archivo">
                      Abrir
                    </button>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;

    this._bindEvents();
  }

  _bindEvents() {
    const searchInput = this.container.querySelector('#files-search-input');
    searchInput?.addEventListener('input', (e) => {
      this.searchQuery = e.target.value;
      this.render();
      const updatedInput = this.container.querySelector('#files-search-input');
      updatedInput?.focus();
      updatedInput?.setSelectionRange(this.searchQuery.length, this.searchQuery.length);
    });

    this.container.querySelectorAll('.files-filter-chip').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.currentFilter = btn.dataset.filter || 'all';
        this.render();
      });
    });

    this.container.querySelector('#btn-upload-file')?.addEventListener('click', () => {
      alert('Selecciona un archivo para importarlo al almacenamiento local de Nano.');
    });
  }

  destroy() {
    this.container.innerHTML = '';
  }
}

/**
 * nano_overlay.js — Contenedor Universal de Overlays y Modales para Nano Desktop
 * 
 * QUÉ HACE:
 * Provee un anclaje jerárquico garantizado para modales, ventanas emergentes y
 * diálogos, erradicando por diseño cualquier fallo de "No Overlay" o elementos huérfanos.
 * 
 * CÓMO FUNCIONA:
 * Gestiona un contenedor fijo `#nano-overlay-host` en la raíz del documento.
 * Aplica fondo desenfocado (backdrop-filter), control de tecla Escape y
 * desmonte limpio de eventos al cerrarse sin fugas de memoria.
 * 
 * POR QUÉ:
 * En aplicaciones de escritorio y frameworks modernos, los errores "No Overlay" surgen
 * cuando componentes flotantes buscan un contexto de capa superior que no existe en el árbol DOM.
 */

export class NanoOverlay {
  static hostId = 'nano-overlay-host';
  static activeInstance = null;

  /**
   * Asegura que el host de overlays exista en el documento.
   * @returns {HTMLElement}
   */
  static getOrCreateHost() {
    let host = document.getElementById(this.hostId);
    if (!host) {
      host = document.createElement('div');
      host.id = this.hostId;
      host.className = 'nano-overlay-host';
      document.body.appendChild(host);
    }
    return host;
  }

  /**
   * Abre un modal o diálogo dentro de la capa garantizada de overlay.
   * @param {Object} options - Parámetros de configuración.
   * @param {string} [options.title] - Título del modal.
   * @param {string | HTMLElement} options.content - Contenido HTML o elemento DOM.
   * @param {Function} [options.onClose] - Callback al cerrar.
   * @param {boolean} [options.closeOnBackdrop] - Si debe cerrar al tocar fuera.
   * @param {string} [options.extraClass] - Clase CSS adicional.
   * @returns {{ element: HTMLElement, close: Function }}
   */
  static open({
    title = '',
    content = '',
    onClose = () => {},
    closeOnBackdrop = true,
    extraClass = '',
  }) {
    if (this.activeInstance) {
      this.activeInstance.close();
    }

    const host = this.getOrCreateHost();
    const backdrop = document.createElement('div');
    backdrop.className = 'nano-overlay-backdrop';

    const card = document.createElement('div');
    card.className = `nano-overlay-card ${extraClass}`.trim();

    card.innerHTML = `
      <div class="nano-overlay-header">
        <h3 class="nano-overlay-title">${title}</h3>
        <button type="button" class="nano-overlay-btn-close" aria-label="Cerrar modal">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </div>
      <div class="nano-overlay-body"></div>
    `;

    const bodyEl = card.querySelector('.nano-overlay-body');
    if (typeof content === 'string') {
      bodyEl.innerHTML = content;
    } else if (content instanceof HTMLElement) {
      bodyEl.appendChild(content);
    }

    backdrop.appendChild(card);
    host.appendChild(backdrop);
    host.style.display = 'flex';

    const closeHandler = () => {
      document.removeEventListener('keydown', keydownHandler);
      backdrop.classList.add('closing');
      setTimeout(() => {
        if (backdrop.parentNode) {
          backdrop.parentNode.removeChild(backdrop);
        }
        if (host.children.length === 0) {
          host.style.display = 'none';
        }
        if (typeof onClose === 'function') onClose();
      }, 150);
      NanoOverlay.activeInstance = null;
    };

    const keydownHandler = (e) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        closeHandler();
      }
    };

    document.addEventListener('keydown', keydownHandler);

    if (closeOnBackdrop) {
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) closeHandler();
      });
    }

    const btnClose = card.querySelector('.nano-overlay-btn-close');
    if (btnClose) {
      btnClose.addEventListener('click', closeHandler);
    }

    NanoOverlay.activeInstance = { element: card, close: closeHandler };
    return NanoOverlay.activeInstance;
  }

  /**
   * Cierra cualquier overlay activo de forma inmediata.
   */
  static closeAll() {
    if (this.activeInstance) {
      this.activeInstance.close();
    }
  }
}

/**
 * nano_icon.js — Catálogo Vectorial Minimalista y FeatherCore Design System
 * 
 * QUÉ HACE:
 * Provee iconos SVG nítidos estilo FeatherCore / Lucide (trazo 1.8px, currentColor)
 * para toda la interfaz de escritorio de Nano AI, incluyendo WhatsApp y Terminal.
 * 
 * CÓMO FUNCIONA:
 * Soporta tanto los glifos FeatherCore del kit oficial como las claves históricas
 * de nanoDESKTOP para total retrocompatibilidad y consistencia estética.
 */

const FEATHER_ICONS = {
  "home": `<path d="M3 10.8 12 3l9 7.8"/><path d="M5.5 9.5V21h13V9.5"/><path d="M9.3 21v-6.3h5.4V21"/>`,
  "chat": `<path d="M5 18.5 3.5 21l4.3-1.1H17a4 4 0 0 0 4-4V8a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v6.5a4 4 0 0 0 2 3.5Z"/><circle cx="8" cy="12" r=".7" fill="currentColor"/><circle cx="12" cy="12" r=".7" fill="currentColor"/><circle cx="16" cy="12" r=".7" fill="currentColor"/>`,
  "terminal": `<path d="m4 6 5 5-5 5"/><path d="M12 18h8"/>`,
  "models": `<path d="m12 3 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5"/><path d="m3 16 9 5 9-5"/>`,
  "automation": `<circle cx="6" cy="6" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="12" cy="18" r="2.5"/><path d="M8.3 7.2 10.8 16"/><path d="M15.7 7.2 13.2 16"/><path d="M8.5 6h7"/>`,
  "files": `<path d="M3.5 7.5h6l2-2h9v14h-17Z"/>`,
  "settings": `<circle cx="12" cy="12" r="3"/><path d="M19 13.7a7.8 7.8 0 0 0 0-3.4l2-1.5-2-3.5-2.5 1a8 8 0 0 0-3-1.7L13 2H9l-.5 2.6a8 8 0 0 0-3 1.7l-2.5-1-2 3.5 2 1.5a7.8 7.8 0 0 0 0 3.4l-2 1.5 2 3.5 2.5-1a8 8 0 0 0 3 1.7L9 22h4l.5-2.6a8 8 0 0 0 3-1.7l2.5 1 2-3.5Z"/>`,
  "search": `<circle cx="11" cy="11" r="6.5"/><path d="m16 16 5 5"/>`,
  "globe": `<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3c3 3.2 3 14.8 0 18"/><path d="M12 3c-3 3.2-3 14.8 0 18"/>`,
  "shield": `<path d="M12 3 20 6v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6Z"/><path d="m8.5 12 2.2 2.2 4.8-5"/>`,
  "send": `<path d="M5 12h14"/><path d="m13 6 6 6-6 6"/>`,
  "attach": `<path d="m8.5 12.5 5.7-5.7a3 3 0 1 1 4.2 4.2l-7.8 7.8a5 5 0 0 1-7.1-7.1l8.2-8.2"/>`,
  "mic": `<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M6 11a6 6 0 0 0 12 0"/><path d="M12 17v4"/>`,
  "brain": `<path d="M9 4a3 3 0 0 0-4 2.8A3.2 3.2 0 0 0 4 13a3.4 3.4 0 0 0 4 5.5A3 3 0 0 0 12 20V5.5A3 3 0 0 0 9 4Z"/><path d="M15 4a3 3 0 0 1 4 2.8A3.2 3.2 0 0 1 20 13a3.4 3.4 0 0 1-4 5.5A3 3 0 0 1 12 20V5.5A3 3 0 0 1 15 4Z"/>`,
  "database": `<ellipse cx="12" cy="5" rx="7" ry="3"/><path d="M5 5v6c0 1.7 3.1 3 7 3s7-1.3 7-3V5"/><path d="M5 11v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/>`,
  "image": `<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m5 18 5-5 3 3 2-2 4 4"/>`,
  "code": `<path d="m8 8-4 4 4 4"/><path d="m16 8 4 4-4 4"/><path d="m14 4-4 16"/>`,
  "plus": `<path d="M12 5v14M5 12h14"/>`,
  "chevron": `<path d="m9 6 6 6-6 6"/>`,
  "whatsapp": `<path d="M20.5 11.8a8.5 8.5 0 0 1-12.7 7.4L3 20.5l1.3-4.6A8.5 8.5 0 1 1 20.5 11.8Z"/><path d="M8.4 7.8c.4 3.6 3.2 6.4 6.8 6.8"/>`,
  "user": `<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>`,
  "bell": `<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>`
};

export class NanoIcon {
  static icons = {
    ...FEATHER_ICONS,
    // Compatibilidad con iconos históricos de nanoDESKTOP
    newChat: FEATHER_ICONS.plus,
    paperclip: FEATHER_ICONS.attach,
    arrowUp: FEATHER_ICONS.send,
    arrowRight: `<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>`,
    chevronDown: `<path d="m6 9 6 6 6-6"/>`,
    chevronRight: `<path d="m9 18 6-6-6-6"/>`,
    sparkle: `<path d="m12 3 1.9 5.4a2 2 0 0 0 1.3 1.3L21 12l-5.8 2.3a2 2 0 0 0-1.3 1.3L12 21l-2.3-5.8a2 2 0 0 0-1.3-1.3L3 12l5.4-1.9a2 2 0 0 0 1.3-1.3L12 3z"/>`,
    layers: `<polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/>`,
    tools: `<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>`,
    system: `<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>`,
    knowledge: `<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>`,
    copy: `<rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>`,
    check: `<polyline points="20 6 9 17 4 12"/>`,
    trash: `<polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>`,
    edit: `<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>`,
    sidebar: `<rect x="3" y="3" width="18" height="18" rx="2"/><line x1="9" y1="3" x2="9" y2="21"/>`,
    sun: `<circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>`,
    moon: `<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>`,
    refresh: `<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>`,
    clear: `<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>`,
    cpu: `<rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="15" x2="23" y2="15"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="15" x2="4" y2="15"/>`,
    ram: `<path d="M4 6h16a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"/><line x1="6" y1="10" x2="6" y2="14"/><line x1="10" y1="10" x2="10" y2="14"/><line x1="14" y1="10" x2="14" y2="14"/><line x1="18" y1="10" x2="18" y2="14"/>`,
    gpu: `<rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="8" cy="12" r="3"/><circle cx="16" cy="12" r="3"/><line x1="1" y1="9" x2="2" y2="9"/><line x1="1" y1="15" x2="2" y2="15"/>`,
    play: `<polygon points="5 3 19 12 5 21 5 3"/>`,
    pause: `<rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/>`,
    network: `<rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/>`,
    vision: `<circle cx="12" cy="12" r="3"/><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7z"/>`
  };

  /**
   * Genera el SVG correspondiente según nombre y tamaño.
   */
  static get(name, size = 18, customClass = '') {
    const raw = this.icons[name] || FEATHER_ICONS[name] || this.icons.chat;
    if (!raw) return '';

    // Si ya es un tag SVG completo:
    if (raw.startsWith('<svg')) {
      let svg = raw.replace(/{size}/g, size.toString());
      if (customClass) {
        svg = svg.replace('class="nano-icon"', `class="nano-icon ${customClass}"`);
      }
      return svg;
    }

    // Si es un path/grupo interno del kit FeatherCore:
    const classAttr = customClass ? `class="nano-icon ${customClass}"` : 'class="nano-icon"';
    return `<svg ${classAttr} width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${raw}</svg>`;
  }

  /**
   * Inicializa elementos con [data-nano-icon]
   */
  static hydrate(root = document) {
    root.querySelectorAll('[data-nano-icon]').forEach((el) => {
      const name = el.getAttribute('data-nano-icon');
      const size = parseInt(el.getAttribute('data-nano-size') || '18', 10);
      const extraClass = el.getAttribute('data-nano-class') || '';
      el.innerHTML = this.get(name, size, extraClass);
    });
  }

  static names() {
    return Object.keys(this.icons);
  }
}

export const nanoIcons = NanoIcon.icons;
export const ICONS = FEATHER_ICONS;

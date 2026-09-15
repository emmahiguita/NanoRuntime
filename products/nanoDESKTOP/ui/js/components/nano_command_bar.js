import { NanoIcon } from './nano_icon.js';
import { appState } from '../core/state.js';

export class NanoCommandBar {
  constructor(container) {
    this.container = container;
    this.init();
  }

  init() {
    this.render();
    this.bindEvents();
  }

  render() {
    this.container.innerHTML = `
      <div class="command-bar-wrapper">
        <div class="command-bar-search">
          <span class="command-search-icon">${NanoIcon.get('search', 18)}</span>
          <input 
            type="text" 
            id="global-search-input" 
            class="command-search-input" 
            placeholder="Busca, pregunta o ejecuta en Nano..." 
            autocomplete="off"
            spellcheck="false"
          />
          <div class="command-kbd-badge">Ctrl + K</div>
          <button type="button" class="btn-icon" title="Entrada por voz" id="btn-mic">
            ${NanoIcon.get('mic', 18)}
          </button>
        </div>

        <div class="command-bar-actions">
          <button type="button" class="btn-icon theme-toggle" title="Alternar Modo Claro / Oscuro" id="btn-theme-toggle">
            ${NanoIcon.get('sun', 18)}
          </button>
          <button type="button" class="btn-icon" title="Notificaciones" id="btn-notifications">
            ${NanoIcon.get('bell', 18)}
          </button>
          <button type="button" class="btn-icon" title="Configuración" id="btn-settings">
            ${NanoIcon.get('settings', 18)}
          </button>
          
          <div class="user-profile-badge">
            <div class="user-avatar-circle">
              <img src="assets/owl_idle.png?v=2" alt="Emma" class="avatar-img" />
              <span class="user-online-dot"></span>
            </div>
            <div class="user-info-text">
              <span class="user-name">Dev Emma</span>
              <span class="user-status-label">En línea</span>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  bindEvents() {
    const input = this.container.querySelector('#global-search-input');
    const themeBtn = this.container.querySelector('#btn-theme-toggle');

    // Global keyboard shortcut Ctrl + K
    window.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        input?.focus();
        input?.select();
      }
    });

    // Theme toggle
    if (themeBtn) {
      themeBtn.addEventListener('click', () => {
        const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        const newTheme = isDark ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', newTheme);
        themeBtn.innerHTML = isDark ? NanoIcon.get('sun', 18) : NanoIcon.get('moon', 18);
        appState.setState({ theme: newTheme });
      });
    }

    if (input) {
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && input.value.trim()) {
          const query = input.value.trim();
          input.value = '';
          // Switch to chat and send message
          const chatNavBtn = document.querySelector('[data-tab="chat"]');
          chatNavBtn?.click();
          setTimeout(() => {
            const chatInput = document.getElementById('chat-input');
            if (chatInput) {
              chatInput.value = query;
              const chatForm = document.getElementById('chat-form');
              chatForm?.dispatchEvent(new Event('submit', { cancelable: true }));
            }
          }, 50);
        }
      });
    }
  }
}

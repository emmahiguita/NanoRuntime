import { NanoIcon } from './nano_icon.js';
import { LocalModelSelector } from './local_model_selector.js';
import { HardwareStatus } from './hardware_status.js';

/** Coordina la cabecera existente; catálogo y hardware tienen ciclos de vida propios. */
export class NanoTopBar {
  constructor({ onStartNewChat, onSwitchView }) {
    this.onStartNewChat = onStartNewChat;
    this.onSwitchView = onSwitchView;
    this.events = new AbortController();
    this.modelSelector = new LocalModelSelector();
    this.hardware = new HardwareStatus();
    this.setupControls();
  }

  /** Cada listener queda ligado al controlador para liberarlo al desmontar. */
  listen(id, action) {
    document.getElementById(id)?.addEventListener('click', action, { signal: this.events.signal });
  }

  /** Conserva controles, iconos y tema originales, sin duplicar navegación. */
  setupControls() {
    this.listen('btn-toggle-deepthink', () => {
      const button = document.getElementById('btn-toggle-deepthink');
      button.classList.toggle('active');
      document.getElementById('composer-btn-deepthink')?.classList.toggle('active', button.classList.contains('active'));
    });
    this.listen('btn-toggle-web', () => {
      const button = document.getElementById('btn-toggle-web');
      button.classList.toggle('active');
      button.classList.toggle('web');
      const composer = document.getElementById('composer-btn-web');
      composer?.classList.toggle('active', button.classList.contains('active'));
      composer?.classList.toggle('web', button.classList.contains('active'));
    });
    this.listen('btn-clear-chat', () => this.onStartNewChat?.());
    const theme = document.getElementById('btn-toggle-theme');
    if (theme) {
      theme.innerHTML = NanoIcon.get(document.documentElement.dataset.theme === 'dark' ? 'moon' : 'sun', 16);
      this.listen('btn-toggle-theme', () => {
        const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
        document.documentElement.dataset.theme = next;
        localStorage.setItem('nano_theme', next);
        theme.innerHTML = NanoIcon.get(next === 'dark' ? 'moon' : 'sun', 16);
      });
    }
    this.listen('btn-open-settings', () => this.onSwitchView?.('terminal'));
    // El indicador abre la vista real de recursos, en lugar de ser un botón sin acción.
    this.listen('btn-nanoruntime-status', () => this.onSwitchView?.('models'));
  }

  /** No deja sondeos ni listeners de componentes destruidos. */
  destroy() { this.events.abort(); this.modelSelector.destroy(); this.hardware.destroy(); }
}

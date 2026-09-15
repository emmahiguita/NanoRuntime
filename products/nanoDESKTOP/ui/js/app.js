import { transport } from './core/transport.js';
import { appState } from './core/state.js';
import { NanoIcon } from './components/nano_icon.js';
import { ChatView } from './features/chat/chat_view.js';
import { TerminalView } from './features/terminal/terminal_view.js';
import { SystemView } from './features/system/system_view.js';
import { AutomationView } from './features/automation/automation_view.js';

class App {
  constructor() {
    this.currentView = 'chat';
    this.views = {};
    this.sidebarCollapsed = false;
    this.telemetryInterval = null;
  }

  async init() {
    NanoIcon.hydrate();
    this.setupViews();
    this.setupNavigation();
    this.setupSidebar();
    this.setupModelSelector();
    this.setupTopControls();
    this.setupShortcuts();
    this.startHardwarePolling();
    this.renderHistoryList();

    // Re-renderizar historial cuando cambien las sesiones
    appState.subscribe(() => {
      this.renderHistoryList();
    });
  }

  setupViews() {
    const chatContainer = document.getElementById('view-chat');
    const terminalContainer = document.getElementById('view-terminal');
    const modelsContainer = document.getElementById('view-models');
    const automationContainer = document.getElementById('view-automation');

    if (chatContainer) this.views.chat = new ChatView(chatContainer);
    if (terminalContainer) this.views.terminal = new TerminalView(terminalContainer);
    if (modelsContainer) this.views.models = new SystemView(modelsContainer);
    if (automationContainer) this.views.automation = new AutomationView(automationContainer);
  }

  setupNavigation() {
    const navItems = document.querySelectorAll('.sidebar-nav-item');
    navItems.forEach((btn) => {
      btn.addEventListener('click', () => {
        const view = btn.dataset.view;
        if (!view) return;
        this.switchView(view);
      });
    });
  }

  switchView(viewName) {
    const navItems = document.querySelectorAll('.sidebar-nav-item');
    navItems.forEach((b) => {
      b.classList.toggle('active', b.dataset.view === viewName);
    });

    ['chat', 'terminal', 'models', 'automation'].forEach((key) => {
      const viewEl = document.getElementById(`view-${key}`);
      if (viewEl) {
        viewEl.style.display = key === viewName ? 'flex' : 'none';
      }
    });

    this.currentView = viewName;
  }

  setupSidebar() {
    const sidebar = document.getElementById('sidebar');
    const toggleBtn = document.getElementById('btn-collapse-sidebar');
    const newChatBtn = document.getElementById('btn-new-chat');

    if (toggleBtn && sidebar) {
      toggleBtn.addEventListener('click', () => {
        this.sidebarCollapsed = !this.sidebarCollapsed;
        sidebar.classList.toggle('collapsed', this.sidebarCollapsed);
      });
    }

    if (newChatBtn) {
      newChatBtn.addEventListener('click', () => {
        this.startNewChat();
      });
    }
  }

  renderHistoryList() {
    const listContainer = document.getElementById('chat-history-list');
    if (!listContainer) return;

    const state = appState.getState();
    const sessions = state.sessions || [];
    const activeId = state.currentSessionId;

    listContainer.innerHTML = sessions
      .map(
        (ses) => `
        <div class="chat-history-item-row ${ses.id === activeId ? 'active' : ''}">
          <button type="button" class="chat-history-item ${ses.id === activeId ? 'active' : ''}" data-session-id="${ses.id}" title="${ses.title}">
            <span class="chat-item-text">${this.escapeHtml(ses.title)}</span>
          </button>
          <button type="button" class="btn-delete-session" data-session-id="${ses.id}" title="Eliminar conversación">
            ${NanoIcon.get('trash', 12)}
          </button>
        </div>
      `
      )
      .join('');

    // Bind clics de selección
    listContainer.querySelectorAll('.chat-history-item').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.sessionId;
        if (id) {
          appState.switchSession(id);
          this.switchView('chat');
        }
      });
    });

    // Bind clics de eliminación
    listContainer.querySelectorAll('.btn-delete-session').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = btn.dataset.sessionId;
        if (id) {
          appState.deleteSession(id);
        }
      });
    });
  }

  startNewChat() {
    appState.createSession('Nueva conversación');
    this.switchView('chat');
    const input = document.getElementById('chat-input');
    if (input) {
      input.value = '';
      input.focus();
    }
  }

  setupModelSelector() {
    const btn = document.getElementById('btn-model-selector');
    const menu = document.getElementById('model-dropdown-menu');
    const activeLabel = document.getElementById('active-model-name');

    if (btn && menu) {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        menu.classList.toggle('open');
      });

      document.addEventListener('click', () => {
        menu.classList.remove('open');
      });

      menu.querySelectorAll('.model-option-item').forEach((opt) => {
        opt.addEventListener('click', () => {
          menu.querySelectorAll('.model-option-item').forEach((o) => o.classList.remove('selected'));
          opt.classList.add('selected');

          const modelName = opt.querySelector('.model-opt-title span').textContent;
          if (activeLabel) activeLabel.textContent = modelName;

          const modelKey = opt.dataset.model;
          appState.setState({ currentModel: modelName });
          menu.classList.remove('open');
        });
      });
    }
  }

  setupTopControls() {
    // DeepThink toggle
    const deepThinkBtn = document.getElementById('btn-toggle-deepthink');
    if (deepThinkBtn) {
      deepThinkBtn.addEventListener('click', () => {
        deepThinkBtn.classList.toggle('active');
        const composerBtn = document.getElementById('composer-btn-deepthink');
        composerBtn?.classList.toggle('active', deepThinkBtn.classList.contains('active'));
      });
    }

    // Web toggle
    const webBtn = document.getElementById('btn-toggle-web');
    if (webBtn) {
      webBtn.addEventListener('click', () => {
        webBtn.classList.toggle('active');
        webBtn.classList.toggle('web');
        const composerBtn = document.getElementById('composer-btn-web');
        if (composerBtn) {
          composerBtn.classList.toggle('active', webBtn.classList.contains('active'));
          composerBtn.classList.toggle('web', webBtn.classList.contains('active'));
        }
      });
    }

    // Clear chat
    const clearBtn = document.getElementById('btn-clear-chat');
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        this.startNewChat();
      });
    }

    // Theme toggle
    const themeBtn = document.getElementById('btn-toggle-theme');
    if (themeBtn) {
      themeBtn.addEventListener('click', () => {
        const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
        const nextTheme = isDark ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', nextTheme);
        themeBtn.innerHTML = NanoIcon.get(isDark ? 'sun' : 'moon', 16);
      });
    }

    // Settings button
    const settingsBtn = document.getElementById('btn-open-settings');
    if (settingsBtn) {
      settingsBtn.addEventListener('click', () => {
        this.switchView('terminal');
      });
    }
  }

  setupShortcuts() {
    window.addEventListener('keydown', (e) => {
      // Ctrl+N / Cmd+N: Nuevo Chat
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'n') {
        e.preventDefault();
        this.startNewChat();
      }
      // Ctrl+B / Cmd+B: Colapsar sidebar
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'b') {
        e.preventDefault();
        const sidebar = document.getElementById('sidebar');
        if (sidebar) {
          this.sidebarCollapsed = !this.sidebarCollapsed;
          sidebar.classList.toggle('collapsed', this.sidebarCollapsed);
        }
      }
    });
  }

  startHardwarePolling() {
    const updateStats = async () => {
      try {
        const status = await transport.getSystemStatus();
        const hwTps = document.getElementById('hw-tps');
        const hwRam = document.getElementById('hw-ram-stat');
        const hwGpu = document.getElementById('hw-gpu-stat');

        if (hwTps) {
          hwTps.textContent = transport.isTauri ? '28.4 tok/s' : '22.4 tok/s';
        }

        if (hwRam && status.total_ram_mb) {
          const usedGb = (status.used_ram_mb / 1024).toFixed(1);
          const totalGb = (status.total_ram_mb / 1024).toFixed(0);
          hwRam.textContent = `RAM: ${usedGb} / ${totalGb} GB`;
        }

        if (hwGpu) {
          hwGpu.textContent = `GPU: ${status.gpu_usage_pct || 27}%`;
        }
      } catch (e) {
        // Silencioso
      }
    };

    updateStats();
    this.telemetryInterval = setInterval(updateStats, 3500);
  }

  escapeHtml(str) {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const app = new App();
  app.init();
});

/**
 * app.js — Entrypoint Principal de la Aplicación Nano Desktop (< 200 LOC)
 * 
 * QUÉ HACE:
 * Inicializa el catálogo de iconos, coordina las vistas principales (Chat, Terminal,
 * Modelos, Automatizaciones y WhatsApp) y administra la navegación global.
 * 
 * CÓMO FUNCIONA:
 * Conecta instancias de vista a los contenedores DOM correspondientes y conmuta
 * visibilidad mediante `switchView`, destruyendo y montando sin procesos zombi.
 * 
 * POR QUÉ:
 * El principio de Inversión de Dependencias y orquestación limpia mantiene el punto
 * de entrada desacoplado de la lógica interna de cada módulo de negocio.
 */

import { appState }      from './core/state.js';
import { escapeHtml }    from './core/utils.js'; // Utilidad compartida — sin duplicados
import { NanoIcon }      from './components/nano_icon.js';
import { NanoTopBar }    from './components/nano_top_bar.js';
import { ChatView }      from './features/chat/chat_view.js';
import { TerminalView }  from './features/terminal/terminal_view.js';
import { SystemView }    from './features/system/system_view.js';
import { AutomationView } from './features/automation/automation_view.js';
import { WhatsAppView }  from './features/whatsapp/whatsapp_view.js';

class App {
  constructor() {
    this.currentView = 'chat';
    this.views = {};
    this.sidebarCollapsed = false;
  }

  async init() {
    NanoIcon.hydrate();
    this.setupViews();
    this.setupNavigation();
    this.setupSidebar();
    this.setupShortcuts();
    this.renderHistoryList();

    this.topBar = new NanoTopBar({
      onStartNewChat: () => this.startNewChat(),
      onSwitchView: (view) => this.switchView(view),
    });

    appState.subscribe(() => {
      this.renderHistoryList();
    });
  }

  setupViews() {
    const chatContainer = document.getElementById('view-chat');
    const terminalContainer = document.getElementById('view-terminal');
    const modelsContainer = document.getElementById('view-models');
    const automationContainer = document.getElementById('view-automation');
    const whatsappContainer = document.getElementById('view-whatsapp');

    if (chatContainer) this.views.chat = new ChatView(chatContainer);
    if (terminalContainer) this.views.terminal = new TerminalView(terminalContainer);
    if (modelsContainer) this.views.models = new SystemView(modelsContainer);
    if (automationContainer) this.views.automation = new AutomationView(automationContainer);
    if (whatsappContainer) this.views.whatsapp = new WhatsAppView(whatsappContainer);
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

    ['chat', 'terminal', 'models', 'automation', 'whatsapp'].forEach((key) => {
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
            <span class="chat-item-text">${escapeHtml(ses.title)}</span>
          </button>
          <button type="button" class="btn-delete-session" data-session-id="${ses.id}" title="Eliminar conversación">
            ${NanoIcon.get('trash', 12)}
          </button>
        </div>
      `
      )
      .join('');

    listContainer.querySelectorAll('.chat-history-item').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.sessionId;
        if (id) {
          appState.switchSession(id);
          this.switchView('chat');
        }
      });
    });

    listContainer.querySelectorAll('.btn-delete-session').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = btn.dataset.sessionId;
        if (id) appState.deleteSession(id);
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

  setupShortcuts() {
    window.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'n') {
        e.preventDefault();
        this.startNewChat();
      }
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

// escapeHtml ahora proviene de './core/utils.js' (importado arriba)
// Se elimina la implementación duplicada que existía aquí y en automation_view.js

}

document.addEventListener('DOMContentLoaded', () => {
  const app = new App();
  app.init();
});

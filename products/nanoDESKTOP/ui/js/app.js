/**
 * app.js — Entrypoint Principal de Nano Desktop (< 200 LOC)
 *
 * QUÉ HACE:
 * Inicializa iconos, coordina vistas principales (Chat, Terminal, Modelos,
 * Automatizaciones, WhatsApp) y administra la navegación y atajos globales.
 *
 * CÓMO FUNCIONA:
 * Conecta instancias de vista a sus contenedores DOM y conmuta visibilidad
 * mediante `switchView`, asegurando ciclo de vida limpio sin fugas.
 *
 * POR QUÉ:
 * DIP (Dependency Inversion): Mantiene el punto de entrada desacoplado
 * de los detalles de implementación de cada vista de negocio.
 */

import { appState } from './core/state.js?v=v16';
import { escapeHtml } from './core/utils.js?v=v16';
import { NanoIcon } from './components/nano_icon.js?v=v16';
import { NanoTopBar } from './components/nano_top_bar.js?v=v16';
import { ChatView } from './features/chat/chat_view.js?v=v16';
import { TerminalView } from './features/terminal/terminal_view.js?v=v16';
import { SystemView } from './features/system/system_view.js?v=v16';
import { AutomationView } from './features/automation/automation_view.js?v=v16';
import { WhatsAppView } from './features/whatsapp/whatsapp_view.js?v=v16';

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

    appState.subscribe(() => this.renderHistoryList());
  }

  setupViews() {
    const chat = document.getElementById('view-chat');
    const term = document.getElementById('view-terminal');
    const mods = document.getElementById('view-models');
    const auto = document.getElementById('view-automation');
    const wapp = document.getElementById('view-whatsapp');

    if (chat) this.views.chat = new ChatView(chat);
    if (term) this.views.terminal = new TerminalView(term);
    if (mods) this.views.models = new SystemView(mods);
    if (auto) this.views.automation = new AutomationView(auto);
    if (wapp) this.views.whatsapp = new WhatsAppView(wapp);
  }

  setupNavigation() {
    document.querySelectorAll('.sidebar-nav-item').forEach((btn) => {
      btn.addEventListener('click', () => {
        const view = btn.dataset.view;
        if (!view) return;
        if (view === 'chat' && this.currentView === 'chat') {
          this.startNewChat();
        } else {
          this.switchView(view);
        }
      });
    });
  }

  switchView(viewName) {
    document.querySelectorAll('.sidebar-nav-item').forEach((b) => {
      b.classList.toggle('active', b.dataset.view === viewName);
    });

    ['chat', 'terminal', 'models', 'automation', 'whatsapp'].forEach((key) => {
      const el = document.getElementById(`view-${key}`);
      if (el) {
        const isActive = key === viewName;
        el.classList.toggle('active', isActive);
        el.style.display = isActive ? 'flex' : 'none';
      }
    });

    this.currentView = viewName;
  }

  setupSidebar() {
    const sidebar = document.getElementById('sidebar');
    const toggleBtn = document.getElementById('btn-collapse-sidebar');
    const newChatBtn = document.getElementById('btn-new-chat');
    const brandLogo = document.querySelector('.sidebar-header.nano-brand');

    brandLogo?.addEventListener('click', () => this.startNewChat());
    toggleBtn?.addEventListener('click', () => {
      this.sidebarCollapsed = !this.sidebarCollapsed;
      sidebar?.classList.toggle('collapsed', this.sidebarCollapsed);
    });
    newChatBtn?.addEventListener('click', () => this.startNewChat());
  }

  renderHistoryList() {
    const listContainer = document.getElementById('chat-history-list');
    if (!listContainer) return;

    const state = appState.getState();
    const sessions = state.sessions || [];
    const activeId = state.currentSessionId;

    listContainer.innerHTML = sessions.map((ses) => `
      <div class="chat-history-item-row ${ses.id === activeId ? 'active' : ''}">
        <button type="button" class="chat-history-item ${ses.id === activeId ? 'active' : ''}" data-session-id="${ses.id}" title="${ses.title}">
          <span class="chat-item-text">${escapeHtml(ses.title)}</span>
        </button>
        <button type="button" class="btn-delete-session" data-session-id="${ses.id}" title="Eliminar conversación">
          ${NanoIcon.get('trash', 12)}
        </button>
      </div>
    `).join('');

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
}

document.addEventListener('DOMContentLoaded', () => {
  const app = new App();
  app.init();
});

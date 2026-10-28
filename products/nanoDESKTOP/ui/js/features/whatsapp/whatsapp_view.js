/**
 * whatsapp_view.js — Controlador Maestro de la Vista de WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Orquesta las 3 columnas de WhatsApp Desktop: Barra lateral de chats, Hilo central
 * de conversación con compositor y Panel lateral de contexto e inteligencia de negocio.
 * 
 * CÓMO FUNCIONA:
 * Asigna los contenedores en el DOM, inicializa los componentes de cada columna,
 * sincroniza la selección del hilo activo y destruye limpiamente todos los recursos.
 * 
 * POR QUÉ:
 * Implementa el Patrón Mediador (Mediator Pattern) respetando Clean Architecture y
 * SOLID, manteniendo el código < 200 líneas y garantizando ausencia de procesos zombi.
 */

import { WhatsAppChatList } from './ui/whatsapp_chat_list.js';
import { WhatsAppChatConversation } from './ui/whatsapp_chat_conversation.js';
import { WhatsAppComposer } from './ui/whatsapp_composer.js';
import { WhatsAppContextPanel } from './ui/whatsapp_context_panel.js';
import { WhatsAppPairingModal } from './ui/whatsapp_pairing_modal.js';
import { whatsAppBus } from './domain/whatsapp_events.js';
import { whatsAppStorage } from './services/whatsapp_storage.js';

export class WhatsAppView {
  constructor(containerElement) {
    this.container = containerElement;
    this.activeThreadId = null;
    this._unsubscribers = [];

    this._init();
  }

  _init() {
    this.container.innerHTML = `
      <div class="wa-workspace">
      <header class="wa-workspace-toolbar">
        <button type="button" class="wa-btn-new-chat wa-back-list">Conversaciones</button>
        <div class="wa-workspace-heading"><strong>Mensajería</strong><span class="wa-source-label">Historial local</span></div>
        <button type="button" class="wa-btn-new-chat wa-toggle-details" aria-expanded="false">Detalles</button>
        <button type="button" class="wa-btn-new-chat wa-open-connection wa-connection-status"
          title="Configurar la conexión oficial de Meta">Meta sin conectar</button>
      </header>
      <div class="wa-container-three-col">
        <!-- Columna 1: Lista de Chats -->
        <aside class="wa-col-sidebar" id="wa-sidebar-mount"></aside>

        <!-- Columna 2: Hilo de Conversación Central y Compositor -->
        <main class="wa-col-conversation">
          <section class="wa-conversation-stream" id="wa-conversation-mount"></section>
          <footer class="wa-composer-wrapper" id="wa-composer-mount"></footer>
        </main>

        <!-- Columna 3: Panel de Contexto e Inteligencia de Negocio -->
        <aside class="wa-col-context" id="wa-context-mount"></aside>
      </div>
      </div>
    `;

    // Un mismo panel se adapta; no duplica pantallas ni cambia rutas.
    this.workspace = this.container.querySelector('.wa-workspace');
    this.container.querySelector('.wa-toggle-details').addEventListener('click', e => {
      const open = this.workspace.classList.toggle('wa-details-open');
      e.currentTarget.setAttribute('aria-expanded', String(open));
      if (open) this.contextPanel.tabs.find(tab => tab.getAttribute('aria-selected') === 'true')?.focus();
    });
    this.container.querySelector('.wa-open-connection').addEventListener('click', () =>
      WhatsAppPairingModal.show());
    this.container.querySelector('.wa-back-list').addEventListener('click', () =>
      this.workspace.classList.remove('wa-thread-selected'));
    // Escape cierra únicamente el panel lateral y devuelve el foco a su control.
    this.workspace.addEventListener('keydown', event => {
      if (event.key !== 'Escape' || !this.workspace.classList.contains('wa-details-open')) return;
      this.workspace.classList.remove('wa-details-open');
      const button = this.container.querySelector('.wa-toggle-details');
      button.setAttribute('aria-expanded', 'false');
      button.focus();
    });

    const sidebarMount = this.container.querySelector('#wa-sidebar-mount');
    const conversationMount = this.container.querySelector('#wa-conversation-mount');
    const composerMount = this.container.querySelector('#wa-composer-mount');
    const contextMount = this.container.querySelector('#wa-context-mount');

    this.chatList = new WhatsAppChatList(sidebarMount, (threadId) => {
      this.handleSelectThread(threadId);
    });

    this.conversation = new WhatsAppChatConversation(conversationMount);
    this.composer = new WhatsAppComposer(composerMount);
    this.contextPanel = new WhatsAppContextPanel(contextMount);

    // Escuchar solicitud para modal de vinculación
    const unsubModal = whatsAppBus.subscribe('ui:open_pairing_modal', () => {
      WhatsAppPairingModal.show();
    });
    this._unsubscribers.push(unsubModal);

    // Selecciona un registro existente; no crea ni presume contactos de ejemplo.
    const convs = whatsAppStorage.getConversations();
    if (convs.length > 0) {
      this.chatList.selectThread(convs[0].id);
    }
  }

  handleSelectThread(threadId) {
    // La navegación compacta ofrece regreso a la lista sin perder el borrador.
    this.workspace.classList.add('wa-thread-selected');
    this.activeThreadId = threadId;
    this.conversation.loadThread(threadId);
    this.composer.setActiveThread(threadId);
    this.contextPanel.setActiveThread(threadId);
  }

  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];

    if (this.chatList) this.chatList.destroy();
    if (this.conversation) this.conversation.destroy();
    if (this.composer) this.composer.destroy();
    if (this.contextPanel) this.contextPanel.destroy();
  }
}


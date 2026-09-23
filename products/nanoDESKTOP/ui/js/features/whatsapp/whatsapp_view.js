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

import { WhatsAppChatList } from './ui/whatsapp_chat_list.js?v=v4';
import { WhatsAppChatConversation } from './ui/whatsapp_chat_conversation.js?v=v4';
import { WhatsAppComposer } from './ui/whatsapp_composer.js?v=v4';
import { WhatsAppContextPanel } from './ui/whatsapp_context_panel.js?v=v4';
import { WhatsAppPairingModal } from './ui/whatsapp_pairing_modal.js?v=v4';
import { whatsAppBus } from './domain/whatsapp_events.js?v=v4';
import { whatsAppStorage } from './services/whatsapp_storage.js?v=v4';

export class WhatsAppView {
  constructor(containerElement) {
    this.container = containerElement;
    this.activeThreadId = null;
    this._unsubscribers = [];

    this._init();
  }

  _init() {
    this.container.innerHTML = `
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
    `;

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

    // Seleccionar por defecto el primer hilo (María González)
    const convs = whatsAppStorage.getConversations();
    if (convs.length > 0) {
      this.handleSelectThread(convs[0].id);
      this.chatList.selectThread(convs[0].id);
    }
  }

  handleSelectThread(threadId) {
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


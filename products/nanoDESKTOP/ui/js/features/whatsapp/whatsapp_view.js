/**
 * whatsapp_view.js — Controlador Maestro de la Vista de WhatsApp Desktop
 * 
 * QUÉ HACE:
 * Orquesta la barra lateral de chats, el visor de mensajes, la barra de políticas
 * y el compositor en una interfaz soberana de escritorio moderna y fluida.
 * 
 * CÓMO FUNCIONA:
 * Construye la estructura base en el elemento contenedor, inicializa los submódulos,
 * conecta los callbacks de selección y escucha eventos de apertura de modales.
 * 
 * POR QUÉ:
 * Implementa el Patrón Mediador (Mediator Pattern) y respeta Clean Architecture,
 * asegurando un desmonte completo (`destroy()`) sin procesos ni listeners zombi.
 */

import { WhatsAppChatList } from './ui/whatsapp_chat_list.js';
import { WhatsAppChatConversation } from './ui/whatsapp_chat_conversation.js';
import { WhatsAppComposer } from './ui/whatsapp_composer.js';
import { WhatsAppPolicyBar } from './ui/whatsapp_policy_bar.js';
import { WhatsAppPairingModal } from './ui/whatsapp_pairing_modal.js';
import { whatsAppBus } from './domain/whatsapp_events.js';
import { whatsAppStorage } from './services/whatsapp_storage.js';

export class WhatsAppView {
  /**
   * @param {HTMLElement} containerElement - Contenedor `#view-whatsapp`.
   */
  constructor(containerElement) {
    this.container = containerElement;
    this.activeThreadId = null;
    this._unsubscribers = [];

    this._init();
  }

  _init() {
    this.container.innerHTML = `
      <div class="wa-container">
        <aside class="wa-sidebar" id="wa-sidebar-mount"></aside>
        <main class="wa-main-panel">
          <header id="wa-policy-mount"></header>
          <section class="wa-messages-stream" id="wa-conversation-mount"></section>
          <footer id="wa-composer-mount"></footer>
        </main>
      </div>
    `;

    const sidebarMount = this.container.querySelector('#wa-sidebar-mount');
    const policyMount = this.container.querySelector('#wa-policy-mount');
    const conversationMount = this.container.querySelector('#wa-conversation-mount');
    const composerMount = this.container.querySelector('#wa-composer-mount');

    this.chatList = new WhatsAppChatList(sidebarMount, (threadId) => {
      this.handleSelectThread(threadId);
    });

    this.policyBar = new WhatsAppPolicyBar(policyMount);
    this.conversation = new WhatsAppChatConversation(conversationMount);
    this.composer = new WhatsAppComposer(composerMount);

    // Escuchar solicitud para abrir el modal de vinculación
    const unsubModal = whatsAppBus.subscribe('ui:open_pairing_modal', () => {
      WhatsAppPairingModal.show();
    });
    this._unsubscribers.push(unsubModal);

    // Seleccionar automáticamente el primer hilo si existe
    const convs = whatsAppStorage.getConversations();
    if (convs.length > 0) {
      this.chatList.selectThread(convs[0].id);
    }
  }

  /**
   * Maneja la selección de un hilo y sincroniza las subvistas.
   * @param {string} threadId
   */
  handleSelectThread(threadId) {
    this.activeThreadId = threadId;
    this.policyBar.setActiveThread(threadId);
    this.conversation.loadThread(threadId);
    this.composer.setActiveThread(threadId);
  }

  /**
   * Limpia y desmantela todos los submódulos al salir o recargar la vista.
   */
  destroy() {
    this._unsubscribers.forEach((fn) => fn());
    this._unsubscribers = [];

    if (this.chatList) this.chatList.destroy();
    if (this.policyBar) this.policyBar.destroy();
    if (this.conversation) this.conversation.destroy();
    if (this.composer) this.composer.destroy();
  }
}

/**
 * chat_view.js — Orquestador de la Vista de Chat (< 200 LOC)
 *
 * QUÉ HACE:
 * Coordina la vista de bienvenida (Hero), el flujo de mensajes y el compositor
 * flotante, integrando la inferencia con `chatService` y el estado reactivo `appState`.
 *
 * CÓMO FUNCIONA:
 * Alterna entre `ChatHeroView` (sin mensajes) y `ChatMessageRenderer` (con mensajes).
 * Garantiza la destrucción determinista del búho y listeners para eliminar procesos zombi.
 *
 * POR QUÉ:
 * Arquitectura Limpia (SOLID - Fachada/Presentador): Centraliza la orquestación
 * sin acumular lógica de renderizado ni de formularios, manteniéndose < 200 LOC.
 */

import { appState } from '../../core/state.js';
import { chatService } from './chat_service.js';
import { ChatHeroView } from './chat_hero_view.js';
import { ChatComposer } from './chat_composer.js';
import { ChatMessageRenderer } from './chat_message_renderer.js';

export class ChatView {
  /**
   * @param {HTMLElement|string} containerOrId Contenedor DOM de la vista.
   */
  constructor(containerOrId) {
    this.container = typeof containerOrId === 'string'
      ? document.getElementById(containerOrId)
      : containerOrId;
    this.heroView = null;
    this.composer = null;
    this.messagesEl = null;
    this.isHomeMode = true;
    this.unsubscribeState = null;

    this.init();
  }

  init() {
    if (!this.container) return;

    this.container.innerHTML = `
      <div class="chat-wrapper-clean" id="chat-wrapper">
        <div id="chat-messages" class="chat-stream-container"></div>
        <div class="nano-composer-wrap chat-composer-outer" id="chat-composer-mount"></div>
      </div>
    `;

    this.messagesEl = this.container.querySelector('#chat-messages');
    const composerMount = this.container.querySelector('#chat-composer-mount');

    this.heroView = new ChatHeroView({
      onSelectPrompt: (prompt) => {
        this.composer?.setValue(prompt);
        if (this.heroView?.owlAvatar) {
          this.heroView.owlAvatar.setState('listening');
        }
      },
      onOwlCreated: (owl) => {
        chatService.setOwlInstance(owl);
      },
    });

    this.composer = new ChatComposer({
      container: composerMount,
      onSubmit: ({ text, files, options }) => {
        chatService.sendMessage(text, files, options);
      },
      onTyping: (isTyping) => {
        if (this.heroView?.owlAvatar) {
          if (isTyping && this.heroView.owlAvatar.currentState === 'idle') {
            this.heroView.owlAvatar.setState('listening');
          } else if (!isTyping && this.heroView.owlAvatar.currentState === 'listening') {
            this.heroView.owlAvatar.setState('idle');
          }
        }
      },
    });

    this.unsubscribeState = appState.subscribe((state) => this.render(state));
    this.render(appState.getState());
  }

  /**
   * Renderiza el estado actual conmutando limpiamente entre Hero y lista de mensajes.
   * @param {Object} state Estado reactivo de la aplicación.
   */
  render(state) {
    if (!this.messagesEl) return;

    const hasMessages = state.messages && state.messages.length > 0;

    if (!hasMessages) {
      // Si ya estaba en modo home, no recreamos el avatar para no reiniciar animaciones
      if (!this.isHomeMode || !this.heroView.owlAvatar) {
        this.isHomeMode = true;
        this.heroView.mount(this.messagesEl);
      }
      chatService.setOwlInstance(this.heroView.owlAvatar);
      return;
    }

    // Modo Mensajes: Limpiar avatar previo para eliminar loops RAF zombis
    if (this.isHomeMode) {
      this.isHomeMode = false;
      this.heroView.destroyAvatar();
      chatService.setOwlInstance(null);
    }

    this.messagesEl.innerHTML = state.messages
      .map((m) => ChatMessageRenderer.render(m))
      .join('');

    ChatMessageRenderer.bindInteractions(this.messagesEl);
    this.messagesEl.scrollTop = this.messagesEl.scrollHeight;
    this.composer?.setDisabled(Boolean(state.isGenerating));
  }

  /**
   * Limpieza de recursos y observadores al destruir la vista.
   */
  destroy() {
    if (this.unsubscribeState) {
      this.unsubscribeState();
      this.unsubscribeState = null;
    }
    if (this.heroView) {
      this.heroView.destroy();
      this.heroView = null;
    }
    this.container = null;
  }
}

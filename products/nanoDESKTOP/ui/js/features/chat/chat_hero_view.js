/**
 * chat_hero_view.js — Vista Hero de Bienvenida y Montaje del Búho Nano (< 200 LOC)
 *
 * QUÉ HACE:
 * Renderiza la pantalla inicial cuando no hay mensajes: título principal, chips
 * informativos, cuadrícula de sugerencias y el contenedor del avatar interactivo.
 *
 * CÓMO FUNCIONA:
 * Monta el DOM del Hero, inicializa `NanoOwlAvatar` de forma controlada y destruye
 * cualquier instancia previa antes de crear una nueva, evitando procesos zombi.
 * Gestiona los eventos de clic en las tarjetas de sugerencia y en el búho.
 *
 * POR QUÉ:
 * Principio de Responsabilidad Única (SRP): Desacopla la presentación de bienvenida
 * del flujo continuo de chat, asegurando un ciclo de vida limpio sin fugas de memoria.
 */

import { NanoIcon } from '../../components/nano_icon.js';
import { NanoOwlAvatar } from '../../components/nano_owl_avatar.js';

export class ChatHeroView {
  /**
   * @param {Object} options
   * @param {Function} options.onSelectPrompt Callback al hacer clic en una sugerencia.
   * @param {Function} options.onOwlCreated Callback para registrar la instancia del búho.
   */
  constructor({ onSelectPrompt = () => {}, onOwlCreated = () => {} }) {
    this.onSelectPrompt = onSelectPrompt;
    this.onOwlCreated = onOwlCreated;
    this.owlAvatar = null;
    this.container = null;
  }

  /**
   * Monta el contenido del Hero dentro del elemento contenedor provisto.
   * @param {HTMLElement} mountEl Elemento contenedor (#chat-messages).
   */
  mount(mountEl) {
    this.container = mountEl;
    this.destroyAvatar(); // Destruye cualquier avatar previo para evitar zombis en RAF

    this.container.innerHTML = `
      <div class="nano-home-view">
        <div class="nano-hero">
          <!-- Columna Izquierda: Títulos, Chips y Feature Cards -->
          <div class="nano-hero-left">
            <h1 class="nano-hero-title">¿En qué puedo <span class="nano-title-accent">ayudarte</span> hoy?</h1>
            <p class="nano-hero-subtitle">Inferencia local 100% privada con nanoRUNTIME y modelos GGUF.</p>

            <div class="nano-hero-chips">
              <span class="nano-chip"><span class="chip-dot"></span>Privado</span>
              <span class="nano-chip"><span class="chip-dot"></span>Rápido</span>
              <span class="nano-chip"><span class="chip-dot"></span>Sin límites</span>
              <span class="nano-chip"><span class="chip-dot"></span>En tu hardware</span>
            </div>

            <div class="nano-home-grid">
              ${this._renderCards()}
            </div>
          </div>

          <!-- Columna Derecha: Avatar Nano con Estado Soberano -->
          <div class="nano-hero-right">
            <div class="nano-hero-owl-wrap" title="Haz clic en Nano para interactuar (Saludar, Planear, Dormir)">
              <div id="nano-owl-mount" class="nano-owl-wrapper"></div>
            </div>

            <div class="nano-avatar-status-pill">
              <span class="status-indicator-dot"></span>
              <span>Inferencia Soberana &bull; En tu hardware</span>
            </div>
          </div>
        </div>
      </div>
    `;

    this._setupOwl();
    this._bindEvents();
  }

  /**
   * Genera el HTML de las 4 tarjetas de sugerencias.
   */
  _renderCards() {
    const cards = [
      {
        icon: 'terminal',
        title: 'Arquitectura NanoRuntime',
        desc: 'Desacoplamiento de backends de inferencia y memory fitting',
        prompt: 'Explica la arquitectura de NanoRuntime en Rust y cómo desacoplar backends de inferencia.',
      },
      {
        icon: 'models',
        title: 'Model Fitting y TTL',
        desc: 'Políticas de ciclo de vida ECO, BALANCED y PINNED',
        prompt: '¿Cómo implementar un mecanismo de model fitting dinámico y auto-eviction estilo Jan y LM Studio?',
      },
      {
        icon: 'database',
        title: 'Diagnósticos de Hardware',
        desc: 'Monitoreo de KV Cache, VRAM y límites térmicos',
        prompt: 'Escribe un script en Rust para ejecutar diagnósticos de VRAM, KV Cache y offload de capas a la GPU.',
      },
      {
        icon: 'automation',
        title: 'Agente de Automatización',
        desc: 'Orquestación de tareas con herramientas y aprobación',
        prompt: 'Diseña un flujo de trabajo para un agente de automatización que procese pedidos y emita tracking.',
      },
    ];

    return cards.map((c) => `
      <button type="button" class="nano-feature-card suggestion-card" data-prompt="${c.prompt}">
        <span class="nano-icon-tile">${NanoIcon.get(c.icon, 20)}</span>
        <span class="nano-card-texts">
          <span class="nano-feature-card-title">${c.title}</span>
          <span class="nano-feature-card-description">${c.desc}</span>
        </span>
      </button>
    `).join('');
  }

  /**
   * Inicializa la instancia del avatar y la registra en el servicio.
   */
  _setupOwl() {
    const owlMount = this.container?.querySelector('#nano-owl-mount');
    if (!owlMount) return;

    this.owlAvatar = new NanoOwlAvatar({
      size: 220,
      container: owlMount,
      withHalo: true,
      interactive: true,
    });

    window.nanoOwl = this.owlAvatar;
    this.onOwlCreated(this.owlAvatar);
  }

  /**
   * Enlaza eventos de clic en el avatar y en las tarjetas de sugerencias.
   */
  _bindEvents() {
    const owlWrap = this.container?.querySelector('.nano-hero-owl-wrap');
    if (owlWrap) {
      owlWrap.addEventListener('click', (e) => {
        if (this.owlAvatar) this.owlAvatar.onClick(e);
      });
    }

    this.container?.querySelectorAll('.suggestion-card').forEach((card) => {
      card.addEventListener('click', () => {
        const prompt = card.dataset.prompt;
        if (prompt) this.onSelectPrompt(prompt);
      });
    });
  }

  /**
   * Destruye de forma segura el avatar y libera recursos/RAF para prevenir zombis.
   */
  destroyAvatar() {
    if (this.owlAvatar) {
      this.owlAvatar.destroy();
      this.owlAvatar = null;
      window.nanoOwl = null;
    }
  }

  /**
   * Destruye la vista completa al cambiar a la vista de mensajes.
   */
  destroy() {
    this.destroyAvatar();
    this.container = null;
  }
}

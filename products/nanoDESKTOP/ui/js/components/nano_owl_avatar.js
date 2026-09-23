/**
 * @file nano_owl_avatar.js
 * @description Fachada principal (Facade Pattern) para el Avatar 3D de Nano AI.
 * 
 * Qué hace: Orquesta la vista del búho, física de resortes y máquina de estados finitos.
 * Cómo funciona: Delega en OwlPhysicsEngine y OwlStateMachine; gestiona eventos de usuario con limpieza total.
 * Por qué: Principio de Responsabilidad Única e Inversión de Dependencias (SOLID); libre de memory leaks.
 */

import { OWL_ASSETS, OWL_TIMERS_CONFIG } from './owl/owl_config.js';
import { OwlPhysicsEngine } from './owl/owl_physics.js';
import { OwlStateMachine } from './owl/owl_state_machine.js';

export class NanoOwlAvatar {
  constructor(options = {}) {
    this.size = options.size || 220;
    this.container = options.container || null;
    this.withHalo = options.withHalo !== false;
    this.interactive = options.interactive !== false;

    this.physics = null;
    this.fsm = null;
    this.sleepTimeout = null;

    if (this.container) {
      this.mount(this.container);
    }
  }

  get currentState() {
    return this.fsm ? this.fsm.currentState : 'idle';
  }

  mount(container) {
    this.container = typeof container === 'string' ? document.getElementById(container) : container;
    if (!this.container) return;

    this.destroy(); // Limpieza preventiva de instancias previas (previene procesos zombi)

    this.element = document.createElement('div');
    this.element.className = 'nano-owl-wrapper';
    this.element.style.setProperty('--owl-size', `${this.size}px`);

    this.element.innerHTML = `
      ${this.withHalo ? '<div class="nano-owl-halo" id="owl-halo" aria-hidden="true"></div>' : ''}
      <div class="nano-owl-stardust-container" id="owl-stardust" aria-hidden="true">
        <span class="stardust-sparkle p1"></span>
        <span class="stardust-sparkle p2"></span>
        <span class="stardust-sparkle p3"></span>
        <span class="stardust-sparkle p4"></span>
      </div>
      <div class="nano-owl-ground-shadow" id="owl-shadow" aria-hidden="true"></div>

      <div class="nano-owl-flight-rig state-idle" id="owl-flight-rig">
        <div class="nano-owl-stage" id="owl-stage">
          ${Object.entries(OWL_ASSETS).map(([key, src]) => `
            <img class="nano-owl-layer layer-${key} ${key === 'idle' ? 'active' : ''}" src="${src}" alt="Nano AI" aria-hidden="${key !== 'idle'}" />
          `).join('')}
          <div class="nano-owl-rim-light" id="owl-rim-light" aria-hidden="true"></div>
          <div class="nano-owl-galaxy-eyes-gleam" id="owl-eyes-gleam" aria-hidden="true">
            <div class="galaxy-pupil-glare pupil-left"><span class="pupil-star-shimmer"></span></div>
            <div class="galaxy-pupil-glare pupil-right"><span class="pupil-star-shimmer"></span></div>
          </div>
        </div>
      </div>
    `;

    this.container.innerHTML = '';
    this.container.appendChild(this.element);

    // Mapeo de elementos del DOM
    const flightRig = this.element.querySelector('#owl-flight-rig');
    const stage = this.element.querySelector('#owl-stage');
    const layers = {};
    Object.keys(OWL_ASSETS).forEach((key) => {
      layers[key] = this.element.querySelector(`.layer-${key}`);
    });

    // Instanciación de motores desacoplados
    this.physics = new OwlPhysicsEngine({
      stage,
      halo: this.element.querySelector('#owl-halo'),
      shadow: this.element.querySelector('#owl-shadow'),
      rimLight: this.element.querySelector('#owl-rim-light'),
      eyesGleam: this.element.querySelector('#owl-eyes-gleam'),
      stardust: this.element.querySelector('#owl-stardust'),
    });

    this.fsm = new OwlStateMachine({
      flightRig,
      stage,
      layers,
      onStateChange: (st) => {
        this.physics.isSleeping = st === 'sleep';
        this.physics.isThinking = st === 'thinking';
      },
    });

    this.physics.start();
    if (this.interactive) {
      this.bindInteractions();
      this.fsm.startAutonomousLoops(this.physics);
      this.resetSleepTimer();
      setTimeout(() => this.performGreeting(), 800);
    }
  }

  bindInteractions() {
    this.boundMouseMove = (e) => {
      this.resetSleepTimer();
      if (!this.element) return;
      const rect = this.element.getBoundingClientRect();
      const nx = (e.clientX - (rect.left + rect.width / 2)) / (window.innerWidth / 2);
      const ny = (e.clientY - (rect.top + rect.height / 2)) / (window.innerHeight / 2);
      this.physics.updateMouse(nx, ny);
    };

    this.boundMouseLeave = () => this.physics.resetMouse();
    this.boundMouseEnter = () => {
      this.physics.isHovered = true;
      this.wakeUp();
    };

    this.boundClick = (e) => {
      e?.stopPropagation();
      this.resetSleepTimer();
      if (this.fsm.isSleeping) {
        this.wakeUp();
        return;
      }
      this.fsm.cycleNextState();
    };

    window.addEventListener('mousemove', this.boundMouseMove, { passive: true });
    document.addEventListener('mouseleave', this.boundMouseLeave);
    this.element.addEventListener('mouseenter', this.boundMouseEnter);
    this.element.addEventListener('click', this.boundClick);
  }

  setState(newState) {
    if (this.fsm) this.fsm.setState(newState);
  }

  performGreeting() {
    if (this.fsm && this.fsm.currentState === 'idle') {
      this.fsm.setState('wave');
    }
  }

  wakeUp() {
    this.resetSleepTimer();
    if (this.fsm && this.fsm.isSleeping) {
      this.fsm.setState('wave');
    }
  }

  resetSleepTimer() {
    if (this.sleepTimeout) clearTimeout(this.sleepTimeout);
    this.sleepTimeout = setTimeout(() => {
      if (this.fsm && this.fsm.currentState === 'idle') {
        this.fsm.setState('sleep');
      }
    }, OWL_TIMERS_CONFIG.sleepInactivityMs);
  }

  destroy() {
    if (this.sleepTimeout) clearTimeout(this.sleepTimeout);
    if (this.physics) this.physics.stop();
    if (this.fsm) this.fsm.destroy();

    if (this.boundMouseMove) window.removeEventListener('mousemove', this.boundMouseMove);
    if (this.boundMouseLeave) document.removeEventListener('mouseleave', this.boundMouseLeave);
    if (this.element && this.boundMouseEnter) this.element.removeEventListener('mouseenter', this.boundMouseEnter);
    if (this.element && this.boundClick) this.element.removeEventListener('click', this.boundClick);

    if (this.element && this.element.parentElement) {
      this.element.parentElement.removeChild(this.element);
    }
  }
}

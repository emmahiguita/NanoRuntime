/**
 * @file owl_state_machine.js
 * @description Máquina de estados finitos y ciclo de vida de animaciones para NanoOwlAvatar.
 * 
 * Qué hace: Orquesta transiciones de poses, bucles autónomos y previene procesos zombi/fugas de timers.
 * Cómo funciona: Gestiona capas visuales con cross-fade elástico y limpia rigurosamente los temporizadores.
 * Por qué: Principio de Responsabilidad Única (SRP) y código libre de memory leaks.
 */

import { OWL_TIMERS_CONFIG as TIMERS } from './owl_config.js';

export class OwlStateMachine {
  constructor({ flightRig, stage, layers, onStateChange }) {
    this.flightRig = flightRig;
    this.stage = stage;
    this.layers = layers;
    this.onStateChange = onStateChange || (() => {});

    this.currentState = 'idle';
    this.isSleeping = false;
    this.activeTimers = new Set();
  }

  safeTimeout(callback, delay) {
    const id = setTimeout(() => {
      this.activeTimers.delete(id);
      callback();
    }, delay);
    this.activeTimers.add(id);
    return id;
  }

  clearAllTimers() {
    this.activeTimers.forEach((id) => clearTimeout(id));
    this.activeTimers.clear();
  }

  setState(newState) {
    if (this.currentState === newState || !this.flightRig) return;
    this.currentState = newState;
    this.isSleeping = newState === 'sleep';

    // 1. Clases de keyframe en Flight Rig y Stage
    this.flightRig.className = `nano-owl-flight-rig state-${newState}`;
    if (this.stage) {
      this.stage.className = `nano-owl-stage state-${newState}`;
    }

    // 2. Crossfade de capas con soporte para blink sobre idle
    Object.keys(this.layers).forEach((key) => {
      const layer = this.layers[key];
      if (layer) {
        const isActive = key === newState || (newState === 'idle' && key === 'idle');
        layer.classList.toggle('active', isActive);
      }
    });

    this.onStateChange(newState);

    // 3. Auto-retorno programado para estados temporales
    if (newState === 'wave') {
      this.safeTimeout(() => {
        if (this.currentState === 'wave') this.setState('idle');
      }, TIMERS.waveDurationMs);
    } else if (newState === 'curious') {
      this.safeTimeout(() => {
        if (this.currentState === 'curious') this.setState('idle');
      }, TIMERS.curiousDurationMs);
    } else if (newState === 'success') {
      this.safeTimeout(() => {
        if (this.currentState === 'success') this.setState('idle');
      }, 3500);
    }
  }

  performBlink() {
    if (this.isSleeping || this.currentState !== 'idle') return;
    if (!this.layers.blink || !this.layers.idle) return;

    this.layers.blink.classList.add('active');
    this.layers.idle.classList.remove('active');

    this.safeTimeout(() => {
      if (this.currentState === 'idle') {
        this.layers.idle.classList.add('active');
        this.layers.blink.classList.remove('active');
      }
    }, TIMERS.blinkDurationMs);
  }

  startAutonomousLoops(physics) {
    // Bucle de parpadeo natural
    const scheduleBlink = () => {
      const delay = Math.floor(Math.random() * (TIMERS.blinkMaxMs - TIMERS.blinkMinMs)) + TIMERS.blinkMinMs;
      this.safeTimeout(() => {
        this.performBlink();
        scheduleBlink();
      }, delay);
    };
    scheduleBlink();

    // Bucle de micro-sacadas oculares vivas
    const scheduleSaccade = () => {
      const delay = Math.floor(Math.random() * 2500) + 2000;
      this.safeTimeout(() => {
        if (this.currentState === 'idle' && !this.isSleeping && physics) {
          physics.eye.saccadeX = (Math.random() - 0.5) * 4.5;
          physics.eye.saccadeY = (Math.random() - 0.5) * 3.0;
          this.safeTimeout(() => {
            physics.eye.saccadeX = 0;
            physics.eye.saccadeY = 0;
          }, 500);
        }
        scheduleSaccade();
      }, delay);
    };
    scheduleSaccade();

    // Bucle de curiosidad esporádica (ladeo de cabeza)
    const scheduleCuriosity = () => {
      const delay = Math.floor(Math.random() * 8000) + 12000;
      this.safeTimeout(() => {
        if (this.currentState === 'idle' && !this.isSleeping) {
          this.setState('curious');
        }
        scheduleCuriosity();
      }, delay);
    };
    scheduleCuriosity();
  }

  cycleNextState() {
    const cycle = ['idle', 'wave', 'flying', 'sleep'];
    const currentIndex = cycle.indexOf(this.currentState);
    const nextIndex = (currentIndex + 1) % cycle.length;
    this.setState(cycle[nextIndex >= 0 ? nextIndex : 0]);
  }

  destroy() {
    this.clearAllTimers();
    this.currentState = 'destroyed';
  }
}

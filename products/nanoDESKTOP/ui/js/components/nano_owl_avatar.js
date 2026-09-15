/**
 * NanoOwlAvatar — Motor de Animación 3D Cinemático & Realista de Nano AI
 * 
 * Implementa cinemática procedimental avanzada, físicas elásticas por resorte (Spring-Damper),
 * micro-sacadas oculares vivas, respiración con compresión/estiramiento orgánico (Squash & Stretch),
 * cambios de peso de apoyo, luz especular volumétrica y partículas de polvo cósmico en 3D.
 */

export class NanoOwlAvatar {
  constructor(options = {}) {
    this.size = options.size || 118; // Proporción áurea en viewport
    this.container = options.container || null;
    this.currentState = 'idle';
    this.withHalo = options.withHalo !== false;
    this.interactive = options.interactive !== false;

    // Control de bucle y temporizadores
    this.rafId = null;
    this.blinkTimer = null;
    this.saccadeTimer = null;
    this.curiousTiltTimer = null;
    this.sleepTimeout = null;

    // Físicas 3D y Cinemática Procedimental (Springs & LERP)
    this.mouse = { x: 0, y: 0, targetX: 0, targetY: 0 };
    
    // Rotaciones angulares 3D
    this.rotX = { current: 0, target: 0, vel: 0 };
    this.rotY = { current: 0, target: 0, vel: 0 };
    this.rotZ = { current: 0, target: 0, vel: 0 };
    
    // Ojos y Micro-sacadas
    this.eye = { currentX: 0, currentY: 0, targetX: 0, targetY: 0, saccadeX: 0, saccadeY: 0 };
    
    // Estados dinámicos
    this.isHovered = false;
    this.isSleeping = false;
    this.isPetting = false;
    this.petTimer = null;

    // Mapeo de texturas en alta resolución sin fondo (canal alfa puro)
    this.assetMap = {
      idle: 'assets/owl_idle.png',
      blink: 'assets/owl_blink.png',
      listening: 'assets/owl_listening.png',
      thinking: 'assets/owl_thinking.png',
      responding: 'assets/owl_responding.png',
      success: 'assets/owl_success.png',
      fly: 'assets/owl_fly.png',
      wave: 'assets/owl_wake.png',
      sleep: 'assets/owl_sleep.png',
      error: 'assets/owl_error.png',
    };

    if (this.container) {
      this.mount(this.container);
    }
  }

  mount(container) {
    this.container = typeof container === 'string' ? document.getElementById(container) : container;
    if (!this.container) return;

    this.element = document.createElement('div');
    this.element.className = 'nano-owl-wrapper';
    this.element.style.setProperty('--owl-size', `${this.size}px`);

    this.element.innerHTML = `
      <!-- Halo Atmosférico Nebular (Plano Z: -45px) -->
      ${this.withHalo ? '<div class="nano-owl-halo" id="owl-halo" aria-hidden="true"></div>' : ''}
      
      <!-- Partículas de Polvo Cósmico Orbitantes 3D (Plano Z: -20px a +30px) -->
      <div class="nano-owl-stardust-container" id="owl-stardust" aria-hidden="true">
        <span class="stardust-sparkle p1"></span>
        <span class="stardust-sparkle p2"></span>
        <span class="stardust-sparkle p3"></span>
        <span class="stardust-sparkle p4"></span>
        <span class="stardust-sparkle p5"></span>
      </div>

      <!-- Sombra de Contacto Dinámica en Suelo 3D (Plano Z: -50px) -->
      <div class="nano-owl-ground-shadow" id="owl-shadow" aria-hidden="true"></div>

      <!-- Escenario 3D Riggeado con Centro en Pies (Plano Z: 0px) -->
      <div class="nano-owl-stage state-idle" id="owl-stage">
        <!-- Capas de Textura de Poses con Alpha Puro -->
        <img class="nano-owl-layer layer-idle active" src="${this.assetMap.idle}" alt="Nano AI — Asistente Soberano" />
        <img class="nano-owl-layer layer-blink" src="${this.assetMap.blink}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-listening" src="${this.assetMap.listening}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-thinking" src="${this.assetMap.thinking}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-responding" src="${this.assetMap.responding}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-success" src="${this.assetMap.success}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-fly" src="${this.assetMap.fly}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-wave" src="${this.assetMap.wave}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-sleep" src="${this.assetMap.sleep}" alt="" aria-hidden="true" />
        <img class="nano-owl-layer layer-error" src="${this.assetMap.error}" alt="" aria-hidden="true" />
        
        <!-- Capa de Luz Especular Dinámica 3D (Rim-Light Volumétrico) (Plano Z: +18px) -->
        <div class="nano-owl-rim-light" id="owl-rim-light" aria-hidden="true"></div>

        <!-- Reflejo Ocular Galáctico con Profundidad Esférica 3D (Plano Z: +28px) -->
        <div class="nano-owl-galaxy-eyes-gleam" id="owl-eyes-gleam" aria-hidden="true">
          <div class="galaxy-pupil-glare pupil-left">
            <span class="pupil-core-iris"></span>
            <span class="pupil-star-shimmer"></span>
          </div>
          <div class="galaxy-pupil-glare pupil-right">
            <span class="pupil-core-iris"></span>
            <span class="pupil-star-shimmer"></span>
          </div>
        </div>
      </div>
    `;

    this.container.innerHTML = '';
    this.container.appendChild(this.element);

    this.stage = this.element.querySelector('#owl-stage');
    this.halo = this.element.querySelector('#owl-halo');
    this.shadow = this.element.querySelector('#owl-shadow');
    this.rimLight = this.element.querySelector('#owl-rim-light');
    this.eyesGleam = this.element.querySelector('#owl-eyes-gleam');
    this.stardust = this.element.querySelector('#owl-stardust');

    this.layers = {
      idle: this.element.querySelector('.layer-idle'),
      blink: this.element.querySelector('.layer-blink'),
      listening: this.element.querySelector('.layer-listening'),
      thinking: this.element.querySelector('.layer-thinking'),
      responding: this.element.querySelector('.layer-responding'),
      success: this.element.querySelector('.layer-success'),
      fly: this.element.querySelector('.layer-fly'),
      wave: this.element.querySelector('.layer-wave'),
      sleep: this.element.querySelector('.layer-sleep'),
      error: this.element.querySelector('.layer-error'),
    };

    this.bindInteractions();
    this.startProceduralLoop();

    if (this.interactive) {
      this.startBlinkLoop();
      this.startSaccadeLoop();
      this.startCuriousTiltLoop();
      this.resetSleepTimer();

      // Saludo amistoso de bienvenida con elevación de ala
      setTimeout(() => {
        this.performGreeting();
      }, 750);
    }
  }

  bindInteractions() {
    this.onMouseMove = (e) => {
      this.resetSleepTimer();
      if (!this.element) return;

      const rect = this.element.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;

      // Coordenadas normalizadas con centro en el avatar (-1.0 a +1.0)
      const nx = (e.clientX - centerX) / (window.innerWidth / 2);
      const ny = (e.clientY - centerY) / (window.innerHeight / 2);

      this.mouse.targetX = Math.max(-1.1, Math.min(1.1, nx));
      this.mouse.targetY = Math.max(-1.1, Math.min(1.1, ny));
    };

    this.onMouseLeave = () => {
      this.mouse.targetX = 0;
      this.mouse.targetY = 0;
      this.isHovered = false;
    };

    this.onMouseEnter = () => {
      this.isHovered = true;
      this.wakeUp();
      this.triggerPettingMicroReaction();
    };

    this.onClick = () => {
      this.wakeUp();
      this.performGreeting();
    };

    window.addEventListener('mousemove', this.onMouseMove, { passive: true });
    document.addEventListener('mouseleave', this.onMouseLeave);
    window.addEventListener('keydown', () => this.wakeUp(), { passive: true });

    if (this.element) {
      this.element.addEventListener('mouseenter', this.onMouseEnter);
      this.element.addEventListener('click', this.onClick);
    }
  }

  triggerPettingMicroReaction() {
    this.isPetting = true;
    if (this.petTimer) clearTimeout(this.petTimer);
    this.petTimer = setTimeout(() => {
      this.isPetting = false;
    }, 600);
  }

  startProceduralLoop() {
    let lastTime = performance.now();

    const updatePhysics = (now) => {
      if (!this.stage) return;
      const dt = Math.min((now - lastTime) / 1000, 0.05); // Delta time limitado
      lastTime = now;
      const t = now * 0.001;

      // --- 1. LERP Suave del Mouse ---
      const easeMouse = 0.075;
      this.mouse.x += (this.mouse.targetX - this.mouse.x) * easeMouse;
      this.mouse.y += (this.mouse.targetY - this.mouse.y) * easeMouse;

      // --- 2. Cinemática de Respiración Orgánica (Compresión y Expansión Asimétrica) ---
      let breathSpeed = 1.6;
      let breathAmp = 0.024;
      if (this.isSleeping) {
        breathSpeed = 0.85;
        breathAmp = 0.038;
      } else if (this.currentState === 'thinking') {
        breathSpeed = 2.2;
        breathAmp = 0.018;
      }

      // Curva respiratoria con inhalación rápida y exhalación relajada
      const breathPhase = Math.sin(t * breathSpeed);
      const breathCurve = breathPhase * 0.7 + Math.sin(t * breathSpeed * 2) * 0.3;
      const squashX = 1.0 - breathCurve * (breathAmp * 0.6);
      const stretchY = 1.0 + breathCurve * breathAmp;
      const liftY = -breathCurve * (this.isSleeping ? 1.2 : 2.4);

      // --- 3. Cambio de Peso de Apoyo Orgánico (Foot-to-Foot Sway) ---
      const swaySpeed = 0.45;
      const footSwayAngle = Math.sin(t * swaySpeed) * (this.isSleeping ? 0.6 : 1.5);
      const footSwayX = Math.sin(t * swaySpeed) * 1.2;

      // --- 4. Rotación 3D con Resortes Físicos (Spring-Damper) ---
      let maxYaw = 15;
      let maxPitch = 9;

      if (this.currentState === 'thinking') {
        // En modo Thinking mira con mayor énfasis hacia la esquina superior derecha
        maxYaw = 10;
        maxPitch = 7;
      } else if (this.isSleeping) {
        maxYaw = 3;
        maxPitch = 2;
      }

      const targetRotY = this.mouse.x * maxYaw;
      const targetRotX = -this.mouse.y * maxPitch;
      // Inclinación lateral (Roll) derivada de la velocidad horizontal del giro
      const targetRotZ = footSwayAngle - (targetRotY - this.rotY.current) * 0.18;

      // Integración Spring-Damper
      const springK = 28;
      const damper = 7.5;

      const forceX = (targetRotX - this.rotX.current) * springK - this.rotX.vel * damper;
      const forceY = (targetRotY - this.rotY.current) * springK - this.rotY.vel * damper;
      const forceZ = (targetRotZ - this.rotZ.current) * springK - this.rotZ.vel * damper;

      this.rotX.vel += forceX * dt;
      this.rotY.vel += forceY * dt;
      this.rotZ.vel += forceZ * dt;

      this.rotX.current += this.rotX.vel * dt;
      this.rotY.current += this.rotY.vel * dt;
      this.rotZ.current += this.rotZ.vel * dt;

      // --- 5. Ojos: Seguimiento Curvado 3D + Micro-Sacadas Vivas ---
      const eyeEase = 0.12;
      const targetEyeX = this.mouse.x * 6.5 + this.eye.saccadeX;
      const targetEyeY = this.mouse.y * 4.8 + this.eye.saccadeY;

      this.eye.currentX += (targetEyeX - this.eye.currentX) * eyeEase;
      this.eye.currentY += (targetEyeY - this.eye.currentY) * eyeEase;

      // --- 6. Aplicar Transformaciones 3D al Escenario ---
      const hoverElevate = this.isHovered ? -4 : 0;
      const pettingJitter = this.isPetting ? Math.sin(t * 26) * 0.6 : 0;

      this.stage.style.transform = `
        translate3d(${footSwayX.toFixed(2)}px, ${(liftY + hoverElevate + pettingJitter).toFixed(2)}px, ${this.isHovered ? 14 : 0}px)
        rotateX(${this.rotX.current.toFixed(2)}deg)
        rotateY(${this.rotY.current.toFixed(2)}deg)
        rotateZ(${this.rotZ.current.toFixed(2)}deg)
        scale3d(${squashX.toFixed(3)}, ${stretchY.toFixed(3)}, 1)
      `;

      // --- 7. Sombra de Contacto Dinámica 3D ---
      if (this.shadow) {
        const shadowShiftX = -this.rotY.current * 1.35;
        const shadowBreathScale = (1.0 + breathCurve * 0.04) * (this.isHovered ? 0.90 : 1.0);
        const shadowOpacity = this.isSleeping ? 0.42 : (0.34 - breathCurve * 0.06);

        this.shadow.style.transform = `
          translateX(calc(-50% + ${shadowShiftX.toFixed(1)}px))
          rotateX(75deg)
          scale(${shadowBreathScale.toFixed(2)})
        `;
        this.shadow.style.opacity = shadowOpacity.toFixed(2);
      }

      // --- 8. Ojos Galácticos en Plano Z Frontal (+28px) ---
      if (this.eyesGleam) {
        this.eyesGleam.style.transform = `
          translate3d(${this.eye.currentX.toFixed(1)}px, ${this.eye.currentY.toFixed(1)}px, 28px)
        `;
      }

      // --- 9. Luz Especular Dinámica 3D (Simulación de Estudio Físico) ---
      if (this.rimLight) {
        const lightAngleX = 50 + this.mouse.x * 38;
        const lightAngleY = 38 + this.mouse.y * 38;
        const lightIntensity = this.isHovered ? 0.52 : 0.38;

        this.rimLight.style.background = `
          radial-gradient(circle at ${lightAngleX.toFixed(1)}% ${lightAngleY.toFixed(1)}%, 
            rgba(255, 255, 255, ${lightIntensity}) 0%, 
            rgba(129, 140, 248, ${(lightIntensity * 0.45).toFixed(2)}) 32%, 
            transparent 66%
          )
        `;
      }

      // --- 10. Partículas de Polvo Cósmico Orbitantes ---
      if (this.stardust) {
        const dustTiltX = -this.mouse.x * 10;
        const dustTiltY = -this.mouse.y * 8;
        this.stardust.style.transform = `
          translate3d(${dustTiltX.toFixed(1)}px, ${dustTiltY.toFixed(1)}px, 10px)
        `;
      }

      // --- 11. Halo Atmosférico Inverso ---
      if (this.halo) {
        const haloX = -this.mouse.x * 14;
        const haloY = -this.mouse.y * 12;
        this.halo.style.transform = `
          translate(calc(-50% + ${haloX.toFixed(1)}px), calc(-50% + ${haloY.toFixed(1)}px))
          translateZ(-45px)
        `;
      }

      this.rafId = requestAnimationFrame(updatePhysics);
    };

    this.rafId = requestAnimationFrame(updatePhysics);
  }

  setState(newState) {
    if (this.currentState === newState || !this.stage) return;
    this.currentState = newState;
    this.isSleeping = newState === 'sleep';

    // Actualizar clases de estado
    this.stage.className = `nano-owl-stage state-${newState}`;

    // Cross-fade hiper-limpio de capas
    Object.keys(this.layers).forEach((key) => {
      const layer = this.layers[key];
      if (layer) {
        const shouldBeActive = key === newState || (newState === 'idle' && key === 'idle');
        layer.classList.toggle('active', shouldBeActive);
      }
    });

    // Desencadenar secuencias cinemáticas ricas
    if (newState === 'success' || newState === 'fly') {
      this.triggerJoyFlySequence();
    } else if (newState === 'wave') {
      this.triggerWaveSequence();
    }
  }

  // --- Secuencias Cinemáticas Avanzadas ---

  performGreeting() {
    if (this.currentState !== 'idle') return;
    this.setState('wave');
    setTimeout(() => {
      if (this.currentState === 'wave') {
        this.setState('idle');
      }
    }, 2100);
  }

  triggerWaveSequence() {
    if (!this.stage) return;
    this.stage.classList.add('action-wave');
    setTimeout(() => {
      if (this.stage) this.stage.classList.remove('action-wave');
    }, 2100);
  }

  triggerJoyFlySequence() {
    if (!this.stage) return;
    this.stage.classList.add('action-joy-fly');
    setTimeout(() => {
      if (this.stage) this.stage.classList.remove('action-joy-fly');
      if (this.currentState === 'success' || this.currentState === 'fly') {
        this.setState('idle');
      }
    }, 2600);
  }

  performBlink() {
    if (!this.layers.blink || !this.layers.idle) return;
    if (this.isSleeping || this.currentState === 'wave' || this.currentState === 'fly') return;

    this.layers.blink.classList.add('active');
    this.layers.idle.classList.remove('active');

    setTimeout(() => {
      if (this.currentState === 'idle') {
        this.layers.idle.classList.add('active');
        this.layers.blink.classList.remove('active');
      }
    }, 150);
  }

  startBlinkLoop() {
    this.stopBlinkLoop();
    const schedule = () => {
      const delay = Math.floor(Math.random() * 4500) + 4000;
      this.blinkTimer = setTimeout(() => {
        if (this.currentState === 'idle' || this.currentState === 'listening') {
          this.performBlink();
        }
        schedule();
      }, delay);
    };
    schedule();
  }

  startSaccadeLoop() {
    this.stopSaccadeLoop();
    const scheduleSaccade = () => {
      // Micro-sacadas oculares vivas cada 2.0 a 4.5 segundos
      const delay = Math.floor(Math.random() * 2500) + 2000;
      this.saccadeTimer = setTimeout(() => {
        if (this.currentState === 'idle' && !this.isSleeping) {
          // Salto ocular sutil (-3px a +3px)
          this.eye.saccadeX = (Math.random() - 0.5) * 5;
          this.eye.saccadeY = (Math.random() - 0.5) * 3.5;

          // Regreso elástico tras 600ms
          setTimeout(() => {
            this.eye.saccadeX = 0;
            this.eye.saccadeY = 0;
          }, 600);
        }
        scheduleSaccade();
      }, delay);
    };
    scheduleSaccade();
  }

  startCuriousTiltLoop() {
    this.stopCuriousTiltLoop();
    const scheduleTilt = () => {
      const delay = Math.floor(Math.random() * 6000) + 7500;
      this.curiousTiltTimer = setTimeout(() => {
        if (this.currentState === 'idle' && !this.isSleeping) {
          // Cabeceo curioso con dirección aleatoria (+ o -)
          const tiltDir = Math.random() > 0.5 ? 1 : -1;
          const tiltClass = tiltDir > 0 ? 'subtle-curious-tilt-right' : 'subtle-curious-tilt-left';
          
          this.stage.classList.add(tiltClass);
          setTimeout(() => {
            if (this.stage) {
              this.stage.classList.remove('subtle-curious-tilt-right');
              this.stage.classList.remove('subtle-curious-tilt-left');
            }
          }, 2400);
        }
        scheduleTilt();
      }, delay);
    };
    scheduleTilt();
  }

  resetSleepTimer() {
    if (this.sleepTimeout) clearTimeout(this.sleepTimeout);
    // Modo sueño tras 36 segundos sin interacción
    this.sleepTimeout = setTimeout(() => {
      if (this.currentState === 'idle') {
        this.setState('sleep');
      }
    }, 36000);
  }

  wakeUp() {
    this.resetSleepTimer();
    if (this.isSleeping || this.currentState === 'sleep') {
      this.setState('wave');
      setTimeout(() => {
        if (this.currentState === 'wave') {
          this.setState('idle');
        }
      }, 1500);
    }
  }

  stopBlinkLoop() {
    if (this.blinkTimer) clearTimeout(this.blinkTimer);
  }

  stopSaccadeLoop() {
    if (this.saccadeTimer) clearTimeout(this.saccadeTimer);
  }

  stopCuriousTiltLoop() {
    if (this.curiousTiltTimer) clearTimeout(this.curiousTiltTimer);
  }

  destroy() {
    this.stopBlinkLoop();
    this.stopSaccadeLoop();
    this.stopCuriousTiltLoop();
    if (this.sleepTimeout) clearTimeout(this.sleepTimeout);
    if (this.petTimer) clearTimeout(this.petTimer);
    if (this.rafId) cancelAnimationFrame(this.rafId);

    window.removeEventListener('mousemove', this.onMouseMove);
    document.removeEventListener('mouseleave', this.onMouseLeave);

    if (this.element && this.element.parentElement) {
      this.element.parentElement.removeChild(this.element);
    }
  }
}

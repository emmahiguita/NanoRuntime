import { NanoIcon } from '../../components/nano_icon.js';
import { appState } from '../../core/state.js';
import { terminalService } from '../terminal/terminal_service.js';

export class HomeView {
  constructor(container) {
    this.container = container;
    this.blinkTimer = null;
    this.telemetryTimer = null;
    this.bubbleTimer = null;
    this.isBlinking = false;
    this.cpuValue = 18;
    this.ramValue = 42;
    this.gpuValue = 27;
    this.init();
  }

  init() {
    this.render();
    this.bindEvents();
    this.startMascotBlinkLoop();
    this.startTelemetrySim();
    appState.subscribe((state) => this.updateTelemetry(state.telemetry));
  }

  render() {
    // Cálculo de offsets SVG iniciales (Circunferencia = 2 * PI * 26 = 163.36)
    const circ = 163.36;
    const cpuOffset = circ * (1 - this.cpuValue / 100);
    const ramOffset = circ * (1 - this.ramValue / 100);
    const gpuOffset = circ * (1 - this.gpuValue / 100);

    this.container.innerHTML = `
      <div class="home-scroll-container">
        <!-- Hero Banner Inteligente Ivory Cosmic -->
        <section class="home-hero-card">
          <div class="hero-celestial-backdrop"></div>

          <div class="hero-text-col">
            <div class="hero-badge-pill">
              <span class="sparkle-icon">${NanoIcon.get('sparkle', 12)}</span>
              <span>Inteligencia Autónoma Local</span>
            </div>
            <h1 class="hero-title">Hola, Emma <span class="wave-emoji">👋</span></h1>
            <p class="hero-subtitle">¿Qué quieres crear hoy?</p>
            <p class="hero-caption">Convierte ideas en realidades extraordinarias con modelos locales y agentes autónomos.</p>
            <div class="hero-quote">
              <span>"La inteligencia no tiene límites, solo principios."</span>
              <span class="hero-quote-author">— Nano AI</span>
            </div>
          </div>
          
          <div class="hero-mascot-col">
            <div class="mascot-halo"></div>
            <div class="hero-crystal-pedestal"></div>
            
            <div class="hero-mascot-wrapper" id="hero-mascot-box" title="Haz clic para interactuar con Nano">
              <div class="mascot-speech-bubble" id="mascot-speech-bubble" style="display: none;">
                ${NanoIcon.get('sparkle', 13)} <span id="mascot-speech-text">¡Hola Emma! Listo para ayudarte.</span>
              </div>
              <img 
                src="assets/owl_idle.png" 
                alt="Búho Blanco Nano" 
                class="hero-mascot-img" 
                id="hero-mascot-img" 
              />
            </div>

            <div class="hero-vertical-tags">
              <span>EXPLORA</span>
              <span class="tag-dot"></span>
              <span>CREA</span>
              <span class="tag-dot"></span>
              <span>APRENDE</span>
              <span class="tag-dot"></span>
              <span>AUTOMATIZA</span>
              <span class="tag-dot"></span>
              <span>EVOLUCIONA</span>
            </div>
          </div>
        </section>

        <!-- Fila de 6 Atajos Principales -->
        <section class="shortcuts-row">
          <button type="button" class="shortcut-card" data-route="chat">
            <div class="shortcut-icon-wrapper blue">${NanoIcon.get('chat', 22)}</div>
            <span class="shortcut-title">Chat IA</span>
            <span class="shortcut-desc">Conversación sin límites</span>
          </button>

          <button type="button" class="shortcut-card" data-route="models">
            <div class="shortcut-icon-wrapper purple">${NanoIcon.get('models', 22)}</div>
            <span class="shortcut-title">Modelos</span>
            <span class="shortcut-desc">Gestiona modelos GGUF</span>
          </button>

          <button type="button" class="shortcut-card" data-route="terminal">
            <div class="shortcut-icon-wrapper cyan">${NanoIcon.get('terminal', 22)}</div>
            <span class="shortcut-title">Terminal</span>
            <span class="shortcut-desc">Control total de tu sistema</span>
          </button>

          <button type="button" class="shortcut-card" data-route="automation">
            <div class="shortcut-icon-wrapper indigo">${NanoIcon.get('automation', 22)}</div>
            <span class="shortcut-title">Automatización</span>
            <span class="shortcut-desc">Agentes y flujos inteligentes</span>
          </button>

          <button type="button" class="shortcut-card" data-route="vision">
            <div class="shortcut-icon-wrapper emerald">${NanoIcon.get('vision', 22)}</div>
            <span class="shortcut-title">Visión</span>
            <span class="shortcut-desc">Analiza imágenes y documentos</span>
          </button>

          <button type="button" class="shortcut-card" data-route="tools">
            <div class="shortcut-icon-wrapper slate">${NanoIcon.get('tools', 22)}</div>
            <span class="shortcut-title">Herramientas</span>
            <span class="shortcut-desc">Todo en un solo lugar</span>
          </button>
        </section>

        <!-- Panel Inferior Dual: Terminal Funcional con Atmósfera + Telemetría Real -->
        <section class="home-dual-panel">
          <!-- Terminal Integrada -->
          <div class="home-terminal-card">
            <div class="terminal-planet-glow"></div>

            <div class="terminal-card-topbar">
              <div class="terminal-dots">
                <span class="terminal-dot dot-red" title="Cerrar"></span>
                <span class="terminal-dot dot-yellow" title="Minimizar"></span>
                <span class="terminal-dot dot-green" title="Maximizar"></span>
              </div>
              <div class="terminal-card-title">
                ${NanoIcon.get('terminal', 13)}
                <span>Terminal Core</span>
                <span class="terminal-session-pill">nanortime-core</span>
              </div>
              <div class="terminal-actions">
                <button type="button" class="btn-terminal-pill" id="home-btn-diag" title="Ejecutar diagnósticos rápidos del sistema">
                  ${NanoIcon.get('refresh', 11)} Diagnósticos
                </button>
                <button type="button" class="btn-terminal-pill" id="home-btn-clear" title="Limpiar salida">
                  ${NanoIcon.get('clear', 11)} Limpiar
                </button>
              </div>
            </div>

            <div id="home-terminal-output" class="home-terminal-body">
              <div class="term-line sys">nanoRUNTIME Diagnostics Console v0.2.0 [Ivory Cosmic Edition]</div>
              <div class="term-line sys">IPC Socket conectado: 127.0.0.1:4200 (Modo Seguro Local)</div>
              <div class="term-line info">Escribe "help" para ver la lista de comandos disponibles.</div>
            </div>

            <div class="home-terminal-inputbar">
              <span class="term-prompt">&gt;</span>
              <input type="text" id="home-term-input" placeholder="Escribe un comando (ej: help, sysinfo, models, test)..." autocomplete="off" spellcheck="false" />
              <span class="term-engine-pill">nanortime-core</span>
            </div>
          </div>

          <!-- Panel Lateral de Telemetría & Modelo Activo -->
          <div class="home-side-widgets">
            <!-- Widget Telemetría SVG Radiales -->
            <div class="telemetry-widget-card">
              <div class="widget-header">
                <span class="widget-title">
                  <span>Sistema en tiempo real</span>
                  <span class="sparkle-icon" style="color: var(--accent-status);">${NanoIcon.get('cpu', 13)}</span>
                </span>
              </div>
              <div class="gauges-row">
                <div class="gauge-item">
                  <div class="gauge-container">
                    <svg class="gauge-svg" viewBox="0 0 64 64">
                      <circle class="gauge-track" cx="32" cy="32" r="26"></circle>
                      <circle class="gauge-progress blue" id="gauge-cpu-circle" cx="32" cy="32" r="26" 
                        stroke-dasharray="163.36" stroke-dashoffset="${cpuOffset}"></circle>
                    </svg>
                    <span class="gauge-value-text" id="cpu-pct">${this.cpuValue}%</span>
                  </div>
                  <span class="gauge-label">CPU</span>
                </div>

                <div class="gauge-item">
                  <div class="gauge-container">
                    <svg class="gauge-svg" viewBox="0 0 64 64">
                      <circle class="gauge-track" cx="32" cy="32" r="26"></circle>
                      <circle class="gauge-progress violet" id="gauge-ram-circle" cx="32" cy="32" r="26" 
                        stroke-dasharray="163.36" stroke-dashoffset="${ramOffset}"></circle>
                    </svg>
                    <span class="gauge-value-text" id="ram-pct">${this.ramValue}%</span>
                  </div>
                  <span class="gauge-label">RAM</span>
                </div>

                <div class="gauge-item">
                  <div class="gauge-container">
                    <svg class="gauge-svg" viewBox="0 0 64 64">
                      <circle class="gauge-track" cx="32" cy="32" r="26"></circle>
                      <circle class="gauge-progress emerald" id="gauge-gpu-circle" cx="32" cy="32" r="26" 
                        stroke-dasharray="163.36" stroke-dashoffset="${gpuOffset}"></circle>
                    </svg>
                    <span class="gauge-value-text" id="gpu-pct">${this.gpuValue}%</span>
                  </div>
                  <span class="gauge-label">GPU</span>
                </div>
              </div>
            </div>

            <!-- Widget Modelo Activo -->
            <div class="model-widget-card">
              <div class="widget-header">
                <span class="widget-title">
                  <span>Modelo activo</span>
                  ${NanoIcon.get('sparkle', 12)}
                </span>
              </div>
              <div class="active-model-chip">
                <div class="model-icon-box">${NanoIcon.get('models', 18)}</div>
                <div class="model-meta-info">
                  <span class="model-name-text">Phi-3-mini-4k-instruct</span>
                  <span class="model-status-text">
                    <span class="dot-green"></span> Listo • 3.8B Q4_K_M
                  </span>
                </div>
              </div>
            </div>

            <!-- Acciones Rápidas (2x2 Grid) -->
            <div class="quick-actions-card">
              <span class="widget-title">Acciones rápidas</span>
              <div class="quick-buttons-grid">
                <button type="button" class="btn-quick" data-action="new-session">
                  ${NanoIcon.get('plus', 14)} <span>Nueva sesión</span>
                </button>
                <button type="button" class="btn-quick" data-action="load-model">
                  ${NanoIcon.get('models', 14)} <span>Cargar modelo</span>
                </button>
                <button type="button" class="btn-quick" data-action="analyze-image">
                  ${NanoIcon.get('vision', 14)} <span>Analizar imagen</span>
                </button>
                <button type="button" class="btn-quick" data-action="create-agent">
                  ${NanoIcon.get('agent', 14)} <span>Crear agente</span>
                </button>
              </div>
            </div>
          </div>
        </section>

        <!-- Barra Inferior de 5 Píldoras de Acciones Canónicas -->
        <section class="bottom-action-toolbar">
          <button type="button" class="action-pill-btn" data-pill-action="search">
            ${NanoIcon.get('search', 15)}
            <span>Buscar</span>
          </button>

          <button type="button" class="action-pill-btn" data-pill-action="generate-image">
            ${NanoIcon.get('image', 15)}
            <span>Generar imagen</span>
          </button>

          <button type="button" class="action-pill-btn" data-pill-action="analyze-file">
            ${NanoIcon.get('fileSearch', 15)}
            <span>Analizar archivo</span>
          </button>

          <button type="button" class="action-pill-btn" data-pill-action="run-command">
            ${NanoIcon.get('terminal', 15)}
            <span>Ejecutar comando</span>
          </button>

          <button type="button" class="action-pill-btn" data-pill-action="create-automation">
            ${NanoIcon.get('automation', 15)}
            <span>Crear automatización</span>
          </button>
        </section>
      </div>
    `;
  }

  bindEvents() {
    // Click shortcuts to navigate
    this.container.querySelectorAll('.shortcut-card').forEach((card) => {
      card.addEventListener('click', () => {
        const route = card.dataset.route;
        const navBtn = document.querySelector(`[data-tab="${route}"]`);
        navBtn?.click();
      });
    });

    // Integrated terminal interaction
    const termInput = this.container.querySelector('#home-term-input');
    const termOutput = this.container.querySelector('#home-terminal-output');
    const clearBtn = this.container.querySelector('#home-btn-clear');
    const diagBtn = this.container.querySelector('#home-btn-diag');

    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        if (termOutput) termOutput.innerHTML = '';
      });
    }

    if (diagBtn) {
      diagBtn.addEventListener('click', () => {
        this.runDiagnostics(termOutput);
      });
    }

    if (termInput) {
      termInput.addEventListener('keydown', async (e) => {
        if (e.key === 'Enter') {
          const val = termInput.value.trim();
          if (!val) return;
          termInput.value = '';

          const echo = document.createElement('div');
          echo.className = 'term-line input-echo';
          echo.textContent = `> ${val}`;
          termOutput.appendChild(echo);

          try {
            const res = await terminalService.executeCommand(val);
            if (res) {
              if (res.type === 'clear') {
                termOutput.innerHTML = '';
              } else {
                const out = document.createElement('div');
                out.className = `term-line ${res.type}`;
                out.textContent = res.output;
                termOutput.appendChild(out);
              }
            }
          } catch (err) {
            const errEl = document.createElement('div');
            errEl.className = 'term-line error';
            errEl.textContent = `Error: ${err.message || err}`;
            termOutput.appendChild(errEl);
          }
          termOutput.scrollTop = termOutput.scrollHeight;
        }
      });
    }

    // Quick Action Buttons
    this.container.querySelectorAll('.btn-quick').forEach((btn) => {
      btn.addEventListener('click', () => {
        const action = btn.dataset.action;
        if (action === 'new-session') {
          const chatBtn = document.querySelector('[data-tab="chat"]');
          chatBtn?.click();
        } else if (action === 'load-model') {
          const modelsBtn = document.querySelector('[data-tab="models"]');
          modelsBtn?.click();
        } else if (action === 'analyze-image') {
          const visionBtn = document.querySelector('[data-tab="vision"]');
          visionBtn?.click();
        } else if (action === 'create-agent') {
          const autoBtn = document.querySelector('[data-tab="automation"]');
          autoBtn?.click();
        }
      });
    });

    // 5 Bottom Action Pills
    this.container.querySelectorAll('.action-pill-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        const pillAction = btn.dataset.pillAction;
        this.handlePillAction(pillAction);
      });
    });

    // Mascot Interaction (Hover listening & Click speech bubble)
    const mascotBox = this.container.querySelector('#hero-mascot-box');
    const mascotImg = this.container.querySelector('#hero-mascot-img');

    if (mascotBox && mascotImg) {
      mascotBox.addEventListener('mouseenter', () => {
        if (!this.isBlinking) {
          mascotImg.src = 'assets/owl_listening.png';
        }
        this.showMascotSpeech('¡Hola Emma! Dime qué necesitas.');
      });

      mascotBox.addEventListener('mouseleave', () => {
        if (!this.isBlinking) {
          mascotImg.src = 'assets/owl_idle.png';
        }
        this.hideMascotSpeech();
      });

      mascotBox.addEventListener('click', () => {
        const phrases = [
          '¡Siempre despierto para crear contigo! 🌟',
          'Tus modelos locales están listos al 100%.',
          'Recuerda: la inteligencia empieza con tus ideas.',
          '¡Nano AI está activo y completamente privado!',
          '¿Probamos ejecutar una automatización hoy?'
        ];
        const randomPhrase = phrases[Math.floor(Math.random() * phrases.length)];
        mascotImg.src = 'assets/owl_thinking.png';
        this.showMascotSpeech(randomPhrase, 3500);
        setTimeout(() => {
          if (!this.isBlinking) {
            mascotImg.src = 'assets/owl_idle.png';
          }
        }, 1200);
      });
    }
  }

  showMascotSpeech(text, duration = 2800) {
    const bubble = this.container.querySelector('#mascot-speech-bubble');
    const bubbleText = this.container.querySelector('#mascot-speech-text');
    if (!bubble || !bubbleText) return;

    bubbleText.textContent = text;
    bubble.style.display = 'flex';

    if (this.bubbleTimer) clearTimeout(this.bubbleTimer);
    this.bubbleTimer = setTimeout(() => {
      this.hideMascotSpeech();
    }, duration);
  }

  hideMascotSpeech() {
    const bubble = this.container.querySelector('#mascot-speech-bubble');
    if (bubble) bubble.style.display = 'none';
  }

  /**
   * Bucle natural de parpadeo fisiológico (idle <-> blink durante 160ms).
   */
  startMascotBlinkLoop() {
    if (this.blinkTimer) clearInterval(this.blinkTimer);

    const scheduleNextBlink = () => {
      const delay = Math.floor(Math.random() * (5200 - 3200 + 1)) + 3200; // Entre 3.2s y 5.2s
      this.blinkTimer = setTimeout(() => {
        const mascotImg = this.container.querySelector('#hero-mascot-img');
        if (mascotImg && !mascotImg.src.includes('listening') && !mascotImg.src.includes('thinking')) {
          this.isBlinking = true;
          mascotImg.src = 'assets/owl_blink.png';
          setTimeout(() => {
            mascotImg.src = 'assets/owl_idle.png';
            this.isBlinking = false;
            scheduleNextBlink();
          }, 160); // 160ms fisiológico humano/animal
        } else {
          scheduleNextBlink();
        }
      }, delay);
    };

    scheduleNextBlink();
  }

  /**
   * Simulación sutil de fluctuación de telemetría para dar vida al panel.
   */
  startTelemetrySim() {
    if (this.telemetryTimer) clearInterval(this.telemetryTimer);

    this.telemetryTimer = setInterval(() => {
      // CPU fluctúa entre 16% y 24%
      this.cpuValue = Math.min(30, Math.max(12, this.cpuValue + (Math.floor(Math.random() * 5) - 2)));
      // GPU fluctúa entre 24% y 32%
      this.gpuValue = Math.min(40, Math.max(20, this.gpuValue + (Math.floor(Math.random() * 5) - 2)));

      this.updateGauge('cpu', this.cpuValue);
      this.updateGauge('gpu', this.gpuValue);
    }, 3200);
  }

  updateGauge(name, value) {
    const circ = 163.36;
    const offset = circ * (1 - value / 100);
    const circle = this.container.querySelector(`#gauge-${name}-circle`);
    const label = this.container.querySelector(`#${name}-pct`);
    if (circle) circle.style.strokeDashoffset = offset;
    if (label) label.textContent = `${value}%`;
  }

  updateTelemetry(telemetry) {
    if (!telemetry) return;
    if (telemetry.total_memory_mb) {
      const pct = Math.round((telemetry.used_memory_mb / telemetry.total_memory_mb) * 100);
      this.ramValue = pct;
      this.updateGauge('ram', pct);
    }
  }

  runDiagnostics(termOutput) {
    if (!termOutput) return;
    const lines = [
      '[DIAGNOSTIC] Iniciando chequeo de subsistemas nanoRUNTIME...',
      '[OK] IPC Socket: 127.0.0.1:4200 conectado y respondiendo (0.4ms)',
      `[OK] Memoria RAM Asignada: ${this.ramValue}% disponible para inferencia`,
      `[OK] Acelerador GPU: Activo (${this.gpuValue}% carga de buffers)`,
      '[OK] Modelo Phi-3-mini-4k-instruct: Cargado en memoria RAM/VRAM',
      '[OK] Subsistema de Automatización: Reglas listas • 0 fallos detectados',
      '[STATUS] Todo listo. El ecosistema Nano AI opera en parámetros óptimos.'
    ];

    lines.forEach((line, idx) => {
      setTimeout(() => {
        const el = document.createElement('div');
        el.className = 'term-line diag';
        el.textContent = line;
        termOutput.appendChild(el);
        termOutput.scrollTop = termOutput.scrollHeight;
      }, idx * 120);
    });
  }

  handlePillAction(action) {
    switch (action) {
      case 'search': {
        const input = document.getElementById('global-search-input');
        input?.focus();
        input?.select();
        break;
      }
      case 'generate-image': {
        const visionBtn = document.querySelector('[data-tab="vision"]');
        visionBtn?.click();
        break;
      }
      case 'analyze-file': {
        const filesBtn = document.querySelector('[data-tab="files"]');
        filesBtn?.click();
        break;
      }
      case 'run-command': {
        const termInput = this.container.querySelector('#home-term-input');
        termInput?.focus();
        break;
      }
      case 'create-automation': {
        const autoBtn = document.querySelector('[data-tab="automation"]');
        autoBtn?.click();
        break;
      }
    }
  }

  destroy() {
    if (this.blinkTimer) clearTimeout(this.blinkTimer);
    if (this.telemetryTimer) clearInterval(this.telemetryTimer);
    if (this.bubbleTimer) clearTimeout(this.bubbleTimer);
  }
}

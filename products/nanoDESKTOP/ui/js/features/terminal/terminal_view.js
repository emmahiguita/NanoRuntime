/**
 * TerminalView: Componente de interfaz de usuario para la terminal interactiva.
 * 
 * QUÉ HACE: Renderiza la ventana de consola y enlaza eventos de teclado con el
 * backend nativo PTY o con el motor de diagnóstico local.
 * 
 * CÓMO FUNCIONA: En entorno Tauri Desktop, activa el flujo PTY bidireccional
 * escribiendo directamente en stdin. Si está en entorno web puro, evalúa los
 * comandos mediante el intérprete de diagnóstico.
 * 
 * POR QUÉ: Ofrece una experiencia de consola real sin romper la compatibilidad web.
 */

import { terminalService } from './terminal_service.js';

export class TerminalView {
  constructor(containerElement) {
    this.container = containerElement;
    this.isPtyActive = false;
    this.init();
  }

  async init() {
    this.render();
    this.bindEvents();

    // Intento de conexión al PTY nativo de Tauri
    const ptyStarted = await terminalService.startPty({
      onData: (chunk) => this.appendRaw(chunk),
      onExit: () => this.appendLine('sys', '\n[Proceso de Shell Finalizado]'),
    });

    this.isPtyActive = ptyStarted;
    const badge = this.container.querySelector('.term-badge-ready');

    if (ptyStarted) {
      if (badge) badge.textContent = 'Native PTY Active';
      this.appendLine('sys', 'NanoAI Native PTY Terminal iniciada correctamente.\n');
    } else {
      if (badge) badge.textContent = 'Diagnostics Shell';
      this.appendLine('sys', 'nanoRUNTIME Diagnostics Console v0.1.0');
      this.appendLine('sys', 'Escribe "help" para ver los comandos disponibles.\n');
    }
  }

  render() {
    this.container.innerHTML = `
      <div class="terminal-container-view">
        <div class="terminal-mac-header">
          <div class="terminal-dots">
            <span class="terminal-dot dot-red"></span>
            <span class="terminal-dot dot-yellow"></span>
            <span class="terminal-dot dot-green"></span>
          </div>
          <div class="terminal-title-center">
            <span class="terminal-tag">● Nano Terminal</span>
            <span class="terminal-title-text">Sovereign Shell — Native PTY</span>
          </div>
          <div class="terminal-header-tools">
            <button type="button" class="btn-term-header-pill" id="btn-term-clear">Limpiar</button>
          </div>
        </div>

        <div id="full-terminal-output" class="terminal-screen-output"></div>

        <div class="terminal-command-input-bar">
          <span class="terminal-chevron">&gt;</span>
          <input 
            type="text" 
            id="full-terminal-input" 
            class="terminal-real-input" 
            placeholder="Introduce comandos (dir, echo, git, python, etc.)..." 
            autocomplete="off" 
            spellcheck="false"
          />
          <span class="term-badge-ready">Conectando...</span>
        </div>
      </div>
    `;

    this.outputEl = this.container.querySelector('#full-terminal-output');
    this.inputEl = this.container.querySelector('#full-terminal-input');
  }

  bindEvents() {
    this.container.querySelector('#btn-term-clear')?.addEventListener('click', () => {
      if (this.outputEl) this.outputEl.innerHTML = '';
    });

    this.inputEl.addEventListener('keydown', async (e) => {
      if (e.key === 'Enter') {
        const val = this.inputEl.value;
        this.inputEl.value = '';

        if (this.isPtyActive) {
          // Enrutamiento directo al stdin del proceso PTY
          await terminalService.writePty(`${val}\r\n`);
        } else {
          // Modo diagnóstico fallback
          if (!val.trim()) return;
          this.appendLine('input-echo', `> ${val}`);
          try {
            const res = await terminalService.executeCommand(val);
            if (res) {
              if (res.type === 'clear') this.outputEl.innerHTML = '';
              else this.appendLine(res.type, res.output);
            }
          } catch (err) {
            this.appendLine('error', `Error: ${err.message || err}`);
          }
        }
      }
    });
  }

  appendRaw(chunk) {
    const span = document.createElement('span');
    span.className = 'terminal-raw-text';
    span.textContent = chunk;
    this.outputEl.appendChild(span);
    this.outputEl.scrollTop = this.outputEl.scrollHeight;
  }

  appendLine(type, text) {
    const line = document.createElement('div');
    line.className = `terminal-line ${type}`;
    line.textContent = text;
    this.outputEl.appendChild(line);
    this.outputEl.scrollTop = this.outputEl.scrollHeight;
  }
}

import { terminalService } from './terminal_service.js';

export class TerminalView {
  constructor(containerElement) {
    this.container = containerElement;
    this.init();
  }

  init() {
    this.render();
    this.bindEvents();
    this.appendLine('sys', 'nanoRUNTIME Diagnostics Console v0.2.0');
    this.appendLine('sys', 'Escribe "help" para ver los comandos disponibles.\n');
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
            <span class="terminal-tag">● Nano Core</span>
            <span class="terminal-title-text">Terminal — nanortime-core</span>
          </div>
          <div class="terminal-header-tools">
            <button type="button" class="btn-term-header-pill" id="btn-term-clear">Limpiar</button>
            <button type="button" class="btn-term-header-pill" id="btn-term-help">Ayuda</button>
          </div>
        </div>

        <div id="full-terminal-output" class="terminal-screen-output"></div>

        <div class="terminal-command-input-bar">
          <span class="terminal-chevron">&gt;</span>
          <input 
            type="text" 
            id="full-terminal-input" 
            class="terminal-real-input" 
            placeholder="Escribe un comando (status, models, infer <prompt>, clear)..." 
            autocomplete="off" 
            spellcheck="false"
          />
          <span class="term-badge-ready">nanortime-core ready</span>
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

    this.container.querySelector('#btn-term-help')?.addEventListener('click', async () => {
      const res = await terminalService.executeCommand('help');
      if (res) this.appendLine(res.type, res.output);
    });

    this.inputEl.addEventListener('keydown', async (e) => {
      if (e.key === 'Enter') {
        const val = this.inputEl.value;
        if (!val.trim()) return;

        this.inputEl.value = '';
        this.appendLine('input-echo', `> ${val}`);

        try {
          const result = await terminalService.executeCommand(val);
          if (result) {
            if (result.type === 'clear') {
              this.outputEl.innerHTML = '';
            } else {
              this.appendLine(result.type, result.output);
            }
          }
        } catch (err) {
          this.appendLine('error', `Error: ${err.message || err}`);
        }
      } else if (e.key === 'ArrowUp') {
        if (terminalService.history.length > 0 && terminalService.historyIndex > 0) {
          terminalService.historyIndex--;
          this.inputEl.value = terminalService.history[terminalService.historyIndex] || '';
        }
      } else if (e.key === 'ArrowDown') {
        if (terminalService.historyIndex < terminalService.history.length - 1) {
          terminalService.historyIndex++;
          this.inputEl.value = terminalService.history[terminalService.historyIndex] || '';
        } else {
          terminalService.historyIndex = terminalService.history.length;
          this.inputEl.value = '';
        }
      }
    });
  }

  appendLine(type, text) {
    const line = document.createElement('div');
    line.className = `terminal-line ${type}`;
    line.textContent = text;
    this.outputEl.appendChild(line);
    this.outputEl.scrollTop = this.outputEl.scrollHeight;
  }
}

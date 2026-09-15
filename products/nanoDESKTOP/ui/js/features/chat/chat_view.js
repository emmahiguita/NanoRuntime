import { appState } from '../../core/state.js';
import { chatService } from './chat_service.js';
import { NanoIcon } from '../../components/nano_icon.js';
import { NanoOwlAvatar } from '../../components/nano_owl_avatar.js';

export class ChatView {
  constructor(containerOrId) {
    this.container = typeof containerOrId === 'string'
      ? document.getElementById(containerOrId)
      : containerOrId;
    this.deepThinkActive = true;
    this.webActive = false;
    this.toolsActive = false;
    this.attachedFiles = [];
    this.owlAvatar = null;
    this.speechRecognition = null;
    this.isRecordingVoice = false;
    this.init();
  }

  init() {
    if (!this.container) return;

    this.container.innerHTML = `
      <div class="chat-wrapper-clean">
        <div id="chat-messages" class="chat-stream-container"></div>
        
        <!-- Floating Composer (Superficie Ivory / Frost) -->
        <div class="chat-composer-outer">
          <form id="chat-form" class="chat-composer-box">
            <!-- Selector de Archivos Oculto -->
            <input 
              type="file" 
              id="composer-file-input" 
              style="display: none;" 
              multiple 
              accept=".txt,.md,.json,.csv,.py,.rs,.js,.log,.pdf" 
            />

            <!-- Fila de Chips de Archivos Adjuntos -->
            <div id="composer-attachments-row" class="composer-attachments-row"></div>

            <div class="composer-top-row">
              <textarea 
                id="chat-input" 
                class="composer-textarea" 
                placeholder="Envía un mensaje o escribe '/' para comandos..." 
                rows="1"
                autocomplete="off"
                spellcheck="false"
              ></textarea>
            </div>
            
            <div class="composer-actions-row">
              <div class="composer-tools-left">
                <button type="button" class="btn-composer-pill" id="composer-btn-attach" title="Adjuntar documento o código local para RAG soberano">
                  ${NanoIcon.get('paperclip', 14)} <span>Adjuntar</span>
                </button>
                <button type="button" class="btn-composer-pill active" id="composer-btn-deepthink" title="Pensar: Razonamiento profundo paso a paso (R1)">
                  ${NanoIcon.get('brain', 14)} <span>Pensar</span>
                </button>
                <button type="button" class="btn-composer-pill" id="composer-btn-web" title="Web: Búsqueda y conocimiento en internet">
                  ${NanoIcon.get('globe', 14)} <span>Web</span>
                </button>
                <button type="button" class="btn-composer-pill" id="composer-btn-tools" title="Herramientas: Conexión con MCP y automatizaciones">
                  ${NanoIcon.get('tools', 14)} <span>Herramientas</span>
                </button>
              </div>

              <div class="composer-actions-right">
                <button type="button" class="btn-mic-dictate" id="composer-btn-mic" title="Dictado por voz">
                  ${NanoIcon.get('mic', 16)}
                </button>
                <button type="submit" id="chat-submit" class="btn-send-circle" title="Enviar prompt (Enter)">
                  ${NanoIcon.get('arrowUp', 16)}
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    `;

    this.messagesEl = this.container.querySelector('#chat-messages');
    this.input = this.container.querySelector('#chat-input');
    this.form = this.container.querySelector('#chat-form');
    this.submitBtn = this.container.querySelector('#chat-submit');
    this.fileInput = this.container.querySelector('#composer-file-input');
    this.attachmentsRow = this.container.querySelector('#composer-attachments-row');

    this.setupVoiceDictation();
    this.bindEvents();
    appState.subscribe((state) => this.render(state));
    this.render(appState.getState());
  }

  setupVoiceDictation() {
    const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (SpeechRec) {
      this.speechRecognition = new SpeechRec();
      this.speechRecognition.continuous = false;
      this.speechRecognition.lang = 'es-ES';
      this.speechRecognition.interimResults = false;

      this.speechRecognition.onresult = (e) => {
        const transcript = e.results[0][0].transcript;
        if (this.input) {
          this.input.value = (this.input.value ? this.input.value + ' ' : '') + transcript;
          this.input.dispatchEvent(new Event('input'));
          this.input.focus();
        }
      };

      this.speechRecognition.onend = () => {
        this.isRecordingVoice = false;
        const micBtn = document.getElementById('composer-btn-mic');
        micBtn?.classList.remove('recording');
        if (this.owlAvatar && this.owlAvatar.currentState === 'listening') {
          this.owlAvatar.setState('idle');
        }
      };

      this.speechRecognition.onerror = () => {
        this.isRecordingVoice = false;
        const micBtn = document.getElementById('composer-btn-mic');
        micBtn?.classList.remove('recording');
      };
    }
  }

  bindEvents() {
    // Envío del Formulario
    if (this.form) {
      this.form.addEventListener('submit', (e) => {
        e.preventDefault();
        const val = this.input.value.trim();
        if (val) {
          const filesToSend = [...this.attachedFiles];
          this.input.value = '';
          this.input.style.height = 'auto';
          this.submitBtn?.classList.remove('ready');
          this.attachedFiles = [];
          this.renderAttachmentChips();

          chatService.sendMessage(val, filesToSend, {
            web: this.webActive,
            deepThink: this.deepThinkActive,
            tools: this.toolsActive,
          });
        }
      });
    }

    // Tecla Enter y Auto-expansión
    if (this.input) {
      this.input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          this.form?.dispatchEvent(new Event('submit', { cancelable: true }));
        }
      });

      this.input.addEventListener('input', () => {
        this.input.style.height = 'auto';
        this.input.style.height = Math.min(this.input.scrollHeight, 180) + 'px';
        const hasContent = this.input.value.trim().length > 0;
        if (this.submitBtn) {
          this.submitBtn.classList.toggle('ready', hasContent);
        }
        if (this.owlAvatar && this.owlAvatar.currentState === 'idle') {
          this.owlAvatar.setState('listening');
        }
      });

      this.input.addEventListener('focus', () => {
        if (this.owlAvatar && this.owlAvatar.currentState === 'idle') {
          this.owlAvatar.setState('listening');
        }
      });

      this.input.addEventListener('blur', () => {
        if (this.owlAvatar && this.owlAvatar.currentState === 'listening' && !this.input.value.trim()) {
          this.owlAvatar.setState('idle');
        }
      });
    }

    // Botón Adjuntar Archivo
    const attachBtn = this.container.querySelector('#composer-btn-attach');
    if (attachBtn && this.fileInput) {
      attachBtn.addEventListener('click', () => {
        this.fileInput.click();
      });

      this.fileInput.addEventListener('change', async (e) => {
        const files = Array.from(e.target.files || []);
        for (const file of files) {
          const content = await file.text();
          this.attachedFiles.push({
            name: file.name,
            size: file.size,
            content,
          });
        }
        this.fileInput.value = '';
        this.renderAttachmentChips();
      });
    }

    // Botón Pensar (DeepThink)
    const deepThinkBtn = this.container.querySelector('#composer-btn-deepthink');
    if (deepThinkBtn) {
      deepThinkBtn.addEventListener('click', () => {
        this.deepThinkActive = !this.deepThinkActive;
        deepThinkBtn.classList.toggle('active', this.deepThinkActive);
        const topBtn = document.getElementById('btn-toggle-deepthink');
        topBtn?.classList.toggle('active', this.deepThinkActive);
      });
    }

    // Botón Web
    const webBtn = this.container.querySelector('#composer-btn-web');
    if (webBtn) {
      webBtn.addEventListener('click', () => {
        this.webActive = !this.webActive;
        webBtn.classList.toggle('active', this.webActive);
        webBtn.classList.toggle('web', this.webActive);
        const topBtn = document.getElementById('btn-toggle-web');
        topBtn?.classList.toggle('active', this.webActive);
        topBtn?.classList.toggle('web', this.webActive);
      });
    }

    // Botón Herramientas (Tools / MCP)
    const toolsBtn = this.container.querySelector('#composer-btn-tools');
    if (toolsBtn) {
      toolsBtn.addEventListener('click', () => {
        this.toolsActive = !this.toolsActive;
        toolsBtn.classList.toggle('active', this.toolsActive);
        toolsBtn.classList.toggle('tools', this.toolsActive);
      });
    }

    // Botón Micrófono
    const micBtn = this.container.querySelector('#composer-btn-mic');
    if (micBtn) {
      micBtn.addEventListener('click', () => {
        if (!this.speechRecognition) {
          alert('El reconocimiento de voz no está soportado en este navegador.');
          return;
        }

        if (this.isRecordingVoice) {
          this.speechRecognition.stop();
          this.isRecordingVoice = false;
          micBtn.classList.remove('recording');
        } else {
          try {
            this.speechRecognition.start();
            this.isRecordingVoice = true;
            micBtn.classList.add('recording');
            if (this.owlAvatar) this.owlAvatar.setState('listening');
          } catch (e) {
            console.warn('Error al iniciar dictado:', e);
          }
        }
      });
    }
  }

  renderAttachmentChips() {
    if (!this.attachmentsRow) return;

    if (this.attachedFiles.length === 0) {
      this.attachmentsRow.innerHTML = '';
      this.attachmentsRow.classList.remove('has-files');
      return;
    }

    this.attachmentsRow.classList.add('has-files');
    this.attachmentsRow.innerHTML = this.attachedFiles
      .map(
        (f, idx) => `
        <div class="attachment-chip">
          ${NanoIcon.get('files', 12)}
          <span class="attachment-chip-name" title="${f.name}">${f.name}</span>
          <button type="button" class="attachment-chip-remove" data-index="${idx}" title="Eliminar archivo">×</button>
        </div>
      `
      )
      .join('');

    this.attachmentsRow.querySelectorAll('.attachment-chip-remove').forEach((btn) => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.dataset.index, 10);
        this.attachedFiles.splice(idx, 1);
        this.renderAttachmentChips();
      });
    });
  }

  render(state) {
    if (!this.messagesEl) return;

    // Conectar la instancia del búho a chatService
    chatService.setOwlInstance(this.owlAvatar);

    if (!state.messages || state.messages.length === 0) {
      this.messagesEl.innerHTML = `
        <div class="chat-empty-state">
          <!-- Búho Nano con halo tenue -->
          <div id="nano-owl-mount" class="nano-owl-wrapper"></div>
          
          <h2 class="empty-title">¿Qué quieres construir hoy?</h2>
          <p class="empty-subtitle">Piensa, crea y ejecuta con Nano.</p>

          <div class="prompt-suggestions-grid">
            <button type="button" class="suggestion-card" data-prompt="Explica la arquitectura de NanoRuntime en Rust y cómo desacoplar backends de inferencia.">
              <div class="suggestion-card-left">
                <div class="suggestion-card-icon">
                  ${NanoIcon.get('code', 15)}
                </div>
                <div class="suggestion-card-content">
                  <span class="suggestion-card-title">Arquitectura NanoRuntime</span>
                  <span class="suggestion-card-desc">Desacoplamiento de backends de inferencia y memory fitting</span>
                </div>
              </div>
              <span class="suggestion-card-arrow">${NanoIcon.get('chevronRight', 14)}</span>
            </button>

            <button type="button" class="suggestion-card" data-prompt="¿Cómo implementar un mecanismo de model fitting dinámico y auto-eviction estilo Jan y LM Studio?">
              <div class="suggestion-card-left">
                <div class="suggestion-card-icon">
                  ${NanoIcon.get('layers', 15)}
                </div>
                <div class="suggestion-card-content">
                  <span class="suggestion-card-title">Model Fitting y TTL</span>
                  <span class="suggestion-card-desc">Políticas de ciclo de vida ECO, BALANCED y PINNED</span>
                </div>
              </div>
              <span class="suggestion-card-arrow">${NanoIcon.get('chevronRight', 14)}</span>
            </button>

            <button type="button" class="suggestion-card" data-prompt="Escribe un script en Rust para ejecutar diagnósticos de VRAM, KV Cache y offload de capas a la GPU.">
              <div class="suggestion-card-left">
                <div class="suggestion-card-icon">
                  ${NanoIcon.get('cpu', 15)}
                </div>
                <div class="suggestion-card-content">
                  <span class="suggestion-card-title">Diagnósticos de Hardware</span>
                  <span class="suggestion-card-desc">Monitoreo de KV Cache, VRAM y límites térmicos</span>
                </div>
              </div>
              <span class="suggestion-card-arrow">${NanoIcon.get('chevronRight', 14)}</span>
            </button>

            <button type="button" class="suggestion-card" data-prompt="Diseña un flujo de trabajo para un agente de automatización que procese pedidos y emita tracking.">
              <div class="suggestion-card-left">
                <div class="suggestion-card-icon">
                  ${NanoIcon.get('automation', 15)}
                </div>
                <div class="suggestion-card-content">
                  <span class="suggestion-card-title">Agente de Automatización</span>
                  <span class="suggestion-card-desc">Orquestación de tareas con herramientas y aprobación</span>
                </div>
              </div>
              <span class="suggestion-card-arrow">${NanoIcon.get('chevronRight', 14)}</span>
            </button>
          </div>
        </div>
      `;

      // Montar el Avatar del Búho Nano con su halo azul-violeta tenue
      const owlMount = this.messagesEl.querySelector('#nano-owl-mount');
      if (owlMount) {
        this.owlAvatar = new NanoOwlAvatar({
          size: 116,
          container: owlMount,
          withHalo: true,
          interactive: true,
        });
        chatService.setOwlInstance(this.owlAvatar);
      }

      // Bind clicks en sugerencias
      this.messagesEl.querySelectorAll('.suggestion-card').forEach((card) => {
        card.addEventListener('click', () => {
          const prompt = card.dataset.prompt;
          if (this.input && prompt) {
            this.input.value = prompt;
            this.input.style.height = 'auto';
            this.input.style.height = Math.min(this.input.scrollHeight, 180) + 'px';
            this.input.focus();
            if (this.owlAvatar) this.owlAvatar.setState('listening');
          }
        });
      });

      return;
    }

    // Renderizar lista de mensajes
    this.messagesEl.innerHTML = state.messages.map((m) => this.renderMessage(m)).join('');
    this.messagesEl.scrollTop = this.messagesEl.scrollHeight;

    // Toggle de acordeón DeepThink
    this.messagesEl.querySelectorAll('.thinking-header').forEach((header) => {
      header.addEventListener('click', () => {
        const box = header.closest('.deepseek-thinking-box');
        box?.classList.toggle('collapsed');
      });
    });

    // Botones de copia de respuestas
    this.messagesEl.querySelectorAll('.btn-copy-msg').forEach((btn) => {
      btn.addEventListener('click', () => {
        const text = btn.dataset.text;
        if (text) {
          navigator.clipboard.writeText(text);
          btn.innerHTML = `${NanoIcon.get('check', 13)} Copiado`;
          setTimeout(() => {
            btn.innerHTML = `${NanoIcon.get('copy', 13)}`;
          }, 2000);
        }
      });
    });

    if (this.input) {
      this.input.disabled = state.isGenerating;
      if (!state.isGenerating) this.input.focus();
    }
  }

  renderMessage(msg) {
    const isUser = msg.role === 'user';
    const isThinking = msg.text === 'Pensando...';

    if (isUser) {
      return `
        <div class="chat-msg-row user">
          <div class="msg-body">
            <div class="msg-bubble">${this.escapeHtml(msg.text)}</div>
          </div>
        </div>
      `;
    }

    // Asistente: Procesar bloque <think>
    let thinkingHtml = '';
    let mainText = msg.text;

    if (isThinking) {
      thinkingHtml = `
        <div class="deepseek-thinking-box">
          <div class="thinking-header">
            <div class="thinking-header-left">
              ${NanoIcon.get('brain', 14)}
              <span>Pensando con DeepThink...</span>
            </div>
            <span class="thinking-chevron">${NanoIcon.get('chevronDown', 13)}</span>
          </div>
          <div class="thinking-content">Analizando el contexto, procesando tokens y formulando la respuesta óptima...</div>
        </div>
      `;
      mainText = '';
    } else if (msg.text.includes('<think>') && msg.text.includes('</think>')) {
      const parts = msg.text.split('</think>');
      const thinkPart = parts[0].replace('<think>', '').trim();
      mainText = parts[1].trim();

      thinkingHtml = `
        <div class="deepseek-thinking-box">
          <div class="thinking-header">
            <div class="thinking-header-left">
              ${NanoIcon.get('brain', 14)}
              <span>Proceso de Razonamiento DeepThink</span>
            </div>
            <span class="thinking-chevron">${NanoIcon.get('chevronDown', 13)}</span>
          </div>
          <div class="thinking-content">${this.escapeHtml(thinkPart)}</div>
        </div>
      `;
    } else if (msg.text.includes('<think>') && !msg.text.includes('</think>')) {
      // Bloque <think> en streaming en vivo
      const thinkPart = msg.text.replace('<think>', '').trim();
      thinkingHtml = `
        <div class="deepseek-thinking-box">
          <div class="thinking-header">
            <div class="thinking-header-left">
              ${NanoIcon.get('brain', 14)}
              <span>Razonando en vivo (DeepThink)...</span>
            </div>
            <span class="thinking-chevron">${NanoIcon.get('chevronDown', 13)}</span>
          </div>
          <div class="thinking-content">${this.escapeHtml(thinkPart)} <span class="streaming-cursor">▊</span></div>
        </div>
      `;
      mainText = '';
    }

    // Telemetría de inferencia
    let metaHtml = '';
    if (msg.meta && !msg.meta.error) {
      metaHtml = `
        <div class="msg-telemetry-bar">
          <span>⚡ ${msg.meta.tok_s || '22.4'} tok/s</span>
          <span>⏱ ${msg.meta.time || '1.8s'}</span>
          <span>📦 ${msg.meta.model || 'DeepSeek-R1'}</span>
          <span>🔒 100% Local</span>
        </div>
      `;
    } else if (msg.meta && msg.meta.error) {
      metaHtml = `
        <div class="msg-telemetry-bar" style="color: var(--accent-error);">
          <span>⚠️ Error en inferencia local</span>
        </div>
      `;
    }

    const formattedContent = this.formatMarkdown(mainText);

    return `
      <div class="chat-msg-row assistant">
        <div class="msg-avatar assistant" title="Nano AI Sovereign Assistant">
          <img src="assets/nano_owl.png" alt="Nano Owl" />
        </div>
        <div class="msg-body">
          ${thinkingHtml}
          ${formattedContent ? `<div class="msg-bubble">${formattedContent}${msg.meta?.isStreaming ? ' <span class="streaming-cursor">▊</span>' : ''}</div>` : ''}
          ${metaHtml}
          <div class="msg-actions-row">
            <button type="button" class="btn-msg-action btn-copy-msg" data-text="${this.escapeHtml(mainText)}" title="Copiar respuesta">
              ${NanoIcon.get('copy', 13)}
            </button>
          </div>
        </div>
      </div>
    `;
  }

  formatMarkdown(text) {
    if (!text) return '';
    let html = this.escapeHtml(text);

    // Code blocks ```code```
    html = html.replace(/```([a-zA-Z0-9_-]*)\n([\s\S]*?)```/g, (match, lang, code) => {
      return `<pre class="code-block"><code>${code.trim()}</code></pre>`;
    });

    // Inline code `code`
    html = html.replace(/`([^`]+)`/g, '<code style="background: var(--bg-hover); padding: 2px 5px; border-radius: 4px; font-family: var(--font-mono); font-size: 0.9em;">$1</code>');

    // Bold **text**
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');

    // List bullets * item
    html = html.replace(/^\* (.*$)/gim, '• $1');

    return html;
  }

  escapeHtml(str) {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

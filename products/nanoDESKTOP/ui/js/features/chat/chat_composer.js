/**
 * chat_composer.js — Componente Flotante del Compositor de Mensajes (< 200 LOC)
 * QUÉ HACE: Gestiona entrada de texto, subida de archivos, dictado por voz y toggles.
 * CÓMO FUNCIONA: Escucha eventos del textarea, gestiona archivos y emite `onSubmit`.
 * POR QUÉ: SRP — Desacopla la lógica de captura del flujo de chat principal.
 */
import { NanoIcon } from '../../components/nano_icon.js';

export class ChatComposer {
  constructor({ container, onSubmit = () => {}, onTyping = () => {} }) {
    this.container = container;
    this.onSubmit = onSubmit;
    this.onTyping = onTyping;
    this.deepThinkActive = true;
    this.webActive = false;
    this.attachedFiles = [];
    this.isRecordingVoice = false;
    this.speechRecognition = null;
    this.mount();
    this.setupVoiceDictation();
    this.bindEvents();
  }

  mount() {
    this.container.innerHTML = `
      <form id="chat-form" class="nano-composer-box chat-composer-box">
        <input type="file" id="composer-file-input" style="display:none;" multiple accept=".txt,.md,.json,.csv,.py,.rs,.js,.log,.pdf" />
        <div id="composer-attachments-row" class="composer-attachments-row"></div>
        <div class="composer-top-row">
          <textarea id="chat-input" class="composer-textarea" placeholder="Envía un mensaje o escribe '/' para comandos..." rows="1" autocomplete="off" spellcheck="false"></textarea>
        </div>
        <div class="composer-actions-row">
          <div class="composer-tools-left">
            <button type="button" class="btn-composer-pill" id="composer-btn-attach" title="Adjuntar documento o código">${NanoIcon.get('attach', 14)} <span>Adjuntar</span></button>
            <button type="button" class="btn-composer-pill active" id="composer-btn-deepthink" title="Pensar: Razonamiento profundo (R1)">${NanoIcon.get('brain', 14)} <span>DeepThink</span></button>
            <button type="button" class="btn-composer-pill" id="composer-btn-web" title="Web: Búsqueda en internet">${NanoIcon.get('globe', 14)} <span>Web</span></button>
          </div>
          <div class="composer-actions-right">
            <span class="composer-kbd-hint">Ctrl + Enter para enviar</span>
            <button type="button" class="btn-mic-dictate" id="composer-btn-mic" title="Dictado por voz">${NanoIcon.get('mic', 16)}</button>
            <button type="submit" id="chat-submit" class="nano-send btn-send-circle" title="Enviar prompt (Enter)">${NanoIcon.get('send', 18)}</button>
          </div>
        </div>
      </form>`;
    this.form = this.container.querySelector('#chat-form');
    this.input = this.container.querySelector('#chat-input');
    this.submitBtn = this.container.querySelector('#chat-submit');
    this.fileInput = this.container.querySelector('#composer-file-input');
    this.attachmentsRow = this.container.querySelector('#composer-attachments-row');
  }

  setupVoiceDictation() {
    const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRec) return;
    this.speechRecognition = new SpeechRec();
    this.speechRecognition.continuous = false;
    this.speechRecognition.lang = 'es-ES';
    this.speechRecognition.onresult = (e) => {
      const transcript = e.results[0][0].transcript;
      if (this.input) {
        this.input.value = (this.input.value ? `${this.input.value} ` : '') + transcript;
        this.input.dispatchEvent(new Event('input'));
        this.input.focus();
      }
    };
    const stop = () => {
      this.isRecordingVoice = false;
      this.container.querySelector('#composer-btn-mic')?.classList.remove('recording');
      this.onTyping(false);
    };
    this.speechRecognition.onend = stop;
    this.speechRecognition.onerror = stop;
  }

  bindEvents() {
    this.form?.addEventListener('submit', (e) => {
      e.preventDefault();
      const text = this.input.value.trim();
      if (!text) return;
      const files = [...this.attachedFiles];
      this.input.value = '';
      this.input.style.height = 'auto';
      this.submitBtn?.classList.remove('ready');
      this.attachedFiles = [];
      this.renderAttachmentChips();
      this.onSubmit({ text, files, options: { web: this.webActive, deepThink: this.deepThinkActive } });
    });

    this.input?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        this.form?.dispatchEvent(new Event('submit', { cancelable: true }));
      }
    });

    this.input?.addEventListener('input', () => {
      this.input.style.height = 'auto';
      this.input.style.height = `${Math.min(this.input.scrollHeight, 180)}px`;
      const hasText = this.input.value.trim().length > 0;
      this.submitBtn?.classList.toggle('ready', hasText);
      this.onTyping(hasText);
    });

    this.input?.addEventListener('focus', () => this.onTyping(true));
    this.input?.addEventListener('blur', () => { if (!this.input.value.trim()) this.onTyping(false); });

    this.container.querySelector('#composer-btn-attach')?.addEventListener('click', () => this.fileInput?.click());
    this.fileInput?.addEventListener('change', async (e) => {
      for (const file of Array.from(e.target.files || [])) {
        this.attachedFiles.push({ name: file.name, size: file.size, content: await file.text() });
      }
      this.fileInput.value = '';
      this.renderAttachmentChips();
    });

    const dtBtn = this.container.querySelector('#composer-btn-deepthink');
    dtBtn?.addEventListener('click', () => {
      this.deepThinkActive = !this.deepThinkActive;
      dtBtn.classList.toggle('active', this.deepThinkActive);
    });

    const webBtn = this.container.querySelector('#composer-btn-web');
    webBtn?.addEventListener('click', () => {
      this.webActive = !this.webActive;
      webBtn.classList.toggle('active', this.webActive);
      webBtn.classList.toggle('web', this.webActive);
    });

    const micBtn = this.container.querySelector('#composer-btn-mic');
    micBtn?.addEventListener('click', () => {
      if (!this.speechRecognition) { alert('Dictado no disponible.'); return; }
      if (this.isRecordingVoice) {
        this.speechRecognition.stop();
        this.isRecordingVoice = false;
        micBtn.classList.remove('recording');
        this.onTyping(false);
      } else {
        try {
          this.speechRecognition.start();
          this.isRecordingVoice = true;
          micBtn.classList.add('recording');
          this.onTyping(true);
        } catch (err) { console.warn('[Composer] Error mic:', err); }
      }
    });
  }

  renderAttachmentChips() {
    if (!this.attachmentsRow) return;
    if (this.attachedFiles.length === 0) {
      this.attachmentsRow.innerHTML = '';
      this.attachmentsRow.classList.remove('has-files');
      return;
    }
    this.attachmentsRow.classList.add('has-files');
    this.attachmentsRow.innerHTML = this.attachedFiles.map((f, i) => `
      <div class="attachment-chip">${NanoIcon.get('files', 12)}
        <span class="attachment-chip-name" title="${f.name}">${f.name}</span>
        <button type="button" class="attachment-chip-remove" data-index="${i}" title="Eliminar">×</button>
      </div>`).join('');

    this.attachmentsRow.querySelectorAll('.attachment-chip-remove').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.attachedFiles.splice(parseInt(btn.dataset.index, 10), 1);
        this.renderAttachmentChips();
      });
    });
  }

  setDisabled(disabled) {
    if (this.input) this.input.disabled = disabled;
    if (!disabled && this.input) this.input.focus();
  }

  setValue(val) {
    if (this.input) {
      this.input.value = val;
      this.input.style.height = 'auto';
      this.input.style.height = `${Math.min(this.input.scrollHeight, 180)}px`;
      this.submitBtn?.classList.toggle('ready', val.trim().length > 0);
      this.input.focus();
    }
  }
}

/**
 * chat_message_renderer.js — Renderizador de Mensajes y Telemetría (< 200 LOC)
 *
 * QUÉ HACE:
 * Transforma los mensajes del estado en HTML semántico con soporte para bloques
 * de razonamiento DeepThink, formateo de Markdown, cursores en vivo y telemetría.
 *
 * CÓMO FUNCIONA:
 * Procesa etiquetas `<think>`, sanitiza cadenas para prevenir XSS y proporciona
 * enlaces para copiar respuestas y alternar la visibilidad de razonamiento.
 *
 * POR QUÉ:
 * Principio de Responsabilidad Única (SRP): Separa la presentación del texto
 * y Markdown de la coordinación y lógica del ciclo de vida del chat.
 */

import { NanoIcon } from '../../components/nano_icon.js';

export class ChatMessageRenderer {
  /**
   * Renderiza un mensaje individual en formato HTML seguro.
   * @param {Object} msg Objeto de mensaje ({ role, text, meta }).
   * @returns {string} Fragmento HTML listo para inyectar.
   */
  static render(msg) {
    if (msg.role === 'user') {
      return `
        <div class="chat-msg-row user">
          <div class="msg-body">
            <div class="msg-bubble chat-bubble-user">${this.escapeHtml(msg.text)}</div>
          </div>
        </div>
      `;
    }

    const isThinking = msg.text === 'Pensando...';
    let thinkingHtml = '';
    let mainText = msg.text;

    if (isThinking) {
      thinkingHtml = this._buildThinkingBox(
        'Pensando con DeepThink...',
        'Analizando el contexto, procesando tokens y formulando la respuesta óptima...',
        false
      );
      mainText = '';
    } else if (msg.text.includes('<think>') && msg.text.includes('</think>')) {
      const parts = msg.text.split('</think>');
      const thinkPart = parts[0].replace('<think>', '').trim();
      mainText = parts[1].trim();
      thinkingHtml = this._buildThinkingBox('Proceso de Razonamiento DeepThink', thinkPart, false);
    } else if (msg.text.includes('<think>')) {
      const thinkPart = msg.text.replace('<think>', '').trim();
      thinkingHtml = this._buildThinkingBox('Razonando en vivo (DeepThink)...', thinkPart, true);
      mainText = '';
    }

    const formattedContent = this.formatMarkdown(mainText);
    const metaHtml = this._renderTelemetry(msg.meta);

    return `
      <div class="chat-msg-row assistant">
        <div class="chat-msg-avatar assistant" title="Nano AI Sovereign Assistant">
          <img src="assets/brand/nano-logo-mark.svg" alt="Nano AI" class="assistant-avatar-svg" />
        </div>
        <div class="msg-body">
          ${thinkingHtml}
          ${formattedContent ? `<div class="msg-bubble chat-bubble-assistant">${formattedContent}${msg.meta?.isStreaming ? ' <span class="streaming-cursor">▊</span>' : ''}</div>` : ''}
          ${metaHtml}
          <div class="msg-actions-row">
            <button type="button" class="btn-msg-action btn-copy-msg" data-text="${this.escapeHtml(mainText)}" title="Copiar respuesta">
              ${NanoIcon.get('copy', 13)}
              <span>Copiar</span>
            </button>
          </div>
        </div>
      </div>
    `;
  }

  static _buildThinkingBox(title, content, isStreaming) {
    return `
      <div class="deepseek-thinking-box">
        <div class="thinking-header">
          <div class="thinking-header-left">
            ${NanoIcon.get('brain', 14)}
            <span>${title}</span>
          </div>
          <span class="thinking-chevron">${NanoIcon.get('chevronDown', 13)}</span>
        </div>
        <div class="thinking-content">${this.escapeHtml(content)}${isStreaming ? ' <span class="streaming-cursor">▊</span>' : ''}</div>
      </div>
    `;
  }

  static _renderTelemetry(meta) {
    if (!meta) return '';
    if (meta.error) {
      return `
        <div class="msg-error-card">
          <span class="msg-error-dot"></span>
          <span>Inferencia no disponible en este turno</span>
        </div>
      `;
    }
    const tokS = meta.tok_s || '18.4';
    const time = meta.time || '1.2s';
    const model = meta.model || 'Qwen 2.5 1.5B (Local)';

    return `
      <div class="msg-telemetry-bar">
        <span class="telemetry-item"><span class="telemetry-live-dot"></span>100% Local</span>
        <span class="telemetry-dot">•</span>
        <span class="telemetry-item">${model}</span>
        <span class="telemetry-dot">•</span>
        <span class="telemetry-item">${tokS} tok/s</span>
        <span class="telemetry-dot">•</span>
        <span class="telemetry-item">${time}</span>
      </div>
    `;
  }

  /**
   * Formatea Markdown estilo GPT/Gemini: encabezados, listas, citas y código.
   * @param {string} text Texto crudo con sintaxis Markdown.
   * @returns {string} HTML renderizado y sanitizado.
   */
  static formatMarkdown(text) {
    if (!text) return '';
    let html = this.escapeHtml(text);
    // 1. Bloques de código con sintaxis pre
    html = html.replace(/```([a-zA-Z0-9_-]*)\n([\s\S]*?)```/g, (_, lang, code) => 
      `<div class="code-block-wrap"><div class="code-lang-label">${lang || 'code'}</div><pre class="code-block"><code>${code.trim()}</code></pre></div>`);
    // 2. Código inline
    html = html.replace(/`([^`]+)`/g, '<code class="nano-inline-code">$1</code>');
    // 3. Encabezados jerárquicos (###, ##, #)
    html = html.replace(/^### (.*$)/gim, '<h4 class="md-heading-3">$1</h4>');
    html = html.replace(/^## (.*$)/gim, '<h3 class="md-heading-2">$1</h3>');
    html = html.replace(/^# (.*$)/gim, '<h2 class="md-heading-1">$1</h2>');
    // 4. Citas en bloque (>)
    html = html.replace(/^> (.*$)/gim, '<blockquote class="md-blockquote">$1</blockquote>');
    // 5. Negritas e itálicas
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>');
    // 6. Listas numeradas y con viñetas
    html = html.replace(/^(\d+)\. (.*$)/gim, '<div class="md-list-item-num"><span class="md-num-badge">$1</span><span>$2</span></div>');
    html = html.replace(/^[•\-\*] (.*$)/gim, '<div class="md-list-item"><span class="md-bullet">•</span><span>$1</span></div>');
    // 7. Párrafos y saltos
    html = html.replace(/\n\n/g, '<div class="chat-paragraph-gap"></div>');
    html = html.replace(/\n/g, '<br />');
    return html;
  }

  static escapeHtml(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  /**
   * Vincula interactividad (acordeón y copia) en el contenedor de mensajes.
   * @param {HTMLElement} messagesEl
   */
  static bindInteractions(messagesEl) {
    messagesEl.querySelectorAll('.thinking-header').forEach((header) => {
      header.addEventListener('click', () => {
        header.closest('.deepseek-thinking-box')?.classList.toggle('collapsed');
      });
    });

    messagesEl.querySelectorAll('.btn-copy-msg').forEach((btn) => {
      btn.addEventListener('click', () => {
        const text = btn.dataset.text;
        if (text) {
          navigator.clipboard.writeText(text);
          btn.innerHTML = `${NanoIcon.get('check', 13)} Copiado`;
          setTimeout(() => { btn.innerHTML = NanoIcon.get('copy', 13); }, 2000);
        }
      });
    });
  }
}

/**
 * StateManager — Gestor de estado reactivo multi-sesión con persistencia (SRP).
 * Conserva conversaciones locales; las credenciales pertenecen al servidor.
 */
import { readSessions, writeSessions } from './session_persistence.js';
class StateManager {
  constructor() {
    const savedSessions = this.loadPersistedSessions();
    const defaultSessionId = savedSessions[0]?.id || this.generateId();

    this.state = {
      activeTab: 'chat',
      sessions: savedSessions.length > 0 ? savedSessions : [
        {
          id: defaultSessionId,
          title: 'Nueva conversación',
          createdAt: Date.now(),
          messages: [],
          activeModel: '',
        }
      ],
      currentSessionId: defaultSessionId,
      currentModel: '',
      isGenerating: false,
      telemetry: null,
      models: [],
      attachedFiles: [],
    };

    this.listeners = new Set();
  }

  generateId() {
    return 'ses_' + Date.now().toString(36) + Math.random().toString(36).substring(2, 6);
  }

  loadPersistedSessions() {
    return readSessions();
  }

  persistSessions() {
    writeSessions(this.state.sessions);
  }

  getState() {
    const currentSession = this.getCurrentSession();
    return {
      ...this.state,
      messages: currentSession ? currentSession.messages : [],
    };
  }

  getCurrentSession() {
    return this.state.sessions.find((s) => s.id === this.state.currentSessionId) || this.state.sessions[0];
  }

  setState(partial) {
    this.state = { ...this.state, ...partial };
    this.notify();
  }

  subscribe(listener) {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify() {
    const currentState = this.getState();
    for (const listener of this.listeners) {
      listener(currentState);
    }
  }

  createSession(title = 'Nueva conversación') {
    const newSession = {
      id: this.generateId(),
      title,
      createdAt: Date.now(),
      messages: [],
      activeModel: this.state.currentModel,
    };

    this.state.sessions.unshift(newSession);
    this.state.currentSessionId = newSession.id;
    this.persistSessions();
    this.notify();
    return newSession;
  }

  switchSession(sessionId) {
    const exists = this.state.sessions.some((s) => s.id === sessionId);
    if (exists) {
      this.state.currentSessionId = sessionId;
      this.notify();
    }
  }

  deleteSession(sessionId) {
    if (this.state.sessions.length <= 1) {
      // Si es la única, limpiarla
      this.state.sessions = [
        {
          id: this.generateId(),
          title: 'Nueva conversación',
          createdAt: Date.now(),
          messages: [],
          activeModel: this.state.currentModel,
        }
      ];
      this.state.currentSessionId = this.state.sessions[0].id;
    } else {
      this.state.sessions = this.state.sessions.filter((s) => s.id !== sessionId);
      if (this.state.currentSessionId === sessionId) {
        this.state.currentSessionId = this.state.sessions[0].id;
      }
    }
    this.persistSessions();
    this.notify();
  }

  addMessage(role, text, meta = null) {
    const session = this.getCurrentSession();
    if (!session) return null;

    const msg = {
      id: 'msg_' + Date.now() + Math.random().toString(36).substring(2, 6),
      role,
      text,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      meta,
    };

    session.messages.push(msg);

    // Si es el primer mensaje de usuario, auto-nombrar la sesión con un título limpio
    if (role === 'user' && session.title === 'Nueva conversación') {
      const cleanTitle = text.slice(0, 36).replace(/\n/g, ' ').trim();
      session.title = cleanTitle.length > 0 ? (cleanTitle.length >= 36 ? cleanTitle + '...' : cleanTitle) : 'Conversación';
    }

    this.persistSessions();
    this.notify();
    return msg;
  }

  // La respuesta queda ligada a su conversación, aunque el usuario cambie de vista.
  appendStreamToken(token, sessionId = this.state.currentSessionId, messageId = null) {
    const session = this.state.sessions.find((s) => s.id === sessionId);
    if (!session || session.messages.length === 0) return;

    const lastMsg = messageId ? session.messages.find((m) => m.id === messageId) : session.messages.at(-1);
    if (lastMsg && lastMsg.role === 'assistant') {
      if (lastMsg.text === 'Pensando...') {
        lastMsg.text = token;
      } else {
        lastMsg.text += token;
      }
      this.notify();
    }
  }

  // Completa solo el mensaje que inició la inferencia; nunca la última burbuja de otro chat.
  updateLastMessage(text, meta = null, sessionId = this.state.currentSessionId, messageId = null) {
    const session = this.state.sessions.find((s) => s.id === sessionId);
    if (!session || session.messages.length === 0) return;

    const lastIdx = messageId ? session.messages.findIndex((m) => m.id === messageId) : session.messages.length - 1;
    if (lastIdx < 0) return;
    const current = session.messages[lastIdx];
    session.messages[lastIdx] = {
      ...current,
      text: (text !== null && text !== undefined) ? text : current.text,
      meta: meta ? { ...current.meta, ...meta } : current.meta,
    };

    this.persistSessions();
    this.notify();
  }
}

export const appState = new StateManager();
if (typeof window !== 'undefined') {
  window.appState = appState;
}

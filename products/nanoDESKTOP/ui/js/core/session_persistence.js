/** Conserva conversaciones existentes; almacenamiento del navegador no equivale a cifrado. */
const KEY = 'nano_desktop_sessions_v2';
let writesBlocked = false;

/** Lee sesiones sin crear muestras ni sobrescribir una colección ilegible. */
export function readSessions() {
  try {
    if (typeof window === 'undefined' || !window.localStorage) return [];
    const raw = localStorage.getItem(KEY);
    if (!raw) return [];
    const sessions = JSON.parse(raw);
    if (!Array.isArray(sessions) || sessions.some((s) => !s?.id || !Array.isArray(s.messages))) {
      throw new Error('El historial guardado tiene un formato inválido.');
    }
    return sessions;
  } catch (error) {
    // Preserva el dato original para recuperación manual, aunque la lectura haya fallado.
    writesBlocked = true;
    console.warn('[Sessions] Historial no disponible:', error.message);
    return [];
  }
}

/** Solo guarda conversaciones de Nano; no almacena tokens de proveedores o Meta. */
export function writeSessions(sessions) {
  if (writesBlocked) return;
  try {
    if (typeof window !== 'undefined' && window.localStorage) {
      localStorage.setItem(KEY, JSON.stringify(sessions));
    }
  } catch (error) { console.warn('[Sessions] No se pudo guardar:', error.message); }
}

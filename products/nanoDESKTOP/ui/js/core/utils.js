/**
 * utils.js — Utilidades Compartidas del Runtime Nano Desktop
 *
 * QUÉ HACE: Provee funciones puras reutilizables entre módulos.
 * CÓMO FUNCIONA: Funciones sin estado ni efectos secundarios (pure functions).
 * POR QUÉ: Elimina el patrón duplicado de escapeHtml en automation_view.js y
 *          app.js (violación DRY/SOLID — principio de Responsabilidad Única).
 */

/**
 * Escapa caracteres HTML peligrosos para prevenir XSS en innerHTML.
 * @param {string} str — Texto a sanitizar
 * @returns {string} — HTML seguro
 */
export function escapeHtml(str) {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * Formatea una marca temporal Unix (ms) como texto relativo legible.
 * Usado por agent_service para "lastRun" y entradas de log.
 * @param {number} ts — Timestamp en milisegundos
 * @returns {string} — Ej: "Hace 2m", "Hace 1h"
 */
export function formatRelativeTime(ts) {
  if (!ts) return 'Nunca';
  const diff = Math.floor((Date.now() - ts) / 1000); // segundos
  if (diff < 60) return 'Justo ahora';
  if (diff < 3600) return `Hace ${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `Hace ${Math.floor(diff / 3600)}h`;
  return `Hace ${Math.floor(diff / 86400)}d`;
}

/**
 * theme.js — Manejo del tema Claro/Oscuro de FeatherCore
 */
export function setNanoTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  document.documentElement.dataset.theme = theme;
  localStorage.setItem('nano_theme', theme);
}

export function toggleNanoTheme() {
  const current = document.documentElement.getAttribute('data-theme') || document.documentElement.dataset.theme || 'light';
  setNanoTheme(current === 'dark' ? 'light' : 'dark');
}

export function restoreNanoTheme() {
  setNanoTheme(localStorage.getItem('nano_theme') || 'light');
}

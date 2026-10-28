/** Only preferences consumed by the product are persisted. No credentials here. */
export function readPreferences() {
  try {
    const data = JSON.parse(localStorage.getItem('nano_desktop_preferences_v1') || '{}');
    return { maxTokens: [512, 1024, 2048, 4096].includes(data.maxTokens) ? data.maxTokens : 512 };
  } catch { return { maxTokens: 512 }; }
}

export function savePreferences(value) {
  if (![512, 1024, 2048, 4096].includes(value.maxTokens)) throw new Error('Límite de tokens inválido');
  localStorage.setItem('nano_desktop_preferences_v1', JSON.stringify(value));
}

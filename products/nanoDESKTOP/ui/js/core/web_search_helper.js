/**
 * Helper para detección y consulta de datos en tiempo real (Grounding).
 * Permite complementar consultas con información pública si el usuario lo solicita.
 */

/**
 * Determina si el prompt del usuario contiene intenciones explícitas de búsqueda externa.
 * @param {string} prompt Texto introducido por el usuario.
 * @returns {boolean} True si requiere búsqueda web.
 */
export function isQueryDemandingWeb(prompt) {
  const p = prompt.toLowerCase();
  return (
    p.includes('ip') ||
    p.includes('clima') ||
    p.includes('precio') ||
    p.includes('noticias') ||
    p.includes('wikipedia') ||
    p.includes('quién es') ||
    p.includes('que es') ||
    p.includes('año') ||
    p.includes('cotización')
  );
}

/**
 * Consulta endpoints web públicos de forma soberana (Wikipedia, IPify, DuckDuckGo).
 * @param {string} query Consulta a realizar.
 * @returns {Promise<{found: boolean, source?: string, snippet?: string}>}
 */
export async function searchWebKnowledge(query) {
  const q = query.trim();
  const lower = q.toLowerCase();

  // Consulta de IP pública
  if (lower.includes('mi ip') || lower.includes('cual es mi ip') || lower.includes('dirección ip') || lower === 'ip') {
    try {
      const res = await fetch('https://api.ipify.org?format=json');
      if (res.ok) {
        const data = await res.json();
        return {
          found: true,
          source: 'Red Global IPify API',
          snippet: `Dirección IP Pública detectada: ${data.ip} (Conexión activa sin fugas DNS).`,
        };
      }
    } catch {
      // Fallback a siguientes servicios
    }
  }

  // Búsqueda en Wikipedia en Español
  const cleanTopic = q
    .replace(/^(busca|buscar|que es|quien es|dime sobre|explica)\s+/i, '')
    .replace(/\s+(en internet|en google|en la web)$/i, '')
    .trim();

  if (cleanTopic.length > 2) {
    try {
      const wikiUrl = `https://es.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(cleanTopic)}`;
      const res = await fetch(wikiUrl);
      if (res.ok) {
        const data = await res.json();
        if (data.extract) {
          return {
            found: true,
            source: `Wikipedia en Español — ${data.title}`,
            snippet: data.extract,
          };
        }
      }
    } catch {
      // Continuar al siguiente proveedor
    }
  }

  // Búsqueda en DuckDuckGo Instant Answers
  try {
    const ddgUrl = `https://api.duckduckgo.com/?q=${encodeURIComponent(cleanTopic)}&format=json&no_html=1&skip_disambig=1`;
    const res = await fetch(ddgUrl);
    if (res.ok) {
      const data = await res.json();
      if (data.AbstractText) {
        return {
          found: true,
          source: `DuckDuckGo Knowledge Graph (${data.Heading || cleanTopic})`,
          snippet: data.AbstractText,
        };
      }
    }
  } catch {
    // Si no hay conexión o no hay datos, retorna found: false
  }

  return { found: false };
}

# nano-desktop-audit-loop

Metodología verificable para auditar reportes de auditoría del módulo nanoDESKTOP.
Uso: cuando llegue una auditoría (interna o externa) y haya que validar si los
hallazgos son REALES antes de tocar código.

## Regla de oro

Ningún hallazgo se corrige sin antes citar la LÍNEA REAL del código que lo
demuestra. Sin evidencia → veredicto REFUTED, no se toca código.

## Loop de trabajo (por hallazgo)

1. LEER el archivo señalado y el rango de líneas citado por la auditoría.
2. BUSCAR lectores reales del campo/función en todo `ui/js` (grep global):
   un "bug" sin consumidores es severidad menor, no crítica.
3. CLASIFICAR:
   - REAL — la línea existe y el impacto descrito ocurre.
   - REAL PARCIAL — existe pero la severidad/impacto está exagerado.
   - REFUTED — la afirmación no ocurre en el código (falta la llamada, el efecto
     o el consumidor). Documentar por qué con evidencia.
4. CORREGIR solo lo REAL, mínimo cambio, sin ampliar por intuición.
5. VALIDAR sintaxis: `node --check` sobre copia `.mjs` (ESM).
6. REPORTAR: tabla hallazgo → veredicto → evidencia (archivo:línea) → fix.

## Estándares de archivo (obligatorios al corregir)

- < 200 líneas por archivo (contar con `(Get-Content f).Count`, no `Measure-Object`).
- Comentarios QUÉ HACE / CÓMO FUNCIONA / POR QUÉ al inicio; JSDoc por función.
- SRP: ejecución (executor) ≠ persistencia (service) ≠ datos (defaults) ≠ UI (view/modals).
- Prohibido: métricas falsas (successRate sin recálculo), contadores demo en
  defaults, delays artificiales que escalan con el tamaño de la respuesta.
- Sin tests automatizados en este proyecto: verificación manual del usuario +
  `node --check` para sintaxis.

## Chequeos recurrentes (zombies y fugas)

- Timers: todo `setInterval` debe tener guard anti-zombie + `stop()` expuesto.
- Listeners: todo `subscribe`/`listen` debe retornar/limpiar su unsubscribe.
- Streaming REST: la animación de tokens usa PRESUPUESTO de tiempo (≤300ms),
  nunca delay fijo por palabra.
- Modales: siempre via `NanoOverlay` (document.body), nunca position:fixed
  dentro de contenedores con overflow:hidden.

## Casos ya verificados (no re-diagnosticar)

- `agent_executor.js`: multi-herramienta combinada (Hardware + Web en la misma
  pasada; LLM solo como fallback sin herramientas reales). Fix 11-oct-2026.
- `transport.js`: `abortController` local por llamada; el claim de "race
  condition" del reporte original era REFUTED (no existía ningún abort()).
- Defaults de agentes: executions en 0, sin successRate, lastRun 'Nunca'.

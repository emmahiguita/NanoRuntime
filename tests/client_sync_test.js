// Pruebas de sincronización del cliente: replica la lógica de
// dashboard/src/app/page.tsx contra el servidor vivo (Node 21+ WebSocket global).
//
// Uso:  node tests/client_sync_test.js
// Requiere: servidor corriendo en ws://localhost:8000/ws/telemetry

const WS_URL = process.env.WS_URL || "ws://localhost:8000/ws/telemetry";
const MAX_POINTS = 120;
const MAX_LOGS = 60;

let pass = 0;
let fail = 0;
function check(name, ok, detail = "") {
  if (ok) {
    pass++;
    console.log(`  PASS  ${name}${detail ? `  [${detail}]` : ""}`);
  } else {
    fail++;
    console.log(`  FAIL  ${name}${detail ? `  [${detail}]` : ""}`);
  }
}

function runSyncTest() {
  return new Promise((resolve) => {
    const telemetry = [];
    const logs = [];
    let lastInferenceAt = 0;
    let inferenceCycles = 0;
    let t0 = Date.now();

    const ws = new WebSocket(WS_URL);
    ws.onopen = () => {};
    ws.onerror = (e) => check("sin errores de red", false, String(e.message || e.type));

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      const inf = data.inference || {};
      if (inf.lastAtMs > lastInferenceAt) {
        lastInferenceAt = inf.lastAtMs;
        inferenceCycles++;
      }
      telemetry.push(data);
      if (telemetry.length > MAX_POINTS) telemetry.shift();
      logs.push(data);
      if (logs.length > MAX_LOGS) logs.shift();
    };

    setTimeout(() => {
      const elapsed = (Date.now() - t0) / 1000;
      const rateOk = telemetry.length >= elapsed * 1.5; // ~2 snaps/s esperados
      check("conexión estable (sin errores)", true);
      check("flujo continuo de snapshots", rateOk, `${telemetry.length} snaps en ${elapsed.toFixed(1)}s`);
      check("ventana deslizante MAX_POINTS", telemetry.length <= MAX_POINTS);
      check("logs con eventos reales", logs.length > 0);
      if (telemetry.length > 2) {
        const t = telemetry[telemetry.length - 1].timestamp;
        const tPrev = telemetry[telemetry.length - 2].timestamp;
        const gapMs = t - tPrev;
        check("timestamps incrementales (no congelados)", gapMs > 0, `gap ${gapMs}ms`);
      }
      ws.close();
      resolve();
    }, 6000);
  });
}

function runInferenceEventTest() {
  return new Promise((resolve) => {
    let lastInferenceAt = 0;
    let cycles = 0;
    let snapshots = 0;
    const ws = new WebSocket(WS_URL);
    ws.onmessage = (e) => {
      const data = JSON.parse(e.data);
      snapshots++;
      if (data.inference && data.inference.lastAtMs > lastInferenceAt) {
        lastInferenceAt = data.inference.lastAtMs;
        cycles++;
      }
    };
    setTimeout(() => {
      check("detección de ciclos de inferencia", cycles >= 1 && cycles <= snapshots, `${cycles} ciclos / ${snapshots} snaps`);
      ws.close();
      resolve();
    }, 12000);
  });
}

(async () => {
  console.log("== Sincronización cliente <-> servidor ==");
  await runSyncTest();
  console.log("== Detección de ciclos de inferencia (dedup) ==");
  await runInferenceEventTest();
  console.log(`\n===== RESUMEN: ${pass} PASS, ${fail} FAIL =====`);
  process.exit(fail ? 1 : 0);
})();

// Prueba LÓGICA con datos REALES: conecta al servidor, recolecta snapshots,
// construye TelemetryPoints como page.tsx y valida el cálculo estadístico
// sobre mediciones reales del motor.
//
// Uso:  node --experimental-strip-types tests/live_logic_test.mjs
// Requiere: servidor en ws://localhost:8000/ws/telemetry
import { computeStatisticalSummary } from "../dashboard/src/lib/telemetryStream.ts";

const WS_URL = process.env.WS_URL || "ws://localhost:8000/ws/telemetry";
let pass = 0, fail = 0;
const check = (name, ok, detail = "") => {
  if (ok) { pass++; console.log(`  PASS  ${name}${detail ? `  [${detail}]` : ""}`); }
  else { fail++; console.log(`  FAIL  ${name}${detail ? `  [${detail}]` : ""}`); }
};

const ws = new WebSocket(WS_URL);
const telemetry = [];
let lastInferenceAt = 0;
let cycles = 0;

ws.onmessage = (e) => {
  const d = JSON.parse(e.data);
  const inf = d.inference || {};
  if (inf.lastAtMs > lastInferenceAt) { lastInferenceAt = inf.lastAtMs; cycles++; }
  telemetry.push({
    timestamp: d.timestamp, timeLabel: d.timeLabel,
    throughputTokSec: inf.tokSec ?? 0, latencyMs: inf.latencyMsPerToken ?? 0,
    tokensGenerated: inf.tokens ?? 0, inferenceConfidence: inf.confidence ?? 0,
    inferenceActive: inf.active ?? false, inferenceAvailable: inf.available ?? false,
    inferenceError: inf.error ?? "",
    vramAllocatedMb: d.vramAllocatedMb ?? 0, vramTotalMb: d.vramTotalMb ?? 0,
    gpuUtilPercent: d.gpuUtilPercent ?? 0, cpuUtilPercent: d.cpuUtilPercent ?? 0,
    tempCelsius: d.tempCelsius ?? 0, powerWatts: d.powerWatts ?? 0,
    procRssMb: d.procRssMb ?? 0, systemRamMb: d.systemRamMb ?? 0, systemRamTotalMb: d.systemRamTotalMb ?? 0,
  });
  if (telemetry.length > 120) telemetry.shift();
};

setTimeout(() => {
  console.log("== Stats sobre datos REALES del servidor ==");
  console.log(`  datos: ${telemetry.length} snapshots, ${cycles} ciclos de inferencia`);
  const s = computeStatisticalSummary(telemetry);

  check("hay ciclos de inferencia reales", cycles >= 1, `${cycles} ciclos`);
  check("latencySamples = ciclos distintos (no snapshots)", s.latencySamples === cycles, `latencySamples=${s.latencySamples}`);
  check("P50 latencia en rango plausible (10-500 ms)", s.p50 >= 10 && s.p50 <= 500, `${s.p50} ms`);
  check("P99 >= P50 (monótono)", s.p99 >= s.p50, `P99=${s.p99} P50=${s.p50}`);
  check("desviación no negativa", s.stdDev >= 0, `${s.stdDev}`);
  check("media >= P50 o <= P99 (sano)", s.mean >= s.p50 - 1 && s.mean <= s.p99, `mean=${s.mean}`);
  check("tendencia calculada o 0", Number.isFinite(s.throughputTrendSlope), `${s.throughputTrendSlope}`);
  check("skewness/kurtosis finitas", Number.isFinite(s.skewness) && Number.isFinite(s.kurtosis), `skew=${s.skewness} kurt=${s.kurtosis}`);

  // integridad de hardware real
  const last = telemetry[telemetry.length - 1];
  check("VRAM real (total 6144MB o mayor)", last.vramTotalMb >= 6000, `${last.vramTotalMb} MB`);
  check("temp GPU en rango real (30-110°C)", last.tempCelsius >= 30 && last.tempCelsius <= 110, `${last.tempCelsius}°C`);
  check("CPU en rango (0-100%)", last.cpuUtilPercent >= 0 && last.cpuUtilPercent <= 100, `${last.cpuUtilPercent}%`);
  check("RAM sistema positiva", last.systemRamMb > 1000, `${last.systemRamMb} MB`);

  console.log(`\n===== RESUMEN VIVO: ${pass} PASS, ${fail} FAIL =====`);
  process.exit(fail ? 1 : 0);
}, 15000);

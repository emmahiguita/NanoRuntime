// Pruebas LÓGICAS del cálculo estadístico real (dashboard/src/lib/telemetryStream.ts).
// Ejecuta el módulo TypeScript real con Node 24 (type stripping), sin duplicar lógica.
//
// Uso:  node --experimental-strip-types tests/logic_tests.mjs
import { computeStatisticalSummary } from "../dashboard/src/lib/telemetryStream.ts";
import * as ss from "../dashboard/node_modules/simple-statistics/dist/simple-statistics.cjs";
import regression from "../dashboard/node_modules/regression/dist/regression.js";

let pass = 0;
let fail = 0;
function check(name, ok, detail = "") {
  if (ok) { pass++; console.log(`  PASS  ${name}${detail ? `  [${detail}]` : ""}`); }
  else { fail++; console.log(`  FAIL  ${name}${detail ? `  [${detail}]` : ""}`); }
}

// Helper: construye un TelemetryPoint mínimo
function pt(over = {}) {
  return {
    timestamp: 0, timeLabel: "", throughputTokSec: 0, latencyMs: 0, tokensGenerated: 0,
    inferenceConfidence: 0, inferenceActive: false, inferenceAvailable: true, inferenceError: "",
    vramAllocatedMb: 0, vramTotalMb: 0, gpuUtilPercent: 0, cpuUtilPercent: 0, tempCelsius: 0,
    powerWatts: 0, procRssMb: 0, systemRamMb: 0, systemRamTotalMb: 0, ...over,
  };
}

console.log("== 1. Entrada vacía ==");
{
  const s = computeStatisticalSummary([]);
  check("ceros con array vacío", s.p50 === 0 && s.p99 === 0 && s.latencySamples === 0 && s.throughputTrendSlope === 0);
}

console.log("== 2. Deduplicación de valores consecutivos ==");
{
  // 3 ciclos reales distintos, cada uno repetido 5 veces (snapshots de hardware)
  const telemetry = [
    ...Array(5).fill(pt({ latencyMs: 80, throughputTokSec: 12 })),
    ...Array(5).fill(pt({ latencyMs: 90, throughputTokSec: 11 })),
    ...Array(5).fill(pt({ latencyMs: 100, throughputTokSec: 10 })),
  ];
  const s = computeStatisticalSummary(telemetry);
  check("latencySamples = 3 ciclos (no 15 duplicados)", s.latencySamples === 3, `got ${s.latencySamples}`);
}

console.log("== 3. Percentiles correctos (P50/P90/P95/P99) ==");
{
  const values = [80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200];
  const telemetry = values.map((v) => pt({ latencyMs: v, throughputTokSec: 20 }));
  const s = computeStatisticalSummary(telemetry);
  const sorted = [...values].sort((a, b) => a - b);
  const approx = (a, b) => Math.abs(a - b) < 0.01;
  check("P50", approx(s.p50, ss.quantile(sorted, 0.5)), `got ${s.p50}`);
  check("P90", approx(s.p90, ss.quantile(sorted, 0.9)), `got ${s.p90}`);
  check("P95", approx(s.p95, ss.quantile(sorted, 0.95)), `got ${s.p95}`);
  check("P99", approx(s.p99, ss.quantile(sorted, 0.99)), `got ${s.p99}`);
  check("media", approx(s.mean, ss.mean(values)), `got ${s.mean}`);
  check("desviación", approx(s.stdDev, ss.standardDeviation(values)), `got ${s.stdDev}`);
}

console.log("== 4. Skewness/kurtosis REALES (muestrales, no heurísticas) ==");
{
  const values = [80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180];
  const telemetry = values.map((v) => pt({ latencyMs: v, throughputTokSec: 20 }));
  const s = computeStatisticalSummary(telemetry);
  check("skewness = sampleSkewness", Math.abs(s.skewness - ss.sampleSkewness(values)) < 0.001, `got ${s.skewness}`);
  check("kurtosis = sampleKurtosis", Math.abs(s.kurtosis - ss.sampleKurtosis(values)) < 0.001, `got ${s.kurtosis}`);
}
{
  // datos con cola derecha (sesgo positivo real)
  const skewed = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 90];
  const s = computeStatisticalSummary(skewed.map((v) => pt({ latencyMs: v })));
  check("skewness > 0 con cola derecha", s.skewness > 0.5, `got ${s.skewness}`);
}

console.log("== 5. Guards con muestras insuficientes ==");
{
  const s1 = computeStatisticalSummary([pt({ latencyMs: 80 })]);
  check("1 muestra: skewness=0", s1.skewness === 0);
  const s2 = computeStatisticalSummary([pt({ latencyMs: 80 }), pt({ latencyMs: 90 })]);
  check("2 muestras: skewness=0, kurtosis=0", s2.skewness === 0 && s2.kurtosis === 0);
}

console.log("== 6. Tendencia de throughput (regresión real) ==");
{
  // throughput decreciente 20->10 en 5 ciclos: pendiente negativa ≈ -2.5
  const telemetry = [
    ...Array(3).fill(pt({ latencyMs: 100, throughputTokSec: 20 })),
    ...Array(3).fill(pt({ latencyMs: 100, throughputTokSec: 17.5 })),
    ...Array(3).fill(pt({ latencyMs: 100, throughputTokSec: 15 })),
    ...Array(3).fill(pt({ latencyMs: 100, throughputTokSec: 12.5 })),
    ...Array(3).fill(pt({ latencyMs: 100, throughputTokSec: 10 })),
  ];
  const s = computeStatisticalSummary(telemetry);
  check("pendiente negativa (~-2.5)", s.throughputTrendSlope < -2.4 && s.throughputTrendSlope > -2.6, `got ${s.throughputTrendSlope}`);
}
{
  const flat = [pt({ latencyMs: 100, throughputTokSec: 15 }), pt({ latencyMs: 100, throughputTokSec: 15 })];
  const s = computeStatisticalSummary(flat);
  check("2 ciclos: pendiente 0", s.throughputTrendSlope === 0);
}

console.log("== 7. Ceros en latencia se ignoran (sin medición aún) ==");
{
  const telemetry = [pt({ latencyMs: 0, throughputTokSec: 0 }), pt({ latencyMs: 0, throughputTokSec: 0 })];
  const s = computeStatisticalSummary(telemetry);
  check("sin latencias reales -> latencySamples=0, percentiles 0", s.latencySamples === 0 && s.p50 === 0);
}

console.log(`\n===== RESUMEN LÓGICA: ${pass} PASS, ${fail} FAIL =====`);
process.exit(fail ? 1 : 0);

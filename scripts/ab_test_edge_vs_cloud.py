#!/usr/bin/env python3
"""
NanoAI Research — A/B Test REAL: Edge (Tier 1) vs Cloud (Tier 3)

Ejecuta el runtime nanortime REAL contra un conjunto de prompts,
alterna entre modo edge-only y modo cloud, y mide:
- Latencia de extremo a extremo (ms)
- RAM pico del proceso (RSS via /proc/<pid>/status)
- Costo estimado en API (tokens * precio)
- Decisión de routing (tier usado por el orchestrator)

Uso:
    python3 scripts/ab_test_edge_vs_cloud.py \
        --binary target/release/nanortime \
        --config nano.manifest.json \
        --prompts scripts/routing_prompts.json \
        --queries 50

Requiere:
    - Binario nanortime compilado en release
    - nano.manifest.json configurado con tier3 habilitado y NANO_API_KEY en env
    - psutil: pip install psutil
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Optional

try:
    import psutil
except ImportError:
    print("ERROR: psutil no instalado. Ejecuta: pip install psutil")
    sys.exit(1)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Precio aproximado de la API en USD por 1k tokens (input+output)
CLOUD_COST_PER_1K_TOKENS = 0.003   # Claude Sonnet aprox

# =============================================================
# Dataset de prompts por defecto
# =============================================================
DEFAULT_PROMPTS_SIMPLE = [
    "¿Cuánto es 15 + 27?",
    "¿Cuál es la capital de Francia?",
    "Traduce 'Hello world' al español.",
    "¿Qué día de la semana fue el 1 de enero de 2000?",
    "¿Cuántos metros hay en un kilómetro?",
]

DEFAULT_PROMPTS_COMPLEX = [
    "Explica la teoría de la relatividad general de Einstein con un ejemplo práctico.",
    "Escribe una función Python para calcular la serie de Fibonacci con memoización.",
    "¿Cuáles son las implicaciones éticas del uso de IA en el sistema judicial?",
    "Describe el mecanismo de atención en transformers y su ventaja vs RNNs.",
    "Compara las arquitecturas de microservicios vs monolíticas en sistemas distribuidos.",
]


def get_process_peak_rss_mb(pid: int, proc: subprocess.Popen) -> float:
    """
    Monitorea el proceso hasta que termina y devuelve el peak RSS en MB.
    Usa psutil para leer /proc/<pid>/status en Linux o equivalente.
    """
    peak_rss_bytes = 0
    try:
        ps = psutil.Process(pid)
        while proc.poll() is None:
            try:
                info = ps.memory_info()
                if info.rss > peak_rss_bytes:
                    peak_rss_bytes = info.rss
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                break
            time.sleep(0.2)
        # Una última lectura por si terminó rápido
        try:
            info = ps.memory_info()
            if info.rss > peak_rss_bytes:
                peak_rss_bytes = info.rss
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        pass

    return peak_rss_bytes / (1024 * 1024)


def run_nanortime(
    binary: str,
    config: str,
    prompt: str,
    max_tokens: int = 256,
    edge_only: bool = True,
    timeout: int = 120,
) -> dict:
    """
    Ejecuta nanortime con el prompt dado y devuelve métricas reales.
    Retorna: {latency_ms, peak_rss_mb, output_text, tokens_estimated, error}
    """
    cmd = [
        binary,
        "--config", config,
        "--prompt", prompt,
        "--max-tokens", str(max_tokens),
        "--quiet",
    ]
    if edge_only:
        cmd.append("--edge-only")

    t0 = time.monotonic()
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        # Monitorear RSS en tiempo real mientras el proceso corre
        peak_rss_mb = get_process_peak_rss_mb(proc.pid, proc)

        stdout, stderr = proc.communicate(timeout=timeout)
        latency_ms = (time.monotonic() - t0) * 1000

        # Estimar tokens generados (aprox: palabras * 1.3)
        output_words = len(stdout.split())
        tokens_estimated = max(1, int(output_words * 1.3))

        return {
            "latency_ms": round(latency_ms, 1),
            "peak_rss_mb": round(peak_rss_mb, 1),
            "output_text": stdout.strip()[:500],
            "tokens_estimated": tokens_estimated,
            "exit_code": proc.returncode,
            "error": stderr.strip()[:300] if proc.returncode != 0 else None,
        }
    except subprocess.TimeoutExpired:
        proc.kill()
        return {
            "latency_ms": timeout * 1000,
            "peak_rss_mb": 0.0,
            "output_text": "",
            "tokens_estimated": 0,
            "exit_code": -1,
            "error": f"Timeout after {timeout}s",
        }
    except Exception as e:
        return {
            "latency_ms": 0.0,
            "peak_rss_mb": 0.0,
            "output_text": "",
            "tokens_estimated": 0,
            "exit_code": -2,
            "error": str(e),
        }


def run_ab_experiment(
    binary: str,
    config: str,
    prompts: list[str],
    max_tokens: int = 256,
) -> dict:
    """
    Alterna prompt por prompt entre edge y cloud, acumula métricas reales.
    """
    edge_results = []
    cloud_results = []

    print(f"\n{'='*60}")
    print(f"  A/B Test: {len(prompts)} prompts × 2 tiers")
    print(f"{'='*60}\n")

    for i, prompt in enumerate(prompts):
        print(f"[{i+1}/{len(prompts)}] Prompt: {prompt[:60]}...")

        # --- EDGE ---
        print("  🟢 Edge (local) ... ", end="", flush=True)
        edge = run_nanortime(binary, config, prompt, max_tokens, edge_only=True)
        edge_results.append(edge)
        if edge["error"]:
            print(f"ERROR: {edge['error'][:80]}")
        else:
            print(f"{edge['latency_ms']:.0f}ms | RSS: {edge['peak_rss_mb']:.1f}MB")

        # --- CLOUD ---
        print("  🔵 Cloud (tier3)... ", end="", flush=True)
        cloud = run_nanortime(binary, config, prompt, max_tokens, edge_only=False)
        cloud_results.append(cloud)
        if cloud["error"]:
            print(f"ERROR: {cloud['error'][:80]}")
        else:
            print(f"{cloud['latency_ms']:.0f}ms | RSS: {cloud['peak_rss_mb']:.1f}MB")

        print()

    # --- Agregados ---
    def safe_avg(lst, key):
        vals = [x[key] for x in lst if x.get("exit_code", -1) == 0 and x[key] > 0]
        return round(sum(vals) / len(vals), 1) if vals else 0.0

    edge_tokens_total = sum(x["tokens_estimated"] for x in edge_results)
    cloud_tokens_total = sum(x["tokens_estimated"] for x in cloud_results)
    edge_cost = 0.0  # local = free
    cloud_cost = round((cloud_tokens_total / 1000) * CLOUD_COST_PER_1K_TOKENS, 4)

    summary = {
        "edge": {
            "tier": "Tier 1 (Local Edge)",
            "queries": len(prompts),
            "avg_latency_ms": safe_avg(edge_results, "latency_ms"),
            "avg_peak_rss_mb": safe_avg(edge_results, "peak_rss_mb"),
            "total_tokens_estimated": edge_tokens_total,
            "total_cost_usd": edge_cost,
            "errors": sum(1 for x in edge_results if x.get("exit_code", -1) != 0),
        },
        "cloud": {
            "tier": "Tier 3 (Cloud)",
            "queries": len(prompts),
            "avg_latency_ms": safe_avg(cloud_results, "latency_ms"),
            "avg_peak_rss_mb": safe_avg(cloud_results, "peak_rss_mb"),
            "total_tokens_estimated": cloud_tokens_total,
            "total_cost_usd": cloud_cost,
            "errors": sum(1 for x in cloud_results if x.get("exit_code", -1) != 0),
        },
        "comparison": {},
    }

    # Calcular ahorro
    if summary["cloud"]["avg_latency_ms"] > 0:
        latency_diff_pct = round(
            100 * (summary["cloud"]["avg_latency_ms"] - summary["edge"]["avg_latency_ms"])
            / summary["cloud"]["avg_latency_ms"], 1
        )
        summary["comparison"]["latency_delta_pct_vs_cloud"] = latency_diff_pct

    if cloud_cost > 0:
        cost_savings_pct = round(100 * (cloud_cost - edge_cost) / cloud_cost, 1)
        summary["comparison"]["cost_savings_pct_edge_vs_cloud"] = cost_savings_pct

    return summary, edge_results, cloud_results


def main():
    parser = argparse.ArgumentParser(
        description="A/B Test REAL: NanoRuntime Edge vs Cloud"
    )
    parser.add_argument("--binary", default="target/release/nanortime",
                        help="Ruta al binario compilado (default: target/release/nanortime)")
    parser.add_argument("--config", default="nano.manifest.json",
                        help="Ruta al manifest de configuración")
    parser.add_argument("--prompts", default=None,
                        help="JSON con lista de prompts. Si no se pasa, usa el dataset default.")
    parser.add_argument("--queries", type=int, default=10,
                        help="Número de prompts a ejecutar del dataset (default: 10)")
    parser.add_argument("--max-tokens", type=int, default=256,
                        help="Tokens máximos por respuesta (default: 256)")
    parser.add_argument("--output", default="data/research/ab_test_results.json",
                        help="Dónde guardar el JSON de resultados")
    args = parser.parse_args()

    # Validar binario
    if not Path(args.binary).exists():
        print(f"❌ Binario no encontrado: {args.binary}")
        print("   Compila con: cargo build --release -p nanortime-cli")
        sys.exit(1)

    # Validar config
    if not Path(args.config).exists():
        print(f"❌ Config no encontrada: {args.config}")
        sys.exit(1)

    # Cargar prompts
    if args.prompts and Path(args.prompts).exists():
        with open(args.prompts) as f:
            all_prompts = json.load(f)
    else:
        all_prompts = DEFAULT_PROMPTS_SIMPLE + DEFAULT_PROMPTS_COMPLEX

    prompts = all_prompts[: args.queries]
    print(f"Usando {len(prompts)} prompts.")

    # Ejecutar
    summary, edge_raw, cloud_raw = run_ab_experiment(
        binary=args.binary,
        config=args.config,
        prompts=prompts,
        max_tokens=args.max_tokens,
    )

    # Guardar
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    full_output = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "binary": args.binary,
        "config": args.config,
        "summary": summary,
        "raw_edge": edge_raw,
        "raw_cloud": cloud_raw,
    }
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(full_output, f, indent=2, ensure_ascii=False)

    # Tabla final
    print("=" * 60)
    print("🏆 RESULTADOS FINALES")
    print("=" * 60)
    e = summary["edge"]
    c = summary["cloud"]
    print(f"{'Métrica':<30} {'Edge':>12} {'Cloud':>12}")
    print(f"{'-'*30} {'-'*12} {'-'*12}")
    print(f"{'Latencia media (ms)':<30} {e['avg_latency_ms']:>12.1f} {c['avg_latency_ms']:>12.1f}")
    print(f"{'Peak RAM media (MB)':<30} {e['avg_peak_rss_mb']:>12.1f} {c['avg_peak_rss_mb']:>12.1f}")
    print(f"{'Tokens estimados':<30} {e['total_tokens_estimated']:>12} {c['total_tokens_estimated']:>12}")
    print(f"{'Costo total USD':<30} {e['total_cost_usd']:>12.4f} {c['total_cost_usd']:>12.4f}")
    print(f"{'Errores':<30} {e['errors']:>12} {c['errors']:>12}")
    if "cost_savings_pct_edge_vs_cloud" in summary["comparison"]:
        pct = summary["comparison"]["cost_savings_pct_edge_vs_cloud"]
        print(f"\n💰 Ahorro de costo Edge vs Cloud: {pct}%")
    print(f"\n📁 Resultados guardados en: {args.output}")


if __name__ == "__main__":
    main()

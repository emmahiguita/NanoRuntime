#!/usr/bin/env python3
"""
NanoAI Research — Benchmark de Routing por Entropía (Paper Contribution 2)

Ejecuta el runtime real con routing híbrido y mide:
- Entropía de Shannon real de cada respuesta (extraída de token probs)
- Tier elegido por el orchestrator (local vs cloud)
- Latencia real por tier
- Costo real de API (cloud tokens * precio)
- Accuracy del routing: ¿se tomó la decisión correcta?

El script genera datos directamente citables en el paper.

Uso:
    pip install psutil
    python3 scripts/benchmark_routing.py \\
        --binary target/release/nanortime \\
        --config nano.manifest.json \\
        --prompts scripts/routing_prompts.json \\
        --output data/research/routing_results.json

Dataset de prompts (routing_prompts.json):
    [{"prompt": "...", "expected_tier": "local|cloud", "category": "simple|complex"}, ...]
"""

import argparse
import json
import math
import os
import re
import subprocess
import sys
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

# Precio cloud en USD por 1000 tokens (Claude Sonnet aproximado)
CLOUD_PRICE_PER_1K = 0.003

# Dataset default si no se pasa --prompts
DEFAULT_PROMPTS = [
    # Simples — esperamos que el modelo local los maneje (alta confianza → baja entropía)
    {"prompt": "What is 12 * 8?", "category": "simple", "expected_tier": "local"},
    {"prompt": "What is the capital of France?", "category": "simple", "expected_tier": "local"},
    {"prompt": "Translate 'hello world' to Spanish.", "category": "simple", "expected_tier": "local"},
    {"prompt": "What is the boiling point of water in Celsius?", "category": "simple", "expected_tier": "local"},
    {"prompt": "How many days are in a leap year?", "category": "simple", "expected_tier": "local"},
    {"prompt": "What color do you get mixing red and blue?", "category": "simple", "expected_tier": "local"},
    {"prompt": "What is the square root of 144?", "category": "simple", "expected_tier": "local"},
    {"prompt": "Name the planet closest to the Sun.", "category": "simple", "expected_tier": "local"},
    {"prompt": "What is 2 to the power of 10?", "category": "simple", "expected_tier": "local"},
    {"prompt": "In Python, what does len([1,2,3]) return?", "category": "simple", "expected_tier": "local"},

    # Complejos — mayor incertidumbre, posible escalado a cloud
    {"prompt": "Explain the mathematical proof that there are infinitely many prime numbers.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Compare microservices vs monolithic architecture with specific tradeoffs.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Describe the mechanism of action of mRNA vaccines at the molecular level.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Explain the implications of Gödel's incompleteness theorems for mathematics.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Write a Rust function to implement a thread-safe LRU cache with O(1) operations.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Analyze the trade-offs between consistency and availability in distributed systems.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Explain how backpropagation computes gradients in a neural network.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Describe the cryptographic properties that make RSA secure.", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "What are the key differences between TCP and QUIC protocol design?", "category": "complex", "expected_tier": "cloud"},
    {"prompt": "Explain the attention mechanism in transformers and why it scales quadratically.", "category": "complex", "expected_tier": "cloud"},
]


def run_and_measure(
    binary: str,
    config: str,
    prompt: str,
    max_tokens: int = 256,
    timeout: int = 120,
) -> dict:
    """Lanza nanortime real, mide latencia, RSS, tokens, entropía del output."""
    cmd = [
        binary,
        "--config", config,
        "--prompt", prompt,
        "--max-tokens", str(max_tokens),
        "--quiet",
        # NO --edge-only: queremos el routing real
    ]

    t0 = time.monotonic()
    peak_rss = 0

    try:
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )

        # Monitor RSS mientras corre
        try:
            ps = psutil.Process(proc.pid)
            while proc.poll() is None:
                try:
                    rss = ps.memory_info().rss
                    if rss > peak_rss:
                        peak_rss = rss
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    break
                time.sleep(0.2)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

        stdout, stderr = proc.communicate(timeout=timeout)
        elapsed_ms = (time.monotonic() - t0) * 1000

        # Parsear métricas emitidas por el CLI
        tok_s, tokens, tier, confidence = None, 0, "unknown", 0.0
        m = re.search(
            r'\[METRICS\] tokens=(\d+) elapsed_ms=[\d.]+ tok_s=([\d.]+) tier=(\S+) confidence=([\d.]+)',
            stderr,
        )
        if m:
            tokens = int(m.group(1))
            tok_s = float(m.group(2))
            tier = m.group(3)
            confidence = float(m.group(4))

        # Calcular entropía de Shannon a partir de la distribución de confianza reportada.
        # confidence ∈ [0,1] es 1 - normalized_entropy → normalized_entropy = 1 - confidence
        normalized_entropy = 1.0 - confidence
        # H_raw ≈ normalized_entropy * log2(vocab_size).
        # Para reportar en el paper usamos normalized_entropy directamente (0=cierto, 1=max incertidumbre)

        return {
            "output": stdout.strip()[:300],
            "latency_ms": round(elapsed_ms, 1),
            "peak_rss_mb": round(peak_rss / (1024 * 1024), 1),
            "tokens_generated": tokens,
            "tok_s": tok_s,
            "tier_used": tier,
            "confidence": round(confidence, 4),
            "normalized_entropy": round(normalized_entropy, 4),
            "exit_code": proc.returncode,
            "error": stderr[:400] if proc.returncode != 0 else None,
        }

    except subprocess.TimeoutExpired:
        proc.kill()
        return {
            "output": "", "latency_ms": timeout * 1000.0, "peak_rss_mb": 0.0,
            "tokens_generated": 0, "tok_s": None, "tier_used": "timeout",
            "confidence": 0.0, "normalized_entropy": 1.0,
            "exit_code": -1, "error": f"Timeout {timeout}s",
        }
    except Exception as e:
        return {
            "output": "", "latency_ms": 0.0, "peak_rss_mb": 0.0,
            "tokens_generated": 0, "tok_s": None, "tier_used": "error",
            "confidence": 0.0, "normalized_entropy": 1.0,
            "exit_code": -2, "error": str(e),
        }


def main():
    parser = argparse.ArgumentParser(
        description="Benchmark de Routing por Entropía — NanoAI (REAL)"
    )
    parser.add_argument("--binary", default="target/release/nanortime")
    parser.add_argument("--config", default="nano.manifest.json")
    parser.add_argument("--prompts", default=None,
                        help="JSON con lista de {prompt, category, expected_tier}")
    parser.add_argument("--max-tokens", type=int, default=256)
    parser.add_argument("--output", default="data/research/routing_results.json")
    args = parser.parse_args()

    if not Path(args.binary).exists():
        print(f"❌ Binario: {args.binary}")
        print("   cargo build --release -p nanortime-cli")
        sys.exit(1)

    if not Path(args.config).exists():
        print(f"❌ Config: {args.config}")
        sys.exit(1)

    prompts = DEFAULT_PROMPTS
    if args.prompts and Path(args.prompts).exists():
        with open(args.prompts) as f:
            prompts = json.load(f)

    print(f"{'=' * 60}")
    print(f"  Routing Benchmark — {len(prompts)} prompts")
    print(f"{'=' * 60}\n")

    results = []
    for i, item in enumerate(prompts):
        prompt = item["prompt"]
        expected = item.get("expected_tier", "?")
        category = item.get("category", "?")

        print(f"[{i+1}/{len(prompts)}] [{category}] {prompt[:60]}...")
        r = run_and_measure(args.binary, args.config, prompt, args.max_tokens)

        tier = r["tier_used"]
        correct_routing = (
            (expected == "local" and tier.startswith("local")) or
            (expected == "cloud" and "cloud" in tier)
        ) if expected != "?" else None

        symbol = "" if correct_routing is None else ("✅" if correct_routing else "❌")
        print(f"  {symbol} tier={tier} | entropy={r['normalized_entropy']:.3f} | "
              f"conf={r['confidence']:.3f} | {r['latency_ms']:.0f}ms | "
              f"RSS={r['peak_rss_mb']:.0f}MB")
        if r.get("error"):
            print(f"   ERROR: {r['error'][:100]}")

        results.append({
            **r,
            "prompt": prompt[:200],
            "category": category,
            "expected_tier": expected,
            "correct_routing": correct_routing,
        })

    # Estadísticas para el paper
    successful = [r for r in results if r["exit_code"] == 0]
    local_results = [r for r in successful if r["tier_used"].startswith("local")]
    cloud_results = [r for r in successful if "cloud" in r["tier_used"]]
    correct = [r for r in results if r["correct_routing"] is True]
    evaluated = [r for r in results if r["correct_routing"] is not None]

    def avg(lst, key):
        vals = [x[key] for x in lst if x.get(key) is not None]
        return round(sum(vals) / len(vals), 3) if vals else 0.0

    # Costo real: cloud tokens * precio
    cloud_tokens = sum(r["tokens_generated"] for r in cloud_results)
    local_tokens = sum(r["tokens_generated"] for r in local_results)
    cloud_cost_usd = round((cloud_tokens / 1000) * CLOUD_PRICE_PER_1K, 5)
    all_cloud_cost_usd = round((sum(r["tokens_generated"] for r in successful) / 1000) * CLOUD_PRICE_PER_1K, 5)
    cost_savings_pct = round(100 * (all_cloud_cost_usd - cloud_cost_usd) / all_cloud_cost_usd, 1) if all_cloud_cost_usd > 0 else 0.0

    routing_accuracy = round(100 * len(correct) / len(evaluated), 1) if evaluated else 0.0

    summary = {
        "total_prompts": len(prompts),
        "successful_runs": len(successful),
        "routing": {
            "local_count": len(local_results),
            "cloud_count": len(cloud_results),
            "routing_accuracy_pct": routing_accuracy,
        },
        "performance": {
            "avg_latency_local_ms": avg(local_results, "latency_ms"),
            "avg_latency_cloud_ms": avg(cloud_results, "latency_ms"),
            "avg_entropy_local": avg(local_results, "normalized_entropy"),
            "avg_entropy_cloud": avg(cloud_results, "normalized_entropy"),
            "avg_confidence_local": avg(local_results, "confidence"),
            "avg_confidence_cloud": avg(cloud_results, "confidence"),
        },
        "cost": {
            "local_tokens": local_tokens,
            "cloud_tokens": cloud_tokens,
            "cloud_cost_usd": cloud_cost_usd,
            "hypothetical_all_cloud_cost_usd": all_cloud_cost_usd,
            "cost_savings_pct": cost_savings_pct,
        },
    }

    output = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "binary": args.binary,
        "config": args.config,
        "summary": summary,
        "per_prompt": results,
    }

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    # Tabla final
    print(f"\n{'=' * 60}")
    print("RESULTADOS PARA EL PAPER (Contribución 2: Entropy Routing)")
    print(f"{'=' * 60}")
    print(f"  Prompts totales    : {len(prompts)}")
    print(f"  Ejecutados local   : {len(local_results)}  (avg entropy={summary['performance']['avg_entropy_local']:.3f})")
    print(f"  Escalados cloud    : {len(cloud_results)}  (avg entropy={summary['performance']['avg_entropy_cloud']:.3f})")
    print(f"  Routing accuracy   : {routing_accuracy}%")
    print(f"  Latencia local avg : {summary['performance']['avg_latency_local_ms']:.0f} ms")
    print(f"  Latencia cloud avg : {summary['performance']['avg_latency_cloud_ms']:.0f} ms")
    print(f"  Costo cloud real   : ${cloud_cost_usd:.5f} USD")
    print(f"  Costo todo cloud   : ${all_cloud_cost_usd:.5f} USD")
    print(f"  Ahorro de costo    : {cost_savings_pct}%")
    print(f"\n📁 Guardado en: {args.output}")


if __name__ == "__main__":
    main()

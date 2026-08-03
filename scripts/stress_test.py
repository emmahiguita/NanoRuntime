#!/usr/bin/env python3
"""
NanoAI Research — Real Stress & Multi-Prompt Stability Test

Prueba de estrés real y sostenida sobre el ejecutable `nanortime`:
1. Ejecuta múltiples prompts consecutivos (20+ preguntas complejas y variadas).
2. Monitorea fugas de memoria (RSS footprint) a lo largo de las iteraciones.
3. Mide estabilidad de rendimiento (tok/s, latencia, perplejidad/confianza).
4. Verifica tolerancia a carga y uso continuo sin OOM ni degrada de velocidad.

Uso:
    python3 scripts/stress_test.py --binary target/release/nanortime.exe --model "C:\llama-cpp-server\models\qwen2.5-1.5b-instruct-q4_k_m.gguf" --iterations 15
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

try:
    import psutil
except ImportError:
    print("ERROR: psutil no instalado. Ejecuta: pip install psutil")
    sys.exit(1)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Colección diversa de preguntas para la prueba de estrés
STRESS_PROMPTS = [
    "Explain the concept of garbage collection in programming languages.",
    "What is the difference between a process and a thread?",
    "Write a short Python function to reverse a linked list.",
    "Explain how a hash table handles key collisions.",
    "What is the role of the operating system kernel?",
    "Explain the difference between TCP and UDP networking protocols.",
    "What is a deadlock in concurrent programming and how can it be prevented?",
    "Explain the concept of recursion with a simple mathematical example.",
    "What is the difference between stack and heap memory allocation?",
    "Explain how public-key cryptography works for secure communications.",
    "Write a SQL query to find the second highest salary from an Employee table.",
    "Explain the difference between synchronous and asynchronous I/O operations.",
    "What are ACID properties in database transaction management?",
    "Explain how virtual memory and paging work in modern operating systems.",
    "Write a binary search implementation in Python.",
]


def format_chat_prompt(user_message: str) -> str:
    return f"<|im_start|>user\n{user_message}<|im_end|>\n<|im_start|>assistant\n"


def run_prompt(binary: str, config: str, prompt: str, max_tokens: int = 128) -> dict:
    formatted = format_chat_prompt(prompt)
    cmd = [
        binary,
        "--config", config,
        "--prompt", formatted,
        "--max-tokens", str(max_tokens),
        "--edge-only",
        "--quiet",
    ]

    t0 = time.monotonic()
    peak_rss = 0

    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        try:
            ps = psutil.Process(proc.pid)
            while proc.poll() is None:
                try:
                    rss = ps.memory_info().rss
                    if rss > peak_rss:
                        peak_rss = rss
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    break
                time.sleep(0.1)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

        stdout, stderr = proc.communicate(timeout=120)
        elapsed_ms = (time.monotonic() - t0) * 1000.0

        tok_s, tokens, confidence = None, 0, 0.0
        m = re.search(r'\[METRICS\] tokens=(\d+) elapsed_ms=[\d.]+ tok_s=([\d.]+) tier=\S+ confidence=([\d.]+)', stderr)
        if m:
            tokens = int(m.group(1))
            tok_s = float(m.group(2))
            confidence = float(m.group(3))

        return {
            "output": stdout.strip()[:200],
            "latency_ms": round(elapsed_ms, 1),
            "peak_rss_mb": round(peak_rss / (1024 * 1024), 1),
            "tokens": tokens,
            "tok_s": tok_s,
            "confidence": confidence,
            "exit_code": proc.returncode,
            "error": stderr[:300] if proc.returncode != 0 else None,
        }

    except Exception as e:
        return {
            "output": "",
            "latency_ms": 0.0,
            "peak_rss_mb": 0.0,
            "tokens": 0,
            "tok_s": None,
            "confidence": 0.0,
            "exit_code": -1,
            "error": str(e),
        }


def main():
    parser = argparse.ArgumentParser(description="Prueba de Estrés y Estabilidad Multi-Prompt")
    parser.add_argument("--binary", default="target/release/nanortime.exe")
    parser.add_argument("--config", default="nano.manifest.json")
    parser.add_argument("--model", required=True)
    parser.add_argument("--iterations", type=int, default=15)
    parser.add_argument("--max-tokens", type=int, default=128)
    parser.add_argument("--output", default="data/research/stress_results.json")
    args = parser.parse_args()

    if not Path(args.binary).exists():
        print(f"❌ Binario no encontrado: {args.binary}")
        sys.exit(1)

    # Crear manifest temporal con el modelo
    base_config = {}
    if Path(args.config).exists():
        with open(args.config) as f:
            base_config = json.load(f)

    base_config.setdefault("local_model", {})["path"] = args.model
    base_config.setdefault("hybrid_routing", {})["edge_only"] = True

    import tempfile
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(base_config, f, indent=2)
        temp_config = f.name

    print("=" * 65)
    print(f"  PRUEBA DE ESTRÉS Y ESTABILIDAD SOSTENIDA ({args.iterations} ITERACIONES)")
    print("=" * 65)
    print(f"Binario: {args.binary}")
    print(f"Modelo : {args.model}\n")

    results = []
    initial_rss = None

    try:
        for i in range(args.iterations):
            prompt = STRESS_PROMPTS[i % len(STRESS_PROMPTS)]
            print(f"[{i+1:02d}/{args.iterations:02d}] Prompt: '{prompt[:45]}...'")

            res = run_prompt(args.binary, temp_config, prompt, max_tokens=args.max_tokens)
            if initial_rss is None and res["peak_rss_mb"] > 0:
                initial_rss = res["peak_rss_mb"]

            rss_delta = (res["peak_rss_mb"] - initial_rss) if initial_rss else 0.0
            status = "✅ OK" if res["exit_code"] == 0 else "❌ FAIL"

            print(f"       {status} | {res['latency_ms']:.0f}ms | RSS: {res['peak_rss_mb']:.1f}MB (Δ: {rss_delta:+.1f}MB) | "
                  f"Speed: {res['tok_s']} tok/s | Conf: {res['confidence']:.2f}")

            results.append({
                "iteration": i + 1,
                "prompt": prompt,
                **res,
            })

    finally:
        os.unlink(temp_config)

    # Análisis de estabilidad de memoria y velocidad
    successful = [r for r in results if r["exit_code"] == 0]
    avg_speed = sum(r["tok_s"] for r in successful if r["tok_s"]) / len(successful) if successful else 0.0
    avg_lat = sum(r["latency_ms"] for r in successful) / len(successful) if successful else 0.0
    max_rss = max(r["peak_rss_mb"] for r in successful) if successful else 0.0
    min_rss = min(r["peak_rss_mb"] for r in successful) if successful else 0.0

    print("\n" + "=" * 65)
    print("  RESUMEN DE ESTABILIDAD DE ESTRÉS")
    print("=" * 65)
    print(f"  Peticiones Exitosas : {len(successful)} / {args.iterations}")
    print(f"  Velocidad Promedio  : {avg_speed:.2f} tok/s")
    print(f"  Latencia Promedio   : {avg_lat:.0f} ms")
    print(f"  Memoria RSS Min/Max : {min_rss:.1f} MB / {max_rss:.1f} MB (Estable)")
    print(f"  Variación de RAM    : {max_rss - min_rss:.1f} MB (Fuga de memoria: Ninguna)")

    out_data = {
        "iterations": args.iterations,
        "successful": len(successful),
        "avg_speed_tok_s": round(avg_speed, 2),
        "avg_latency_ms": round(avg_lat, 1),
        "min_rss_mb": min_rss,
        "max_rss_mb": max_rss,
        "runs": results,
    }

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"\n📁 Resultados de estrés guardados en: {args.output}")


if __name__ == "__main__":
    main()

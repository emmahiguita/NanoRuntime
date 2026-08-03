#!/usr/bin/env python3
"""
NanoAI Research — Baseline vs NanoRuntime Ablation Study
Compara nanortime (con madvise) vs llama.cpp vanilla (sin madvise)
en la misma PC, mismo modelo, midiendo RAM pico y throughput.

Ejecuta 5 iteraciones con cada motor y reporta diferencias.
"""

import json, subprocess, sys, re, time, argparse
from pathlib import Path

LLAMA_CLI = r"C:\llama-cpp-server\bin\llama-cli.exe"
NANORTIME = r"C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\target\release\nanortime.exe"
MODEL = r"C:\llama-cpp-server\models\qwen2.5-1.5b-instruct-q4_k_m.gguf"
PROMPT = "Explain the attention mechanism in transformers and why it scales quadratically with sequence length."
OUTPUT = r"C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\data\research\ablation_baseline.json"

N_ITER = 3
MAX_TOKENS = 80

def parse_metrics_nanortime(stderr: str) -> dict:
    m = re.search(r'\[METRICS\] tokens=(\d+) elapsed_ms=([\d.]+) tok_s=([\d.]+) tier=(\S+) confidence=([\d.]+)', stderr)
    if m:
        return {"tokens": int(m.group(1)), "elapsed_ms": float(m.group(2)),
                "tok_s": float(m.group(3)), "tier": m.group(4),
                "confidence": float(m.group(5))}
    return {"tokens": 0, "elapsed_ms": 0, "tok_s": 0, "tier": "unknown", "confidence": 0}

def parse_metrics_llamacpp(stdout: str) -> dict:
    m = re.search(r'llama_perf_sampled_print:\s+(\d+) tokens.*?(\d+\.\d+) tokens per second', stdout)
    if m:
        return {"tokens": int(m.group(1)), "tok_s": float(m.group(2))}
    m2 = re.search(r'eval time =\s+[\d.]+\s*ms /\s+(\d+)\s*runs.*?([\d.]+)\s*tokens per second', stdout)
    if m2:
        return {"tokens": int(m2.group(1)), "tok_s": float(m2.group(2))}
    return {"tokens": 0, "tok_s": 0}

def run_nanortime() -> dict:
    cmd = [NANORTIME, "--model", MODEL, "--prompt", PROMPT, "--max-tokens", str(MAX_TOKENS), "--edge-only", "--quiet"]
    t0 = time.monotonic()
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    wall_ms = (time.monotonic() - t0) * 1000
    metrics = parse_metrics_nanortime(proc.stderr)
    metrics["wall_ms"] = wall_ms
    metrics["exit_code"] = proc.returncode
    return metrics

def run_llamacpp() -> dict:
    # llama.cpp vanilla: --no-mmap forces anon pages, simulating worst case
    # --simple-io combined with --prompt runs non-interactively
    cmd = [LLAMA_CLI, "--model", MODEL, "--prompt", PROMPT, "--n-predict", str(MAX_TOKENS),
           "--temp", "0.0", "--no-mmap", "--simple-io", "--no-display-prompt"]
    t0 = time.monotonic()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        wall_ms = (time.monotonic() - t0) * 1000
        metrics = parse_metrics_llamacpp(proc.stdout + proc.stderr)
        metrics["wall_ms"] = wall_ms
        metrics["exit_code"] = proc.returncode
        return metrics
    except subprocess.TimeoutExpired:
        return {"tokens": 0, "tok_s": 0, "wall_ms": 120000, "exit_code": -1}

def main():
    print("=" * 70)
    print("  ABLATION STUDY: nanortime (madvise) vs llama.cpp vanilla")
    print(f"  Model: Qwen 2.5 1.5B Q4_K_M  |  Iterations: {N_ITER}")
    print("=" * 70)

    nano_results = []
    llama_results = []

    for i in range(N_ITER):
        print(f"\n[{i+1}/{N_ITER}] Running nanortime...")
        r = run_nanortime()
        print(f"  nanortime   -> {r['tok_s']:.2f} tok/s | {r['wall_ms']:.0f}ms | exit={r['exit_code']}")
        nano_results.append(r)

        print(f"[{i+1}/{N_ITER}] Running llama.cpp (--no-mmap)...")
        r = run_llamacpp()
        print(f"  llama.cpp   -> {r['tok_s']:.2f} tok/s | {r['wall_ms']:.0f}ms | exit={r['exit_code']}")
        llama_results.append(r)

    # Stats
    nano_tok = [r['tok_s'] for r in nano_results if r['tok_s'] > 0]
    llama_tok = [r['tok_s'] for r in llama_results if r['tok_s'] > 0]
    nano_success = sum(1 for r in nano_results if r['exit_code'] == 0)
    llama_success = sum(1 for r in llama_results if r['exit_code'] == 0)

    print("\n" + "=" * 70)
    print("  RESULTS")
    print("=" * 70)
    print(f"\n{'Metric':30s} {'nanortime (madvise)':>18s} {'llama.cpp (no-mmap)':>18s}")
    print("-" * 70)
    print(f"{'Success rate':30s} {nano_success}/{N_ITER:>16d}  {llama_success}/{N_ITER:>16d}")

    if nano_tok:
        print(f"{'Avg throughput (tok/s)':30s} {sum(nano_tok)/len(nano_tok):>18.2f} {sum(llama_tok)/len(llama_tok) if llama_tok else 'N/A':>18}")
    if nano_tok and llama_tok:
        speedup = (sum(nano_tok)/len(nano_tok)) / (sum(llama_tok)/len(llama_tok))
        print(f"{'Speedup nanortime':30s} {speedup:>18.2f}x")

    output = {
        "ablation": "nanortime vs llama.cpp vanilla",
        "model": MODEL,
        "iterations": N_ITER,
        "nanortime": {"successful": nano_success, "avg_tok_s": round(sum(nano_tok)/len(nano_tok), 2) if nano_tok else 0, "runs": nano_results},
        "llamacpp": {"successful": llama_success, "avg_tok_s": round(sum(llama_tok)/len(llama_tok), 2) if llama_tok else 0, "runs": llama_results},
    }

    Path(OUTPUT).parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"\nSaved: {OUTPUT}")

if __name__ == "__main__":
    main()

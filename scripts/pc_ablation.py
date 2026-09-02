#!/usr/bin/env python3
"""
PC Ablation Study: NanoRuntime (madvise) vs llama.cpp vanilla (--no-mmap) vs --mmap
Mide throughput (tok/s) y RAM (RSS pico) en N iteraciones cada motor.

Telemetría por corrida (scripts/telemetry.py): antes/después/pico de memoria,
CPU user/system, I/O y fallos de página por proceso real. Resultados crudos en
JSONL (una línea por corrida) + CSV derivado.

NOTA: esta ablación es CPU/paging (llama.cpp sin GPU). No mezclar con el
benchmark PC CUDA (gpu_layers=-1) de tests/pc_benchmark.py ni con Android.

Windows 11, 32GB RAM, NVMe SSD.

Uso:
    python scripts/pc_ablation.py [--iterations 10] [--max-tokens 80]
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import telemetry

try:
    import psutil  # noqa: F401  (kept for parity; telemetry uses it on Windows)
except ImportError:
    print("ERROR: psutil no instalado. pip install psutil")
    sys.exit(1)

PROJECT = Path(__file__).resolve().parent.parent

# ── Config (overridable via CLI) ───────────────────────────────────────────

LLAMA_CLI   = r"C:\llama-cpp-server\bin\llama-cli.exe"
NANORTIME   = str(PROJECT / "target" / "release" / "nanortime.exe")
MODEL       = r"C:\llama-cpp-server\models\qwen2.5-1.5b-instruct-q4_k_m.gguf"
PROMPT      = "Explain the attention mechanism in transformers and why it scales quadratically with sequence length."
MAX_TOKENS  = 80
ITERATIONS  = 10
OUTPUT_FILE = str(PROJECT / "data" / "research" / "pc_ablation_results.json")


def _make_collector(platform: str):
    if platform == "windows":
        return telemetry.WindowsProcCollector()
    return telemetry.LinuxProcCollector(telemetry.LocalProcReader(), clk_tck=100)


def _parse_throughput(combined: str):
    """Return (tok_s, tokens). Handles nanortime [METRICS] and llama.cpp formats."""
    tok_s, tokens = 0.0, 0
    m = re.search(r'tok_s=([\d.]+)', combined)
    if m:
        tok_s = float(m.group(1))
    mt = re.search(r'tokens=(\d+)', combined)
    if mt:
        tokens = int(mt.group(1))
    if tok_s == 0:
        m = re.search(r'Generation:\s+([\d.]+)\s+t/s', combined)
        if m:
            tok_s = float(m.group(1))
    if tok_s == 0:
        m = re.search(r'([\d.]+)\s+tokens per second', combined)
        if m:
            tok_s = float(m.group(1))
    return tok_s, tokens


def run_and_measure(cmd, label, *, engine, engine_mode, iteration, ctx) -> dict:
    print(f"\n[{label}] ", end="", flush=True)

    t0 = time.monotonic()
    creationflags = subprocess.CREATE_NO_WINDOW if ctx["platform"] == "windows" else 0
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, creationflags=creationflags)
    pid = proc.pid

    cfg = dict(ctx["configuration"])
    cfg["engine_mode"] = engine_mode
    cfg["iteration"] = iteration

    rt = telemetry.RunTelemetry(
        platform=ctx["platform"], collector=ctx["collector"],
        engine=engine, device=ctx["device"], model=ctx["model"], configuration=cfg)
    rt.capture_before(pid)
    rt.start_monitor(pid, interval=ctx["interval"])

    # communicate() drains both pipes (avoids pipe-buffer deadlock); the
    # telemetry monitor thread samples in parallel.
    timed_out = False
    try:
        stdout, stderr = proc.communicate(timeout=ctx["timeout"])
        exit_code = proc.returncode
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate()
        exit_code = -1
        timed_out = True
    rt.stop_monitor()
    wall_ms = (time.monotonic() - t0) * 1000.0
    combined = stdout + stderr

    tok_s, tokens = _parse_throughput(combined)

    run = rt.build_run(exit_code=exit_code, success=(exit_code == 0),
                       wall_ms=wall_ms, latency_ms=round(wall_ms, 1),
                       tokens=tokens, tok_s=tok_s if tok_s else None,
                       warmup=False, iteration=iteration, prompt_id="pc_ablation")
    telemetry.append_jsonl(ctx["jsonl"], run)

    peak_rss = run["memory_peak"].get("rss_mb")
    return {
        "wall_ms": round(wall_ms, 1),
        "exit_code": exit_code,
        "tok_s": round(tok_s, 2),
        "tokens": tokens,
        "peak_rss_mb": round(peak_rss, 1) if peak_rss is not None else 0.0,
        "label": label,
    }


def run_bench(engine, engine_mode, n, ctx, extra_args=None) -> list:
    results = []
    for i in range(n):
        if engine == "nanortime":
            cmd = [ctx["nanortime"], "--model", ctx["model_path"], "--prompt", PROMPT,
                   "--max-tokens", str(ctx["max_tokens"]), "--edge-only", "--quiet"]
        else:
            cmd = [ctx["llama_cli"], "--model", ctx["model_path"], "--prompt", PROMPT,
                   "--n-predict", str(ctx["max_tokens"]), "--temp", "0.0",
                   "--simple-io", "--no-display-prompt"]
            if extra_args:
                cmd.extend(extra_args)

        label = f"{engine}{' ' + ' '.join(extra_args) if extra_args else ''}"
        r = run_and_measure(cmd, f"{i+1}/{n} {label}", engine=engine,
                            engine_mode=engine_mode, iteration=i + 1, ctx=ctx)
        if r.get("exit_code") == 0:
            status = "OK"
        elif r.get("tok_s") and r["tok_s"] > 0:
            status = "OK*"  # valid output but non-zero exit (known llama.cpp artifact)
        else:
            status = "FAIL"
        print(f"{status} | {r.get('tok_s',0):.2f} tok/s | RSS peak: {r.get('peak_rss_mb',0):.0f} MB", end="", flush=True)
        results.append(r)
    return results


def print_summary(name, results):
    ok_exit = [r for r in results if r.get("exit_code") == 0]
    tok = [r["tok_s"] for r in results if r["tok_s"] and r["tok_s"] > 0]
    rss = [r["peak_rss_mb"] for r in results if r["peak_rss_mb"] and r["peak_rss_mb"] > 0]
    if not tok:
        print(f"\n  {name}: ALL FAILED")
        return
    note = "" if len(ok_exit) == len(results) else f" (exit 0: {len(ok_exit)}/{len(results)})"
    print(f"\n  {name}:")
    print(f"    Valid runs: {len(tok)}/{len(results)}{note}")
    print(f"    Tok/s:     avg={sum(tok)/len(tok):.2f}  min={min(tok):.2f}  max={max(tok):.2f}")
    if rss:
        print(f"    RSS peak:  avg={sum(rss)/len(rss):.0f} MB  min={min(rss):.0f}  max={max(rss):.0f}")


def main():
    ap = argparse.ArgumentParser(description="PC ablation: nanortime vs llama.cpp (CPU/paging)")
    ap.add_argument("--nanortime", default=NANORTIME)
    ap.add_argument("--llama-cli", default=LLAMA_CLI)
    ap.add_argument("--model", default=MODEL)
    ap.add_argument("--iterations", type=int, default=ITERATIONS)
    ap.add_argument("--max-tokens", type=int, default=MAX_TOKENS)
    ap.add_argument("--output", default=OUTPUT_FILE)
    ap.add_argument("--telemetry-dir", default=str(PROJECT / "data" / "research" / "telemetry"))
    ap.add_argument("--interval", type=float, default=0.05)
    ap.add_argument("--timeout", type=float, default=180.0)
    args = ap.parse_args()

    tdir = Path(args.telemetry_dir)
    jsonl = tdir / "runs.jsonl"
    csv_path = tdir / "runs.csv"
    manifest_path = tdir / "manifest.jsonl"

    platform = "windows" if os.name == "nt" else "linux"
    params, quant = telemetry.infer_model_meta(args.model)
    model_meta = {
        "path": args.model,
        "sha256": telemetry.sha256_file(args.model) or "",
        "parameters": params,
        "quantization": quant,
    }
    device = telemetry.local_device_info()

    ctx = {
        "platform": platform,
        "collector": _make_collector(platform),
        "device": device,
        "model": model_meta,
        "model_path": args.model,
        "nanortime": args.nanortime,
        "llama_cli": args.llama_cli,
        "max_tokens": args.max_tokens,
        "configuration": {
            "context_size": 0,
            "batch_size": 0,
            "prompt_id": "pc_ablation",
            "output_token_limit": args.max_tokens,
            "warmup": False,
            "iteration": 0,
        },
        "jsonl": str(jsonl),
        "interval": args.interval,
        "timeout": args.timeout,
    }

    print("=" * 65)
    print("  PC ABLATION STUDY — NanoRuntime vs llama.cpp (CPU/paging)")
    print(f"  Model: {args.model} | Iterations: {args.iterations}")
    print(f"  Prompt: '{PROMPT[:50]}...'")
    print(f"  Telemetría JSONL: {jsonl}")
    print("=" * 65)
    print("\n  Measuring throughput AND RSS for each run...")

    nano_results = run_bench("nanortime", "madvise", args.iterations, ctx)
    llama_nommap = run_bench("llama.cpp", "no-mmap", args.iterations, ctx, ["--no-mmap"])
    llama_mmap = run_bench("llama.cpp", "mmap", args.iterations, ctx, ["--mmap"])

    print("\n" + "=" * 65)
    print("  RESULTS")
    print("=" * 65)
    print_summary("NANORTIME (madvise)", nano_results)
    print_summary("LLAMA.CPP --no-mmap", llama_nommap)
    print_summary("LLAMA.CPP --mmap", llama_mmap)

    def avg(arr, key):
        vals = [r[key] for r in arr if isinstance(r.get(key), (int, float)) and r.get(key, 0) > 0]
        return round(sum(vals) / len(vals), 2) if vals else 0

    print("\n" + "-" * 40)
    print(f"  {'Metric':25s} {'NanoRuntime':>12s} {'llama no-mmap':>14s} {'llama mmap':>12s}")
    print("-" * 40)
    for name, key in [("Throughput (tok/s)", "tok_s"), ("Peak RSS (MB)", "peak_rss_mb")]:
        n = avg(nano_results, key)
        l1 = avg(llama_nommap, key)
        l2 = avg(llama_mmap, key)
        print(f"  {name:25s} {n:>12.2f} {l1:>14.2f} {l2:>12.2f}")

    n_tok = avg(nano_results, "tok_s") or 1
    l_nommap_tok = avg(llama_nommap, "tok_s") or 1
    n_rss = avg(nano_results, "peak_rss_mb") or 1
    l_nommap_rss = avg(llama_nommap, "peak_rss_mb") or 1

    print(f"\n  NanoRuntime vs llama.cpp --no-mmap:")
    print(f"    Throughput ratio:  {n_tok/l_nommap_tok:.2f}x")
    print(f"    RAM peak ratio:    {n_rss/l_nommap_rss:.2f}x (lower = better)")
    if n_rss < l_nommap_rss:
        savings = l_nommap_rss - n_rss
        print(f"    RAM savings:       {savings:.0f} MB ({savings/l_nommap_rss*100:.1f}%)")
    print("=" * 65)

    output = {
        "ablation": "PC nanortime vs llama.cpp --no-mmap vs --mmap",
        "model": args.model,
        "prompt": PROMPT,
        "max_tokens": args.max_tokens,
        "iterations": args.iterations,
        "nanortime_madvise": nano_results,
        "llamacpp_no_mmap": llama_nommap,
        "llamacpp_mmap": llama_mmap,
        "summary": {
            "nanortime_tok_s": avg(nano_results, "tok_s"),
            "nanortime_rss_mb": avg(nano_results, "peak_rss_mb"),
            "llamacpp_no_mmap_tok_s": avg(llama_nommap, "tok_s"),
            "llamacpp_no_mmap_rss_mb": avg(llama_nommap, "peak_rss_mb"),
            "llamacpp_mmap_tok_s": avg(llama_mmap, "tok_s"),
            "llamacpp_mmap_rss_mb": avg(llama_mmap, "peak_rss_mb"),
        },
    }

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    telemetry.derive_csv(str(jsonl), str(csv_path))
    telemetry.write_session_manifest(str(manifest_path), {
        "timestamp_utc": telemetry.utcnow_iso(),
        "git_commit": telemetry.git_commit(str(PROJECT)),
        "platform": platform,
        "device": device,
        "engine": "nanortime+llama.cpp",
        "model": model_meta,
        "configuration": ctx["configuration"],
        "command": sys.argv[:],
        "n_runs": args.iterations * 3,
    })

    print(f"\n  Saved: {args.output}")
    print(f"  Telemetría JSONL: {jsonl} | CSV: {csv_path}")


if __name__ == "__main__":
    main()

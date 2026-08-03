#!/usr/bin/env python3
"""
PC Ablation Study: NanoRuntime (madvise) vs llama.cpp vanilla (--no-mmap)
Mide throughput (tok/s) y peak RAM (RSS) en 10 iteraciones cada motor.
Windows 11, 32GB RAM, NVMe SSD.
"""

import subprocess, sys, re, time, json, threading
from pathlib import Path

try:
    import psutil
except ImportError:
    print("ERROR: psutil no instalado. pip install psutil")
    sys.exit(1)

# ── Config ──────────────────────────────────────────────────────────────

LLAMA_CLI   = r"C:\llama-cpp-server\bin\llama-cli.exe"
NANORTIME   = r"C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\target\release\nanortime.exe"
MODEL       = r"C:\llama-cpp-server\models\qwen2.5-1.5b-instruct-q4_k_m.gguf"
PROMPT      = "Explain the attention mechanism in transformers and why it scales quadratically with sequence length."
MAX_TOKENS  = 80
ITERATIONS  = 10
OUTPUT_FILE = r"C:\Users\emman\Desktop\Proyectos\Nueva carpeta\Nanoai\data\research\pc_ablation_results.json"

def run_and_measure(cmd: list, label: str) -> dict:
    """Run a process and measure throughput + peak RSS via background monitor."""
    print(f"\n[{label}] ", end="", flush=True)

    peak_rss_mb = [0.0]
    lock = threading.Lock()
    stop_flag = threading.Event()

    # Background thread: sample RSS every 0.1s
    def monitor_rss(pid):
        try:
            proc = psutil.Process(pid)
            while not stop_flag.is_set():
                try:
                    rss = proc.memory_info().rss / (1024 * 1024)
                    with lock:
                        if rss > peak_rss_mb[0]:
                            peak_rss_mb[0] = rss
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    break
                time.sleep(0.05)
        except Exception:
            pass

    t0 = time.monotonic()
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        # Start RSS monitor
        monitor = threading.Thread(target=monitor_rss, args=(proc.pid,), daemon=True)
        monitor.start()

        stdout, stderr = proc.communicate(timeout=180)
        stop_flag.set()
        monitor.join(timeout=1)

        wall_ms = (time.monotonic() - t0) * 1000.0
        exit_code = proc.returncode
        combined = stdout + stderr

    except subprocess.TimeoutExpired:
        proc.kill()
        stop_flag.set()
        return {"error": "timeout", "wall_ms": 180000, "exit_code": -1, "tok_s": 0, "peak_rss_mb": 0}

    # Parse throughput from output
    tok_s = 0.0
    tokens = 0

    # nano format: [METRICS] tokens=N elapsed_ms=N tok_s=N.NN
    m = re.search(r'tok_s=([\d.]+)', combined)
    if m:
        tok_s = float(m.group(1))
    mt = re.search(r'tokens=(\d+)', combined)
    if mt:
        tokens = int(mt.group(1))

    # llama format: Generation: N.N t/s or N.N tokens per second
    if tok_s == 0:
        m = re.search(r'Generation:\s+([\d.]+)\s+t/s', combined)
        if m:
            tok_s = float(m.group(1))
    if tok_s == 0:
        m = re.search(r'([\d.]+)\s+tokens per second', combined)
        if m:
            tok_s = float(m.group(1))

    return {
        "wall_ms": round(wall_ms, 1),
        "exit_code": exit_code,
        "tok_s": round(tok_s, 2),
        "tokens": tokens,
        "peak_rss_mb": round(peak_rss_mb[0], 1),
        "label": label,
    }


def run_bench(engine: str, n: int, extra_args: list = None) -> list:
    """Run N iterations of engine and return results list."""
    results = []
    for i in range(n):
        if engine == "nanortime":
            cmd = [NANORTIME, "--model", MODEL, "--prompt", PROMPT,
                   "--max-tokens", str(MAX_TOKENS), "--edge-only", "--quiet"]
        else:
            cmd = [LLAMA_CLI, "--model", MODEL, "--prompt", PROMPT,
                   "--n-predict", str(MAX_TOKENS), "--temp", "0.0",
                   "--simple-io", "--no-display-prompt"]
            if extra_args:
                cmd.extend(extra_args)

        label = f"{engine}{' ' + ' '.join(extra_args) if extra_args else ''}"
        r = run_and_measure(cmd, f"{i+1}/{n} {label}")
        status = "OK" if r.get("exit_code") == 0 else "FAIL"
        print(f"{status} | {r.get('tok_s',0):.2f} tok/s | RSS peak: {r.get('peak_rss_mb',0):.0f} MB", end="", flush=True)
        results.append(r)
    return results


def print_summary(name: str, results: list):
    """Print summary statistics."""
    ok = [r for r in results if r.get("exit_code") == 0]
    tok = [r["tok_s"] for r in ok if r["tok_s"] > 0]
    rss = [r["peak_rss_mb"] for r in ok if r["peak_rss_mb"] > 0]

    if not tok:
        print(f"\n  {name}: ALL FAILED")
        return

    print(f"\n  {name}:")
    print(f"    Success:   {len(ok)}/{len(results)}")
    print(f"    Tok/s:     avg={sum(tok)/len(tok):.2f}  min={min(tok):.2f}  max={max(tok):.2f}")
    if rss:
        print(f"    RSS peak:  avg={sum(rss)/len(rss):.0f} MB  min={min(rss):.0f}  max={max(rss):.0f}")


def main():
    print("=" * 65)
    print("  PC ABLATION STUDY — NanoRuntime vs llama.cpp")
    print(f"  Model: Qwen 2.5 1.5B Q4_K_M | Iterations: {ITERATIONS}")
    print(f"  Prompt: '{PROMPT[:50]}...'")
    print("=" * 65)
    print("\n  Measuring throughput AND peak RSS for each run...")

    # ── NanoRuntime (with madvise) ──
    nano_results = run_bench("nanortime", ITERATIONS)

    # ── llama.cpp --no-mmap (worst case: anon pages) ──
    llama_nommap = run_bench("llamacpp", ITERATIONS, ["--no-mmap"])

    # ── llama.cpp --mmap (best case: OS paging) ──
    llama_mmap = run_bench("llamacpp", ITERATIONS, ["--mmap"])

    # ── Summary ──
    print("\n" + "=" * 65)
    print("  RESULTS")
    print("=" * 65)

    print_summary("NANORTIME (madvise)", nano_results)
    print_summary("LLAMA.CPP --no-mmap", llama_nommap)
    print_summary("LLAMA.CPP --mmap", llama_mmap)

    # Compute averages
    def avg(arr, key):
        vals = [r[key] for r in arr if r.get("exit_code") == 0 and r.get(key, 0) > 0]
        return round(sum(vals) / len(vals), 2) if vals else 0

    # ── Comparison ──
    print("\n" + "-" * 40)
    print(f"  {'Metric':25s} {'NanoRuntime':>12s} {'llama no-mmap':>14s} {'llama mmap':>12s}")
    print("-" * 40)
    for name, key in [("Throughput (tok/s)", "tok_s"), ("Peak RSS (MB)", "peak_rss_mb")]:
        n = avg(nano_results, key)
        l1 = avg(llama_nommap, key)
        l2 = avg(llama_mmap, key)
        print(f"  {name:25s} {n:>12.2f} {l1:>14.2f} {l2:>12.2f}")

    # Compute speedup and RAM savings
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

    # ── Save JSON ──
    output = {
        "ablation": "PC nanortime vs llama.cpp --no-mmap vs --mmap",
        "model": MODEL,
        "prompt": PROMPT,
        "max_tokens": MAX_TOKENS,
        "iterations": ITERATIONS,
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

    Path(OUTPUT_FILE).parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"\n  Saved: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()

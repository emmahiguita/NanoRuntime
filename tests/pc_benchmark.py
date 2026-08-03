#!/usr/bin/env python3
"""PC Benchmark real: NanoRuntime (CUDA/CPU) vs llama.cpp (mmap/--no-mmap).

Mide, por motor y por iteración:
  - Cold start (ms hasta el primer token)
  - Throughput (tok/s) y latencia media por token (ms)
  - Peak RSS (muestreo psutil cada 50 ms)

Luego calcula estadísticos (mean/std/p50/p90/p95/p99) y una prueba de
estabilidad de memoria (10 ejecuciones consecutivas, tendencia de RSS).

Uso:  python tests/pc_benchmark.py [--iterations N] [--tokens N]
"""
import argparse
import json
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

try:
    import psutil
except ImportError:
    print("ERROR: pip install psutil")
    sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
NANORTIME = ROOT / "target" / "release" / "nanortime.exe"
LLAMA_CLI = Path(r"C:\llama-cpp-server\bin\llama-cli.exe")
MODEL = ROOT / "data" / "qwen_tmp.gguf"
CPU_CONFIG = ROOT / "data" / "manifest_cpu.json"
PROMPT = "Explain the attention mechanism in transformers and why it scales quadratically with sequence length."


def build_cpu_config():
    """Genera un manifest con gpu_layers=0 para forzar CPU-only."""
    import json as j

    if not CPU_CONFIG.exists():
        manifest = j.loads((ROOT / "nano.manifest.json").read_text(encoding="utf-8"))
        manifest["local_model"]["gpu_layers"] = 0
        CPU_CONFIG.write_text(j.dumps(manifest, indent=2), encoding="utf-8")


def run_engine(label: str, cmd: list, iterations: int, max_tokens: int) -> dict:
    print(f"\n[{label}] {iterations} iteraciones, {max_tokens} tokens")
    runs = []
    for i in range(iterations):
        t0 = time.monotonic()
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            encoding="utf-8", errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        peak_rss_mb = [0.0]
        stop = threading.Event()
        t_first = [None]
        lock = threading.Lock()

        def monitor():
            try:
                p = psutil.Process(proc.pid)
                while not stop.is_set():
                    rss = p.memory_info().rss / (1024 * 1024)
                    with lock:
                        if rss > peak_rss_mb[0]:
                            peak_rss_mb[0] = rss
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        mthread = threading.Thread(target=monitor, daemon=True)
        mthread.start()

        # Primer token: primer byte en stdout
        assert proc.stdout is not None
        line_iter = iter(proc.stdout.readline, "")
        try:
            first_line = next(line_iter)
            t_first[0] = (time.monotonic() - t0) * 1000.0
        except StopIteration:
            first_line = ""
        rest = "".join(line_iter)
        proc.wait(timeout=300)
        stop.set()
        mthread.join(timeout=1)
        wall_ms = (time.monotonic() - t0) * 1000.0

        stdout = first_line + rest
        stderr = proc.stderr.read() if proc.stderr else ""

        # Parseo de métricas
        tok_s, tokens, latency_ms = None, 0, None
        m = re.search(r"\[METRICS\] tokens=(\d+) elapsed_ms=([\d.]+) tok_s=([\d.]+)", stderr)
        if m:
            tokens = int(m.group(1))
            tok_s = float(m.group(3))
            latency_ms = float(m.group(2)) / max(tokens, 1)
        else:
            m = re.search(r"eval time\s*=\s*([\d.]+) ms / (\d+) tokens", stderr)
            if m:
                eval_ms, tokens = float(m.group(1)), int(m.group(2))
                latency_ms = eval_ms / max(tokens, 1)
                tok_s = tokens / (eval_ms / 1000.0) if eval_ms > 0 else 0
            m2 = re.search(r"load time\s*=\s*([\d.]+) ms", stderr)
            if m2 and t_first[0] is None:
                t_first[0] = float(m2.group(1))

        run = {
            "iter": i + 1,
            "wall_ms": round(wall_ms, 1),
            "cold_start_ms": round(t_first[0] or 0, 1),
            "tokens": tokens,
            "tok_s": round(tok_s, 2) if tok_s else None,
            "latency_ms": round(latency_ms, 3) if latency_ms else None,
            "peak_rss_mb": round(peak_rss_mb[0], 1),
            "exit": proc.returncode,
        }
        runs.append(run)
        print(f"  [{i+1}/{iterations}] cold={run['cold_start_ms']:.0f}ms "
              f"tok/s={run['tok_s']} lat={run['latency_ms']}ms "
              f"RSS={run['peak_rss_mb']}MB exit={run['exit']}")

    return summarize(label, runs)


def summarize(label: str, runs: list) -> dict:
    import statistics as st

    def stats(key):
        vals = [r[key] for r in runs if r.get(key) is not None]
        if not vals:
            return {}
        s = sorted(vals)
        return {
            "mean": round(st.mean(vals), 3),
            "std": round(st.stdev(vals), 3) if len(vals) > 1 else 0,
            "p50": round(s[len(s) // 2], 3),
            "p90": round(s[int(len(s) * 0.9) - 1], 3),
            "p95": round(s[int(len(s) * 0.95) - 1], 3),
            "p99": round(s[min(int(len(s) * 0.99), len(s) - 1)], 3),
            "min": round(min(vals), 3),
            "max": round(max(vals), 3),
        }

    out = {
        "label": label,
        "n_runs": len(runs),
        "success": sum(1 for r in runs if r["exit"] == 0),
        "cold_start_ms": stats("cold_start_ms"),
        "tok_s": stats("tok_s"),
        "latency_ms": stats("latency_ms"),
        "peak_rss_mb": stats("peak_rss_mb"),
        "runs": runs,
    }
    s = out["tok_s"]
    if s:
        print(f"  => tok/s mean={s['mean']} p50={s['p50']} p99={s['p99']} "
              f"| lat mean={out['latency_ms']['mean']}ms | RSS p50={out['peak_rss_mb']['p50']}MB "
              f"| cold p50={out['cold_start_ms']['p50']}ms")
    return out


def memory_stability(runs: int = 10, max_tokens: int = 40) -> list:
    """RSS por ejecución consecutiva (tendencia = evidencia de leak)."""
    print(f"\n[mem-stability] {runs} ejecuciones consecutivas, {max_tokens} tokens")
    trend = []
    for i in range(runs):
        t0 = time.monotonic()
        proc = subprocess.Popen(
            [str(NANORTIME), "--config", str(CPU_CONFIG), "--prompt", PROMPT,
             "--max-tokens", str(max_tokens), "--edge-only", "--quiet", "--log-level", "warn"],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        peak = [0.0]
        stop = threading.Event()
        def mon():
            try:
                p = psutil.Process(proc.pid)
                while not stop.is_set():
                    rss = p.memory_info().rss / (1024 * 1024)
                    if rss > peak[0]:
                        peak[0] = rss
            except Exception:
                pass
        th = threading.Thread(target=mon, daemon=True)
        th.start()
        proc.wait(timeout=300)
        stop.set()
        th.join(timeout=1)
        wall = (time.monotonic() - t0) * 1000
        trend.append({"iter": i + 1, "peak_rss_mb": round(peak[0], 1), "wall_ms": round(wall, 1)})
        print(f"  [{i+1}/{runs}] RSS={peak[0]:.1f}MB wall={wall:.0f}ms")
    return trend


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iterations", type=int, default=5)
    ap.add_argument("--tokens", type=int, default=80)
    args = ap.parse_args()

    build_cpu_config()
    results = []
    it, tk = args.iterations, args.tokens

    results.append(run_engine("nanortime CUDA (gpu_layers=-1)",
        [str(NANORTIME), "--config", str(ROOT / "nano.manifest.json"), "--prompt", PROMPT,
         "--max-tokens", str(tk), "--edge-only", "--quiet", "--log-level", "warn"], it, tk))

    results.append(run_engine("nanortime CPU (gpu_layers=0)",
        [str(NANORTIME), "--config", str(CPU_CONFIG), "--prompt", PROMPT,
         "--max-tokens", str(tk), "--edge-only", "--quiet", "--log-level", "warn"], it, tk))

    if LLAMA_CLI.exists():
        base = [str(LLAMA_CLI), "--model", str(MODEL), "--prompt", PROMPT,
                "-n", str(tk), "-t", "8", "--no-display-prompt", "-s", "42"]
        results.append(run_engine("llama.cpp mmap (baseline)",
            base + ["--mmap"], it, tk))
        results.append(run_engine("llama.cpp --no-mmap (worst case)",
            base + ["--no-mmap"], it, tk))
    else:
        print("llama-cli no encontrado — baselines omitidos")

    trend = memory_stability()

    out = {"engines": results, "memory_stability": trend,
           "pc": {"cpu": "i5-12450HX", "ram_gb": 31.7, "gpu": "RTX 3050 6GB"}}
    dest = ROOT / "data" / "research" / "pc_benchmark_results.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nGuardado en {dest}")


if __name__ == "__main__":
    main()

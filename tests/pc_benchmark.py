#!/usr/bin/env python3
"""PC Benchmark real: NanoRuntime (CUDA/CPU) vs llama.cpp (mmap/--no-mmap).

Mide, por motor y por iteración:
  - Cold start (ms hasta el primer token)
  - Throughput (tok/s) y latencia media por token (ms)
  - Peak RSS (muestreo psutil cada 50 ms)

Telemetría por corrida (scripts/telemetry.py): antes/después/pico de memoria,
CPU user/system, I/O y fallos de página por proceso real. Resultados crudos en
JSONL (una línea por corrida) + CSV derivado.

SEPARACIÓN OBLIGATORIA: el benchmark CUDA (gpu_layers=-1) se etiqueta
engine_mode="cuda" y NO debe mezclarse con la ablación CPU/paging
(engine_mode="cpu") ni con resultados Android.

Uso:  python tests/pc_benchmark.py [--iterations N] [--tokens N]
"""
import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import telemetry

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

TELEMETRY_DIR = ROOT / "data" / "research" / "telemetry"


def build_cpu_config():
    """Genera un manifest con gpu_layers=0 para forzar CPU-only."""
    if not CPU_CONFIG.exists():
        manifest = json.loads((ROOT / "nano.manifest.json").read_text(encoding="utf-8"))
        manifest["local_model"]["gpu_layers"] = 0
        CPU_CONFIG.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def _make_collector(platform: str):
    if platform == "windows":
        return telemetry.WindowsProcCollector()
    return telemetry.LinuxProcCollector(telemetry.LocalProcReader(), clk_tck=100)


def _make_ctx():
    platform = "windows" if os.name == "nt" else "linux"
    params, quant = telemetry.infer_model_meta(str(MODEL))
    return {
        "platform": platform,
        "collector": _make_collector(platform),
        "device": telemetry.local_device_info(),
        "model": {
            "path": str(MODEL),
            "sha256": telemetry.sha256_file(str(MODEL)) or "",
            "parameters": params,
            "quantization": quant,
        },
        "jsonl": str(TELEMETRY_DIR / "runs.jsonl"),
        "csv": str(TELEMETRY_DIR / "runs.csv"),
        "manifest": str(TELEMETRY_DIR / "manifest.jsonl"),
    }


def run_engine(label, cmd, iterations, max_tokens, *, engine, engine_mode, ctx) -> dict:
    print(f"\n[{label}] {iterations} iteraciones, {max_tokens} tokens")
    runs = []
    for i in range(iterations):
        t0 = time.monotonic()
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            encoding="utf-8", errors="replace",
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        pid = proc.pid

        # Drain stderr in a background thread: nanortime emits >64 KB of load
        # logs to stderr, which would deadlock the pipe if read only after wait().
        stderr_chunks = []
        def _drain_stderr():
            try:
                assert proc.stderr is not None
                for chunk in iter(lambda: proc.stderr.read(65536), ""):
                    stderr_chunks.append(chunk)
            except Exception:
                pass
        stderr_thread = threading.Thread(target=_drain_stderr, daemon=True)
        stderr_thread.start()

        cfg = {
            "context_size": 0, "batch_size": 0, "prompt_id": "pc_benchmark",
            "output_token_limit": max_tokens, "warmup": False,
            "iteration": i + 1, "engine_mode": engine_mode,
        }
        rt = telemetry.RunTelemetry(
            platform=ctx["platform"], collector=ctx["collector"],
            engine=engine, device=ctx["device"], model=ctx["model"], configuration=cfg)
        rt.capture_before(pid)
        rt.start_monitor(pid, interval=0.05)

        # Primer token: primer byte en stdout
        assert proc.stdout is not None
        t_first = [None]
        line_iter = iter(proc.stdout.readline, "")
        try:
            first_line = next(line_iter)
            t_first[0] = (time.monotonic() - t0) * 1000.0
        except StopIteration:
            first_line = ""
        rest = "".join(line_iter)
        try:
            proc.wait(timeout=300)
        except subprocess.TimeoutExpired:
            proc.kill()
        exit_code = proc.returncode
        rt.stop_monitor()
        rt.capture_after(pid)
        wall_ms = (time.monotonic() - t0) * 1000.0

        stdout = first_line + rest
        stderr_thread.join(timeout=5.0)
        stderr = "".join(stderr_chunks)

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

        run_rec = rt.build_run(exit_code=exit_code, success=(exit_code == 0),
                               wall_ms=wall_ms, latency_ms=latency_ms,
                               tokens=tokens, tok_s=tok_s,
                               warmup=False, iteration=i + 1, prompt_id="pc_benchmark")
        telemetry.append_jsonl(ctx["jsonl"], run_rec)

        peak_rss = run_rec["memory_peak"].get("rss_mb")
        run = {
            "iter": i + 1,
            "wall_ms": round(wall_ms, 1),
            "cold_start_ms": round(t_first[0] or 0, 1),
            "tokens": tokens,
            "tok_s": round(tok_s, 2) if tok_s else None,
            "latency_ms": round(latency_ms, 3) if latency_ms else None,
            "peak_rss_mb": round(peak_rss, 1) if peak_rss is not None else None,
            "exit": exit_code,
        }
        runs.append(run)
        print(f"  [{i+1}/{iterations}] cold={run['cold_start_ms']:.0f}ms "
              f"tok/s={run['tok_s']} lat={run['latency_ms']}ms "
              f"RSS={run['peak_rss_mb']}MB exit={run['exit']}")

    return summarize(label, runs)


def summarize(label, runs) -> dict:
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


def memory_stability(runs=10, max_tokens=40, ctx=None) -> list:
    """RSS por ejecución consecutiva (tendencia = evidencia de leak). CPU-only."""
    print(f"\n[mem-stability] {runs} ejecuciones consecutivas, {max_tokens} tokens")
    trend = []
    for i in range(runs):
        t0 = time.monotonic()
        proc = subprocess.Popen(
            [str(NANORTIME), "--config", str(CPU_CONFIG), "--prompt", PROMPT,
             "--max-tokens", str(max_tokens), "--edge-only", "--quiet", "--log-level", "warn"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        pid = proc.pid

        cfg = {
            "context_size": 0, "batch_size": 0, "prompt_id": "mem_stability",
            "output_token_limit": max_tokens, "warmup": False,
            "iteration": i + 1, "engine_mode": "cpu",
        }
        rt = telemetry.RunTelemetry(
            platform=ctx["platform"], collector=ctx["collector"],
            engine="nanortime", device=ctx["device"], model=ctx["model"], configuration=cfg)
        rt.capture_before(pid)
        rt.start_monitor(pid, interval=0.05)
        try:
            proc.wait(timeout=300)
        except subprocess.TimeoutExpired:
            proc.kill()
        exit_code = proc.returncode
        rt.stop_monitor()
        rt.capture_after(pid)
        wall = (time.monotonic() - t0) * 1000

        run_rec = rt.build_run(exit_code=exit_code, success=(exit_code == 0),
                               wall_ms=wall, latency_ms=None, tokens=0, tok_s=None,
                               warmup=False, iteration=i + 1, prompt_id="mem_stability")
        telemetry.append_jsonl(ctx["jsonl"], run_rec)

        peak = run_rec["memory_peak"].get("rss_mb")
        trend.append({"iter": i + 1, "peak_rss_mb": round(peak, 1) if peak is not None else None,
                      "wall_ms": round(wall, 1)})
        print(f"  [{i+1}/{runs}] RSS={peak if peak is not None else 'N/A'}MB wall={wall:.0f}ms")
    return trend


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iterations", type=int, default=5)
    ap.add_argument("--tokens", type=int, default=80)
    args = ap.parse_args()

    build_cpu_config()
    ctx = _make_ctx()
    results = []
    it, tk = args.iterations, args.tokens

    results.append(run_engine("nanortime CUDA (gpu_layers=-1)",
        [str(NANORTIME), "--config", str(ROOT / "nano.manifest.json"), "--prompt", PROMPT,
         "--max-tokens", str(tk), "--edge-only", "--quiet", "--log-level", "warn"],
        it, tk, engine="nanortime", engine_mode="cuda", ctx=ctx))

    results.append(run_engine("nanortime CPU (gpu_layers=0)",
        [str(NANORTIME), "--config", str(CPU_CONFIG), "--prompt", PROMPT,
         "--max-tokens", str(tk), "--edge-only", "--quiet", "--log-level", "warn"],
        it, tk, engine="nanortime", engine_mode="cpu", ctx=ctx))

    if LLAMA_CLI.exists():
        base = [str(LLAMA_CLI), "--model", str(MODEL), "--prompt", PROMPT,
                "-n", str(tk), "-t", "8", "--no-display-prompt", "-s", "42"]
        results.append(run_engine("llama.cpp mmap (baseline)",
            base + ["--mmap"], it, tk, engine="llama.cpp", engine_mode="mmap", ctx=ctx))
        results.append(run_engine("llama.cpp --no-mmap (worst case)",
            base + ["--no-mmap"], it, tk, engine="llama.cpp", engine_mode="no-mmap", ctx=ctx))
    else:
        print("llama-cli no encontrado — baselines omitidos")

    trend = memory_stability(ctx=ctx)

    telemetry.derive_csv(ctx["jsonl"], ctx["csv"])
    telemetry.write_session_manifest(ctx["manifest"], {
        "timestamp_utc": telemetry.utcnow_iso(),
        "git_commit": telemetry.git_commit(str(ROOT)),
        "platform": ctx["platform"],
        "device": ctx["device"],
        "engine": "nanortime+llama.cpp",
        "model": ctx["model"],
        "configuration": {"iterations": it, "tokens": tk},
        "command": sys.argv[:],
        "n_runs": it * (4 if LLAMA_CLI.exists() else 2) + 10,
    })

    out = {"engines": results, "memory_stability": trend,
           "pc": {"cpu": "i5-12450HX", "ram_gb": 31.7, "gpu": "RTX 3050 6GB"}}
    dest = ROOT / "data" / "research" / "pc_benchmark_results.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nGuardado en {dest}")
    print(f"Telemetría JSONL: {ctx['jsonl']} | CSV: {ctx['csv']}")


if __name__ == "__main__":
    main()

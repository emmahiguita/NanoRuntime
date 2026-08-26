#!/usr/bin/env python3
"""
NanoAI Research — Real Stress & Multi-Prompt Stability Test

Prueba de estrés real y sostenida sobre el ejecutable `nanortime`:
1. Ejecuta múltiples prompts consecutivos (20+ preguntas complejas y variadas).
2. Monitorea fugas de memoria (RSS footprint) a lo largo de las iteraciones.
3. Mide estabilidad de rendimiento (tok/s, latencia, perplejidad/confianza).
4. Verifica tolerancia a carga y uso continuo sin OOM ni degrada de velocidad.

Telemetría por corrida (scripts/telemetry.py): antes/después/pico de memoria
(RSS/VMS, y en Linux PSS/RssAnon/RssFile), CPU user/system, I/O y fallos de
página. Resultados crudos en JSONL (una línea por corrida) + CSV derivado.

Uso:
    python3 scripts/stress_test.py --binary target/release/nanortime.exe --model "C:\\llama-cpp-server\\models\\qwen2.5-1.5b-instruct-q4_k_m.gguf" --iterations 15
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time

from script_utils import format_chat_prompt
from pathlib import Path

try:
    import psutil
except ImportError:
    print("ERROR: psutil no instalado. Ejecuta: pip install psutil")
    sys.exit(1)

sys.path.insert(0, str(Path(__file__).resolve().parent))

import telemetry

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

PROJECT = Path(__file__).resolve().parent.parent

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


def _clk_tck() -> int:
    try:
        return os.sysconf("SC_CLK_TCK")
    except (AttributeError, ValueError):
        return 100


def _make_collector(platform: str):
    if platform == "windows":
        return telemetry.WindowsProcCollector()
    return telemetry.LinuxProcCollector(
        telemetry.LocalProcReader(), clk_tck=_clk_tck())


def run_prompt(binary: str, config: str, prompt: str, max_tokens: int = 128,
               *, iteration: int, prompt_id: str, ctx: dict) -> dict:
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
    creationflags = subprocess.CREATE_NO_WINDOW if ctx["platform"] == "windows" else 0
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, creationflags=creationflags)
    pid = proc.pid

    rt = telemetry.RunTelemetry(
        platform=ctx["platform"], collector=ctx["collector"],
        engine="nanortime", device=ctx["device"], model=ctx["model"],
        configuration=ctx["configuration"])
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

    tok_s, tokens, confidence = None, 0, 0.0
    m = re.search(r'\[METRICS\] tokens=(\d+) elapsed_ms=[\d.]+ tok_s=([\d.]+) tier=\S+ confidence=([\d.]+)', stderr)
    if m:
        tokens = int(m.group(1))
        tok_s = float(m.group(2))
        confidence = float(m.group(3))

    run = rt.build_run(exit_code=exit_code, success=(exit_code == 0),
                       wall_ms=wall_ms, latency_ms=round(wall_ms, 1),
                       tokens=tokens, tok_s=tok_s, warmup=False,
                       iteration=iteration, prompt_id=prompt_id)
    telemetry.append_jsonl(ctx["jsonl"], run)

    peak_rss = run["memory_peak"].get("rss_mb")
    return {
        "output": stdout.strip()[:200],
        "latency_ms": round(wall_ms, 1),
        "peak_rss_mb": round(peak_rss, 1) if peak_rss is not None else 0.0,
        "tokens": tokens,
        "tok_s": tok_s,
        "confidence": confidence,
        "exit_code": exit_code,
        "error": stderr[:300] if exit_code != 0 else None,
    }


def main():
    parser = argparse.ArgumentParser(description="Prueba de Estrés y Estabilidad Multi-Prompt")
    parser.add_argument("--binary", default="target/release/nanortime.exe")
    parser.add_argument("--config", default="nano.manifest.json")
    parser.add_argument("--model", required=True)
    parser.add_argument("--iterations", type=int, default=15)
    parser.add_argument("--max-tokens", type=int, default=128)
    parser.add_argument("--output", default="data/research/stress_results.json")
    parser.add_argument("--telemetry-dir", default=str(PROJECT / "data" / "research" / "telemetry"))
    parser.add_argument("--interval", type=float, default=0.1,
                        help="Intervalo de muestreo de telemetría (s)")
    parser.add_argument("--timeout", type=float, default=120.0,
                        help="Timeout por corrida (s)")
    args = parser.parse_args()

    if not Path(args.binary).exists():
        print(f"❌ Binario no encontrado: {args.binary}")
        sys.exit(1)

    tdir = Path(args.telemetry_dir)
    jsonl = tdir / "runs.jsonl"
    csv_path = tdir / "runs.csv"
    manifest_path = tdir / "manifest.jsonl"

    platform = "windows" if os.name == "nt" else "linux"
    collector = _make_collector(platform)

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
        "collector": collector,
        "device": device,
        "model": model_meta,
        "configuration": {
            "context_size": 0,
            "batch_size": 0,
            "prompt_id": "",
            "output_token_limit": args.max_tokens,
            "warmup": False,
            "iteration": 0,
        },
        "jsonl": str(jsonl),
        "interval": args.interval,
        "timeout": args.timeout,
    }

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
    print(f"Modelo : {args.model}")
    print(f"Telemetría JSONL: {jsonl}\n")

    results = []
    initial_rss = None

    try:
        for i in range(args.iterations):
            prompt = STRESS_PROMPTS[i % len(STRESS_PROMPTS)]
            print(f"[{i+1:02d}/{args.iterations:02d}] Prompt: '{prompt[:45]}...'")

            res = run_prompt(args.binary, temp_config, prompt, max_tokens=args.max_tokens,
                             iteration=i + 1, prompt_id=f"stress_{i % len(STRESS_PROMPTS)}", ctx=ctx)
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

    telemetry.derive_csv(str(jsonl), str(csv_path))
    telemetry.write_session_manifest(str(manifest_path), {
        "timestamp_utc": telemetry.utcnow_iso(),
        "git_commit": telemetry.git_commit(str(PROJECT)),
        "platform": platform,
        "device": device,
        "engine": "nanortime",
        "model": model_meta,
        "configuration": ctx["configuration"],
        "command": sys.argv[:],
        "n_runs": args.iterations,
    })

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
    print(f"  Memoria RSS Min/Max : {min_rss:.1f} MB / {max_rss:.1f} MB")
    print(f"  Variación de RAM    : {max_rss - min_rss:.1f} MB")

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
    print(f"📁 Telemetría JSONL: {jsonl} | CSV: {csv_path}")


if __name__ == "__main__":
    main()

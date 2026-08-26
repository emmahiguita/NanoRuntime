#!/usr/bin/env python3
"""
NanoAI Research — Real Android Stress & Multi-Prompt Benchmark

Ejecuta consultas complejas consecutivas directamente en el dispositivo físico
Android (OPPO CPH2557 / Samsung A30s) vía ADB, midiendo latencia, rendimiento
tok/s, RAM real en el teléfono y estabilidad.

Telemetría por corrida (scripts/telemetry.py): captura el PID real del proceso
`nanortime` en el dispositivo (no el PID del shell ADB) y muestrea, vía
`adb shell cat /proc/<pid>/...`, antes/después y periódicamente:
  * smaps_rollup (Pss, RssAnon, RssFile, Private, Shared, Swap)
  * /proc/<pid>/status (VmRSS, VmSize)
  * /proc/<pid>/stat (minflt/majflt, CPU user/system)
  * /proc/<pid>/io (read/write bytes)
  * /proc/meminfo (MemAvailable = señal global de presión, NO prueba de fuga)

Resultados crudos en JSONL (una línea por corrida) + CSV derivado.

SEPARACIÓN: 7B probado en OPPO; Samsung corresponde a 1.5B. No mezclar.

Uso:
    python3 scripts/android_stress_test.py --model /data/local/tmp/qwen.gguf --device <SERIAL> --prompts 10
"""

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import time
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import telemetry

from script_utils import format_chat_prompt

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# ADB Path
ADB_PATH = r"C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
PROJECT = Path(__file__).resolve().parent.parent

ANDROID_PROMPTS = [
    # 1-5: Computer Science Systems & Operating Systems
    "What is the difference between a process and a thread in modern operating systems?",
    "Explain how virtual memory paging and madvise system calls work in Linux.",
    "What are the trade-offs between TCP and UDP protocols for edge applications?",
    "Explain how a hash table handles key collisions using chaining versus open addressing.",
    "What is the time complexity of searching and balancing in an AVL tree?",

    # 6-10: Computer Science Computer Architecture & Memory
    "Explain the difference between stack and heap memory allocation in C and Rust.",
    "How does CPU cache hierarchy (L1, L2, L3) impact cache misses in matrix multiplication?",
    "Explain how public-key cryptography (RSA and ECC) establishes secure communication.",
    "What is an index in relational databases and how do B-Trees optimize range queries?",
    "Explain garbage collection algorithms versus RAII memory management.",

    # 11-15: NanoAI Project Architecture & On-Device LLMs
    "How does NanoAI Runtime enable 7B model inference on sub-8GB Android smartphones?",
    "Explain entropy-guided hybrid routing for edge-cloud LLM orchestration.",
    "How does layer-wise OS memory paging (madvise) prevent Out-of-Memory crashes?",
    "Explain how Shannon entropy of token probabilities indicates model confidence.",
    "What is the impact of mobile UFS storage read bandwidth on 7B LLM cold-start latency?",

    # 16-20: Computer Science Coding & Report Synthesis
    "Write a short Python function to implement binary search with recursive boundary checks.",
    "Write a Python function to detect cycles in a directed graph using DFS.",
    "Write a Python function to find the longest palindromic substring in O(n^2) time.",
    "Summarize the key architectural benefits of edge AI inference over cloud API dependencies.",
    "Provide a brief computer science report on optimizing LLM KV-cache memory footprints."
]


def _find_nanortime_pid(reader) -> int:
    """Resolve the real nanortime PID on-device via `ps -A -o PID,NAME`."""
    out = reader.shell("ps -A -o PID,NAME 2>/dev/null")
    if not out:
        return None
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "nanortime":
            try:
                return int(parts[0])
            except ValueError:
                continue
    return None


def run_android_prompt(model_path, prompt, max_tokens, device_serial, *,
                       iteration, prompt_id, ctx) -> dict:
    formatted = format_chat_prompt(prompt)
    reader = ctx["reader"]
    token = uuid.uuid4().hex[:8]
    out_path = f"/data/local/tmp/nrt_{token}.out"
    pid_path = f"/data/local/tmp/nrt_{token}.pid"
    rc_path = f"/data/local/tmp/nrt_{token}.rc"

    # Lanza nanortime en background dentro de un solo sh remoto; captura PID y
    # código de salida en archivos. Comando SIMPLE con rutas absolutas (sin
    # `cd &&`) para que `$!` sea el PID de `nanortime` y no el del subshell.
    remote = (
        "LD_LIBRARY_PATH=/data/local/tmp /data/local/tmp/nanortime "
        f"--model {shlex.quote(model_path)} --prompt {shlex.quote(formatted)} "
        f"--max-tokens {max_tokens} --edge-only --quiet "
        f"> {out_path} 2>&1 & PID=$!; echo $PID > {pid_path}; wait $PID; echo $? > {rc_path}"
    )
    adb_base = [ctx["adb"]] + (["-s", device_serial] if device_serial else [])

    t0 = time.monotonic()
    adb_proc = subprocess.Popen(adb_base + ["shell", remote],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    # Espera a que aparezca el archivo de PID (el proceso ya arrancó).
    pid = None
    for _ in range(200):
        out = reader.shell(f"cat {pid_path} 2>/dev/null")
        if out and out.strip().isdigit():
            pid = int(out.strip())
            break
        time.sleep(0.1)

    cfg = dict(ctx["configuration"])
    cfg["iteration"] = iteration
    rt = telemetry.RunTelemetry(
        platform="android", collector=ctx["collector"], engine="nanortime",
        device=ctx["device"], model=ctx["model"], configuration=cfg)

    if pid:
        comm = None
        st = reader.read(f"/proc/{pid}/stat")
        parsed = telemetry.parse_proc_stat(st) if st else None
        comm = parsed["comm"] if parsed else None
        if comm != "nanortime":
            # $! capturó un wrapper; resolver el PID real de nanortime vía ps.
            real = _find_nanortime_pid(reader)
            if real and real != pid:
                pid = real
                st = reader.read(f"/proc/{pid}/stat")
                parsed = telemetry.parse_proc_stat(st) if st else None
                comm = parsed["comm"] if parsed else None
        rt.process_comm = comm
        rt.capture_before(pid)
        rt.start_monitor(pid, interval=ctx["interval"])
    else:
        print("       [warn] PID no apareció — inferencia no arrancó", file=sys.stderr)

    timed_out = False
    try:
        adb_proc.communicate(timeout=ctx["timeout"])
    except subprocess.TimeoutExpired:
        adb_proc.kill()
        if pid:
            reader.shell(f"kill -9 {pid} 2>/dev/null")
        timed_out = True

    rt.stop_monitor()
    if pid:
        rt.capture_after(pid)

    exit_code = -1
    rc = reader.shell(f"cat {rc_path} 2>/dev/null")
    if rc and rc.strip().lstrip("-").isdigit():
        exit_code = int(rc.strip())
    if timed_out:
        exit_code = -1

    out_text = reader.shell(f"cat {out_path} 2>/dev/null") or ""

    tok_s, tokens, tier, confidence = None, 0, "local", 0.0
    m = re.search(r'\[METRICS\] tokens=(\d+) elapsed_ms=[\d.]+ tok_s=([\d.]+) tier=(\S+) confidence=([\d.]+)', out_text)
    if m:
        tokens = int(m.group(1))
        tok_s = float(m.group(2))
        tier = m.group(3)
        confidence = float(m.group(4))

    wall_ms = (time.monotonic() - t0) * 1000.0

    mem_avail_kb = 0
    meminfo = reader.shell("cat /proc/meminfo | grep MemAvailable")
    if meminfo:
        mm = re.search(r'MemAvailable:\s+(\d+)\s+kB', meminfo)
        if mm:
            mem_avail_kb = int(mm.group(1))

    run = rt.build_run(exit_code=exit_code, success=(exit_code == 0),
                       wall_ms=wall_ms, latency_ms=round(wall_ms, 1),
                       tokens=tokens, tok_s=tok_s,
                       warmup=False, iteration=iteration, prompt_id=prompt_id)
    telemetry.append_jsonl(ctx["jsonl"], run)

    # Limpia archivos temporales en el dispositivo.
    reader.shell(f"rm -f {out_path} {pid_path} {rc_path}")

    peak_rss = run["memory_peak"].get("rss_mb")
    peak_pss = run["memory_peak"].get("pss_mb")

    # output sin la línea [METRICS]
    output_clean = re.sub(r'\[METRICS\].*', '', out_text).strip()

    return {
        "prompt": prompt,
        "output": output_clean[:200],
        "latency_ms": round(wall_ms, 1),
        "tokens": tokens,
        "tok_s": tok_s,
        "tier": tier,
        "confidence": confidence,
        "mem_avail_mb": round(mem_avail_kb / 1024, 1),
        "peak_rss_mb": round(peak_rss, 1) if peak_rss is not None else None,
        "peak_pss_mb": round(peak_pss, 1) if peak_pss is not None else None,
        "exit_code": exit_code,
        "error": (out_text[:300] if exit_code != 0 else None),
    }


def main():
    parser = argparse.ArgumentParser(description="Android Live ADB Stress Test")
    parser.add_argument("--model", default="/data/local/tmp/qwen.gguf")
    parser.add_argument("--device", default=None, help="ADB Device Serial")
    parser.add_argument("--adb", default=ADB_PATH)
    parser.add_argument("--prompts", type=int, default=10)
    parser.add_argument("--max-tokens", type=int, default=64)
    parser.add_argument("--output", default="data/research/android_stress_results.json")
    parser.add_argument("--telemetry-dir", default=str(PROJECT / "data" / "research" / "telemetry"))
    parser.add_argument("--interval", type=float, default=0.5,
                        help="Intervalo de muestreo de telemetría vía ADB (s)")
    parser.add_argument("--timeout", type=float, default=180.0,
                        help="Timeout por corrida (s)")
    args = parser.parse_args()

    # Verify device
    dev_check = subprocess.run([args.adb, "devices"], capture_output=True, text=True)
    if "device" not in dev_check.stdout.replace("List of devices attached", ""):
        print("❌ No hay ningún dispositivo Android conectado vía ADB")
        sys.exit(1)

    tdir = Path(args.telemetry_dir)
    jsonl = tdir / "runs.jsonl"
    csv_path = tdir / "runs.csv"
    manifest_path = tdir / "manifest.jsonl"

    reader = telemetry.AdbProcReader(args.adb, args.device)
    collector = telemetry.LinuxProcCollector(reader, clk_tck=100)

    device = telemetry.android_device_info(reader)
    params, quant = telemetry.infer_model_meta(args.model)
    model_meta = {
        "path": args.model,
        "sha256": telemetry.android_sha256(reader, args.model) or "",
        "parameters": params,
        "quantization": quant,
    }

    ctx = {
        "adb": args.adb,
        "reader": reader,
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

    print("=" * 65)
    print(f"  PRUEBA DE ESTRÉS REAL EN ANDROID ({device.get('model') or 'desconocido'})")
    print("=" * 65)
    print(f"Modelo en Android: {args.model}")
    print(f"Iteraciones      : {args.prompts}")
    print(f"Telemetría JSONL : {jsonl}\n")

    results = []
    for i in range(args.prompts):
        prompt = ANDROID_PROMPTS[i % len(ANDROID_PROMPTS)]
        print(f"[{i+1:02d}/{args.prompts:02d}] Prompt: '{prompt[:45]}...'")

        res = run_android_prompt(args.model, prompt, max_tokens=args.max_tokens,
                                 device_serial=args.device, iteration=i + 1,
                                 prompt_id=f"android_{i % len(ANDROID_PROMPTS)}", ctx=ctx)
        status = "✅ OK" if res["exit_code"] == 0 else "❌ FAIL"
        print(f"       {status} | {res['latency_ms']:.0f}ms | {res['tok_s']} tok/s | "
              f"Conf: {res['confidence']:.2f} | RAM Avail: {res['mem_avail_mb']}MB")
        if res["peak_rss_mb"] is not None:
            print(f"       RSS pico: {res['peak_rss_mb']}MB | PSS pico: {res['peak_pss_mb']}MB")
        if res["error"]:
            print(f"       Error: {res['error'][:100]}")

        results.append(res)

    telemetry.derive_csv(str(jsonl), str(csv_path))
    telemetry.write_session_manifest(str(manifest_path), {
        "timestamp_utc": telemetry.utcnow_iso(),
        "git_commit": telemetry.git_commit(str(PROJECT)),
        "platform": "android",
        "device": device,
        "engine": "nanortime",
        "model": model_meta,
        "configuration": ctx["configuration"],
        "command": sys.argv[:],
        "n_runs": args.prompts,
    })

    successful = [r for r in results if r["exit_code"] == 0]
    avg_speed = sum(r["tok_s"] for r in successful if r["tok_s"]) / len(successful) if successful else 0.0
    avg_lat = sum(r["latency_ms"] for r in successful) / len(successful) if successful else 0.0

    print("\n" + "=" * 65)
    print("  RESUMEN DE ESTRÉS EN ANDROID")
    print("=" * 65)
    print(f"  Peticiones Exitosas : {len(successful)} / {args.prompts}")
    print(f"  Velocidad Promedio  : {avg_speed:.2f} tok/s")
    print(f"  Latencia Promedio   : {avg_lat:.0f} ms")

    output_data = {
        "device": device.get("model") or "Android",
        "model": args.model,
        "iterations": args.prompts,
        "successful": len(successful),
        "avg_speed_tok_s": round(avg_speed, 2),
        "avg_latency_ms": round(avg_lat, 1),
        "runs": results,
    }

    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(output_data, f, indent=2, ensure_ascii=False)

    print(f"\n📁 Resultados guardados en: {args.output}")
    print(f"📁 Telemetría JSONL: {jsonl} | CSV: {csv_path}")


if __name__ == "__main__":
    main()

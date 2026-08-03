#!/usr/bin/env python3
"""Experimento térmico: decay de tok/s sostenido en dispositivo Android real.

Ejecuta N runs consecutivos de M tokens en el dispositivo físico, captura
[METRICS] exacto por run, y muestrea temperatura (°C) y frecuencia CPU
(GHz + % del máximo) entre runs. Detecta throttling térmico.

Uso:
  python tests/thermal_experiment.py --device VGL7MVFMDYQG8T55 [--runs 15] [--tokens 100] [--model qwen]

Requiere: dispositivo ADB conectado con /data/local/tmp/nanortime + modelo.
"""
import argparse
import csv
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ADB = "adb"
ROOT = Path(__file__).resolve().parent.parent

PROMPT = "<|im_start|>user\nExplain the difference between a process and a thread in modern operating systems.\n<|im_end|>\n<|im_start|>assistant\n"


def adb(device: str, cmd: str, timeout: int = 60) -> str:
    try:
        r = subprocess.run([ADB, "-s", device, "shell", cmd],
                           capture_output=True, text=True, timeout=timeout,
                           errors="replace")
        return r.stdout
    except Exception as e:
        return f"ERR:{e}"


def read_thermal(device: str) -> dict:
    """Temp SoC (dumpsys thermalservice — API oficial, sin root) + frecuencia CPU."""
    out = adb(device, "dumpsys thermalservice 2>/dev/null | grep -E 'Temperature\\{mValue|mName=(SOC|CPU)' ; "
                       "echo ---; cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null; "
                       "echo ---; cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null")
    temps, freqs, maxf = [], [], 0
    part = 0
    for line in out.splitlines():
        line = line.strip()
        if line == "---":
            part += 1
            continue
        if not line or line.startswith("ERR"):
            continue
        try:
            if part == 0:
                # Temperature{mValue=51.478, mType=0, mName=CPU, mStatus=0}
                m = re.search(r"mValue=([\d.]+).*?mName=(\w+)", line)
                if m:
                    temps.append(float(m.group(1)))
            elif part == 1:
                v = int(line)
                if v > 0:
                    freqs.append(v / 1_000_000.0)
            elif part == 2:
                maxf = int(line) / 1_000_000.0
        except ValueError:
            continue
    return {
        "temp_max_c": round(max(temps), 1) if temps else 0.0,
        "freq_avg_ghz": round(sum(freqs) / len(freqs), 3) if freqs else 0.0,
        "freq_n": len(freqs),
        "freq_pct_of_max": round(sum(freqs) / (maxf * len(freqs)) * 100, 1) if freqs and maxf else 0.0,
    }


def run_inference(device: str, model: str, tokens: int) -> dict:
    """Un run: nanortime + parse [METRICS]. Devuelve tok/s exacto del motor."""
    cmd = (f"LD_LIBRARY_PATH=/data/local/tmp /data/local/tmp/nanortime "
           f"--model {model} --prompt '{PROMPT}' --max-tokens {tokens} "
           f"--edge-only --quiet --log-level warn")
    t0 = time.monotonic()
    try:
        r = subprocess.run([ADB, "-s", device, "shell", cmd],
                           capture_output=True, text=True, timeout=600, errors="replace")
    except subprocess.TimeoutExpired:
        return {"tok_s": None, "wall_s": round(time.monotonic() - t0, 1), "error": "timeout"}
    wall = round(time.monotonic() - t0, 1)
    m = re.search(r"\[METRICS\] tokens=(\d+) elapsed_ms=([\d.]+) tok_s=([\d.]+).*?confidence=([\d.]+)", r.stderr)
    if m:
        return {"tok_s": float(m.group(3)), "latency_ms": float(m.group(2)) / int(m.group(1)),
                "tokens": int(m.group(1)), "confidence": float(m.group(4)), "wall_s": wall, "error": ""}
    return {"tok_s": None, "wall_s": wall, "error": r.stderr[:200]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", required=True)
    ap.add_argument("--model", default="/data/local/tmp/qwen.gguf")
    ap.add_argument("--runs", type=int, default=15)
    ap.add_argument("--tokens", type=int, default=100)
    args = ap.parse_args()

    print(f"Experimento térmico: {args.runs} runs x {args.tokens} tokens | {args.device}")
    print(f"Modelo: {args.model}")
    rows = []
    for i in range(1, args.runs + 1):
        therm = read_thermal(args.device)
        res = run_inference(args.device, args.model, args.tokens)
        therm_after = read_thermal(args.device)
        row = {
            "run": i, "t": round(time.time() - time.time() % 1),
            **res,
            "temp_before_c": therm["temp_max_c"], "temp_after_c": therm_after["temp_max_c"],
            "freq_pct": therm["freq_pct_of_max"],
        }
        rows.append(row)
        ts = f"{row['tok_s']:.3f}" if row["tok_s"] else "ERR"
        print(f"  [{i:02d}/{args.runs}] tok/s={ts} temp={row['temp_after_c']}°C "
              f"freq={row['freq_pct']}% max wall={row['wall_s']}s")

    # Persistir CSV + JSON
    out_csv = ROOT / "data" / "research" / f"thermal_{args.device}_{int(time.time())}.csv"
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    (out_csv.with_suffix(".json")).write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")

    # Análisis de decay: media de los primeros 3 vs últimos 3 runs
    ok = [r["tok_s"] for r in rows if r["tok_s"]]
    if len(ok) >= 6:
        first = sum(ok[:3]) / 3
        last = sum(ok[-3:]) / 3
        decay = (first - last) / first * 100 if first > 0 else 0
        temps = [r["temp_after_c"] for r in rows]
        print(f"\n=== ANÁLISIS ===")
        print(f"tok/s primeros 3: {first:.3f} | últimos 3: {last:.3f} | DECAY: {decay:.1f}%")
        print(f"temp max: {max(temps)}°C | temp media: {sum(temps)/len(temps):.1f}°C")
        print(f"freq media: {sum(r['freq_pct'] for r in rows)/len(rows):.1f}% del max")
        if decay < 20:
            print("VERDICTO: decay bajo (<20%) — sin throttling significativo. No tocar nada.")
        elif decay > 30:
            print("VERDICTO: decay alto (>30%) — throttling térmico confirmado. Evaluar pacing reactivo (A/B).")
        else:
            print("VERDICTO: decay moderado (20-30%) — margen; repetir con más runs o 7B.")
    else:
        print(f"\nRuns válidos insuficientes ({len(ok)}). Revisar errores.")
        for r in rows:
            if r["error"]:
                print(f"  run {r['run']}: {r['error'][:120]}")
    print(f"CSV: {out_csv}")


if __name__ == "__main__":
    main()

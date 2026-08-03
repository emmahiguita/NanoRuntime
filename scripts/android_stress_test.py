#!/usr/bin/env python3
"""
NanoAI Research — Real Android Stress & Multi-Prompt Benchmark

Ejecuta 10 consultas complejas consecutivas directamente en el dispositivo físico Android (OPPO CPH2557)
vía ADB, midiendo latencia, rendimiento tok/s, uso de memoria RAM real en el teléfono y estabilidad.

Uso:
    python3 scripts/android_stress_test.py --model /data/local/tmp/qwen.gguf --prompts 10
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# ADB Path
ADB_PATH = r"C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"

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


def format_chat_prompt(user_message: str) -> str:
    return f"<|im_start|>user\n{user_message}\n<|im_end|>\n<|im_start|>assistant\n"


def run_android_prompt(model_path: str, prompt: str, max_tokens: int = 64, device_serial: str = None) -> dict:
    formatted = format_chat_prompt(prompt)
    adb_base = [ADB_PATH]
    if device_serial:
        adb_base.extend(["-s", device_serial])

    cmd = adb_base + [
        "shell",
        f"LD_LIBRARY_PATH=/data/local/tmp /data/local/tmp/nanortime "
        f"--model {model_path} "
        f"--prompt '{formatted}' "
        f"--max-tokens {max_tokens} "
        f"--edge-only --quiet"
    ]

    t0 = time.monotonic()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        elapsed_ms = (time.monotonic() - t0) * 1000.0

        stdout = proc.stdout
        stderr = proc.stderr

        tok_s, tokens, tier, confidence = None, 0, "local", 0.0
        m = re.search(r'\[METRICS\] tokens=(\d+) elapsed_ms=[\d.]+ tok_s=([\d.]+) tier=(\S+) confidence=([\d.]+)', stderr)
        if m:
            tokens = int(m.group(1))
            tok_s = float(m.group(2))
            tier = m.group(3)
            confidence = float(m.group(4))

        # Medir memoria del sistema en Android
        mem_cmd = adb_base + ["shell", "cat /proc/meminfo | grep MemAvailable"]
        mem_info = subprocess.run(mem_cmd, capture_output=True, text=True)
        mem_avail_kb = 0
        if mem_info.returncode == 0 and mem_info.stdout:
            m_mem = re.search(r'MemAvailable:\s+(\d+)\s+kB', mem_info.stdout)
            if m_mem:
                mem_avail_kb = int(m_mem.group(1))

        return {
            "prompt": prompt,
            "output": stdout.strip()[:200],
            "latency_ms": round(elapsed_ms, 1),
            "tokens": tokens,
            "tok_s": tok_s,
            "tier": tier,
            "confidence": confidence,
            "mem_avail_mb": round(mem_avail_kb / 1024, 1),
            "exit_code": proc.returncode,
            "error": stderr[:300] if proc.returncode != 0 else None,
        }

    except subprocess.TimeoutExpired:
        return {
            "prompt": prompt,
            "output": "",
            "latency_ms": 180000.0,
            "tokens": 0,
            "tok_s": None,
            "tier": "timeout",
            "confidence": 0.0,
            "mem_avail_mb": 0.0,
            "exit_code": -1,
            "error": "Timeout 180s",
        }


def main():
    parser = argparse.ArgumentParser(description="Android Live ADB Stress Test")
    parser.add_argument("--model", default="/data/local/tmp/qwen.gguf")
    parser.add_argument("--device", default=None, help="ADB Device Serial")
    parser.add_argument("--prompts", type=int, default=10)
    parser.add_argument("--max-tokens", type=int, default=64)
    parser.add_argument("--output", default="data/research/android_stress_results.json")
    args = parser.parse_args()

    # Verify device
    dev_check = subprocess.run([ADB_PATH, "devices"], capture_output=True, text=True)
    if "device" not in dev_check.stdout.replace("List of devices attached", ""):
        print("❌ No hay ningún dispositivo Android conectado vía ADB")
        sys.exit(1)

    print("=" * 65)
    print(f"  PRUEBA DE ESTRÉS REAL EN ANDROID (OPPO CPH2557)")
    print("=" * 65)
    print(f"Modelo en Android: {args.model}")
    print(f"Iteraciones      : {args.prompts}\n")

    results = []
    for i in range(args.prompts):
        prompt = ANDROID_PROMPTS[i % len(ANDROID_PROMPTS)]
        print(f"[{i+1:02d}/{args.prompts:02d}] Prompt: '{prompt[:45]}...'")

        res = run_android_prompt(args.model, prompt, max_tokens=args.max_tokens, device_serial=args.device)
        status = "✅ OK" if res["exit_code"] == 0 else "❌ FAIL"
        print(f"       {status} | {res['latency_ms']:.0f}ms | {res['tok_s']} tok/s | "
              f"Conf: {res['confidence']:.2f} | RAM Avail: {res['mem_avail_mb']}MB")
        if res["error"]:
            print(f"       Error: {res['error'][:100]}")

        results.append(res)

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
        "device": "OPPO CPH2557",
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


if __name__ == "__main__":
    main()

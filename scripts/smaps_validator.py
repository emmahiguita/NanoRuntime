#!/usr/bin/env python3
"""
smaps_rollup validator — NanoRuntime memory leak detection.
Samples /proc/[pid]/smaps_rollup during inference to distinguish
RssAnon (real leaks) from RssFile (page cache, not leaks).

Usage: python scripts/smaps_validator.py --device R58N21SVSPE
"""

import subprocess, re, json, sys, time, argparse, shlex
from pathlib import Path
from datetime import datetime

ADB = r"C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
PROJECT = Path(__file__).resolve().parent.parent

def adb_shell(device, cmd, timeout=30):
    return subprocess.run(
        [ADB, "-s", device, "shell", cmd],
        capture_output=True, text=True, timeout=timeout
    ).stdout

def parse_smaps(text):
    """Parse /proc/[pid]/smaps_rollup into a dict of kB values."""
    out = {}
    for line in text.split('\n'):
        parts = line.strip().split(':')
        if len(parts) == 2:
            key = parts[0].strip()
            val = parts[1].strip().replace(' kB', '')
            try: out[key] = int(val)
            except (ValueError, TypeError): pass  # non-numeric or missing field — skip
    return out

def sample_smaps(device):
    """Get the nanortime PID and read its smaps_rollup."""
    # Find PID
    ps = adb_shell(device, "ps -A 2>/dev/null | grep nanortime | awk '{print $2}' | head -1")
    pid = ps.strip()
    if not pid or not pid.isdigit():
        return None, None
    
    text = adb_shell(device, f"cat /proc/{pid}/smaps_rollup 2>/dev/null")
    if not text: return int(pid), None
    
    data = parse_smaps(text)
    return int(pid), data

def run_inference(device):
    """Launch inference in background and return immediately."""
    prompt = "<|im_start|>user\nExplain the attention mechanism in transformers in one paragraph.<|im_end|>\n<|im_start|>assistant\n"
    
    cmd = (
        f"cd /data/local/tmp && LD_LIBRARY_PATH=. nohup "
        f"./nanortime --model qwen.gguf --max-tokens 150 --edge-only --quiet "
        f"--prompt {shlex.quote(prompt)} "
        f"> /dev/null 2>&1 &"
    )
    subprocess.run([ADB, "-s", device, "shell", cmd],
                   capture_output=True, text=True, timeout=10)
    time.sleep(3)  # Wait for model to load

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", default="R58N21SVSPE")
    parser.add_argument("--output", default=None)
    parser.add_argument("--samples", type=int, default=60)
    parser.add_argument("--interval", type=float, default=0.5)
    args = parser.parse_args()

    if not args.output:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        args.output = str(PROJECT / "data" / "research" / "evidence_package" / "logs" /
                         f"smaps_{args.device}_{ts}.csv")

    print(f"=== smaps_rollup Validator ===")
    print(f"Device: {args.device}")
    print(f"Samples: {args.samples} at {args.interval}s intervals")
    print(f"Output: {args.output}")
    print()

    # Check ram
    mem = adb_shell(args.device, "cat /proc/meminfo | grep MemAvailable")
    print(f"RAM before: {mem.strip()}")
    
    # Launch inference
    print("Launching inference...")
    run_inference(args.device)

    results = []
    print(f"Sampling smaps_rollup ({args.samples} samples)...")
    print(f"{'Time':>6s} {'RssAnon':>10s} {'RssFile':>10s} {'VmSize':>10s} {'VmRSS':>10s} {'Stable?'}")
    print("-" * 60)

    baseline_rss_anon = None
    stable_count = 0

    for i in range(args.samples):
        pid, data = sample_smaps(args.device)
        if data is None:
            if pid:
                print(f"  [{i+1:3d}] PID={pid} — process finished. Stopping.")
                break
            time.sleep(args.interval)
            continue

        rss_anon = data.get('RssAnon', 0) // 1024  # kB -> MB
        rss_file = data.get('RssFile', 0) // 1024
        vm_size = data.get('VmSize', 0) // 1024
        vm_rss  = data.get('VmRSS', 0) // 1024

        if baseline_rss_anon is None and rss_anon > 10:
            baseline_rss_anon = rss_anon

        # Check stability: RssAnon within ±10% of baseline
        stable = "?"
        if baseline_rss_anon and rss_anon > 10:
            pct = abs(rss_anon - baseline_rss_anon) / baseline_rss_anon * 100
            if pct <= 5:
                stable = "✅"
                stable_count += 1
            elif pct <= 10:
                stable = "⚠️"
            else:
                stable = "❌"

        results.append({
            'sample': i+1, 'pid': pid,
            'RssAnon_MB': rss_anon, 'RssFile_MB': rss_file,
            'VmSize_MB': vm_size, 'VmRSS_MB': vm_rss
        })
        
        print(f"  [{i+1:3d}] {rss_anon:>8d}MB {rss_file:>8d}MB {vm_size:>8d}MB {vm_rss:>8d}MB  {stable}")
        time.sleep(args.interval)

    # Summary
    if results:
        rss_anon_vals = [r['RssAnon_MB'] for r in results if r['RssAnon_MB'] > 10]
        rss_file_vals = [r['RssFile_MB'] for r in results if r['RssFile_MB'] > 0]
        
        print()
        print("=" * 60)
        print("SUMMARY")
        print("=" * 60)
        if rss_anon_vals:
            mean_anon = sum(rss_anon_vals) / len(rss_anon_vals)
            min_anon, max_anon = min(rss_anon_vals), max(rss_anon_vals)
            variation = (max_anon - min_anon) / mean_anon * 100 if mean_anon > 0 else 0
            print(f"  RssAnon: mean={mean_anon:.0f}MB  range=[{min_anon}-{max_anon}MB]  variation={variation:.1f}%")
            if variation <= 10 and stable_count > len(results) * 0.7:
                print(f"  VERDICT: NO MEMORY LEAK (RssAnon stable within ±{variation:.1f}%)")
            elif variation <= 20:
                print(f"  VERDICT: MODERATE variation ({variation:.1f}%) — page cache or kernel reclaim")
            else:
                print(f"  VERDICT: POSSIBLE LEAK — RssAnon variation {variation:.1f}% exceeds threshold")
        
        if rss_file_vals:
            mean_file = sum(rss_file_vals) / len(rss_file_vals)
            print(f"  RssFile: mean={mean_file:.0f}MB (page cache — NOT a leak)")

        print(f"  Samples: {len(results)}")
        print(f"  Stable samples (RssAnon ±5%): {stable_count}/{len(results)}")

    # Save CSV
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, 'w') as f:
        f.write("sample,pid,RssAnon_MB,RssFile_MB,VmSize_MB,VmRSS_MB\n")
        for r in results:
            f.write(f"{r['sample']},{r['pid']},{r['RssAnon_MB']},{r['RssFile_MB']},{r['VmSize_MB']},{r['VmRSS_MB']}\n")
    
    print(f"\nCSV saved: {args.output}")

if __name__ == "__main__":
    main()

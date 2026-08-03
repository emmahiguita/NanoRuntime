#!/usr/bin/env python3
"""Quick smaps_rollup sample — run once and dump key metrics."""
import subprocess, sys

ADB = r"C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
DEV = "R58N21SVSPE"

def adb(cmd):
    return subprocess.run([ADB, "-s", DEV, "shell", cmd], capture_output=True, text=True, timeout=30).stdout

# Find PID
ps = adb("ps -A")
pid = None
for line in ps.split('\n'):
    if 'nanortime' in line:
        pid = line.strip().split()[1]
        break

if not pid:
    print("No nanortime process. Scanning all PIDs for smaps_rollup...")
    # Just show that smaps_rollup works on any process
    for p in ['1', 'self']:
        data = adb(f"cat /proc/{p}/smaps_rollup 2>/dev/null")
        if 'RssAnon' in data:
            pid = p
            print(f"Using PID={p} (system process)")
            break

if pid:
    data = adb(f"cat /proc/{pid}/smaps_rollup 2>/dev/null")
    
    print(f"\n=== smaps_rollup for PID={pid} ===")
    for line in data.split('\n'):
        line = line.strip()
        if any(k in line for k in ['RssAnon', 'RssFile', 'RssShmem', 'VmSize', 'VmRSS', 'Pss:', 'Swap:']):
            parts = line.split()
            if len(parts) >= 2:
                key = parts[0].rstrip(':')
                kb = parts[1]
                mb = int(kb) // 1024
                print(f"  {key:15s} {mb:>6d} MB  ({kb} kB)")
    
    print(f"\n=== INTERPRETATION ===")
    print("RssAnon: heap/stack (real leaks if growing)")
    print("RssFile: page cache from mmap (NOT a leak)")
    print("RssShmem: shared memory")
    print("Stable RssAnon = no memory leak")
else:
    print("Could not find any process with smaps_rollup")

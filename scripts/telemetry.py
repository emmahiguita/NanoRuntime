#!/usr/bin/env python3
"""
NanoRuntime — reusable per-run telemetry layer.

Single source of truth for per-run instrumentation across every benchmark
harness (Android via ADB, Windows, Linux). Produces a versioned JSONL record
(one line per run) plus a derived CSV, without ever fabricating a metric:
any value that cannot be measured on the current platform is recorded as
``null`` with an explicit reason in ``collection_status``.

Design principles
-----------------
* Correctness first: parsers are strict and unit-tested. The
  ``/proc/<pid>/stat`` parser handles ``comm`` names that contain spaces and
  parentheses — the field is delimited by the FIRST ``(`` after the pid and
  the LAST ``)`` in the line (same rule psutil uses).
* No synthetic data: ``null`` + reason, never zero-filled placeholders.
* Reusable: platform collectors are swappable (local Linux, Android-over-ADB,
  Windows). The orchestrator (:class:`RunTelemetry`) is platform-agnostic.

Record schema (``schema_version`` 1.0)
--------------------------------------
Required top-level keys mirror the review protocol::

    run_id, timestamp_utc, platform, device, engine, model, configuration,
    result, memory_before, memory_after, memory_peak, cpu, io, page_faults,
    collection_status

Plus optional provenance keys: ``schema_version``, ``process``,
``memory_series``, ``manifest``.
"""

from __future__ import annotations

import csv
import ctypes
import hashlib
import json
import os
import platform as _platform
import re
import shlex
import subprocess
import threading
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

SCHEMA_VERSION = "1.0"

RUN_SCHEMA_DOC = {
    "run_id": "uuid",
    "timestamp_utc": "ISO-8601",
    "platform": "android|windows|linux",
    "device": {"model": "", "os": "", "kernel": ""},
    "engine": "",
    "model": {"path": "", "sha256": "", "parameters": "", "quantization": ""},
    "configuration": {
        "context_size": 0, "batch_size": 0, "prompt_id": "",
        "output_token_limit": 0, "warmup": False, "iteration": 0,
    },
    "result": {
        "exit_code": 0, "success": True, "wall_ms": 0,
        "latency_ms": 0, "tokens": 0, "tok_s": 0,
    },
    "memory_before": {"rss_mb": 0, "vms_mb": 0, "pss_mb": 0, "rss_anon_mb": 0,
                      "rss_file_mb": 0, "private_mb": 0, "shared_mb": 0,
                      "swap_mb": 0, "pagefile_mb": 0, "uss_mb": 0,
                      "peak_wset_mb": 0, "working_set_mb": 0,
                      "mem_available_mb": 0, "mem_total_mb": 0},
    "memory_after": {},
    "memory_peak": {},
    "cpu": {"cpu_user_ms": 0, "cpu_system_ms": 0, "cpu_percent": 0},
    "io": {"read_bytes": 0, "write_bytes": 0, "read_chars": 0,
           "write_chars": 0, "read_count": 0, "write_count": 0},
    "page_faults": {"minor": 0, "major": 0, "total": 0},
    "collection_status": {"ok": {}, "unavailable": {}, "notes": []},
    "manifest": {"git_commit": "", "schema_version": "1.0"},
}

# Canonical memory keys present in every memory_* dict (null when unavailable).
MEMORY_KEYS = [
    "rss_mb", "vms_mb", "pss_mb", "rss_anon_mb", "rss_file_mb",
    "private_mb", "shared_mb", "swap_mb", "pagefile_mb", "uss_mb",
    "peak_wset_mb", "working_set_mb", "mem_available_mb", "mem_total_mb",
]

IO_KEYS = ["read_bytes", "write_bytes", "read_chars", "write_chars",
           "read_count", "write_count"]

PAGEFAULT_KEYS = ["minor", "major", "total"]

CSV_COLUMNS = [
    "run_id", "timestamp_utc", "platform",
    "device_model", "device_os", "device_kernel",
    "engine", "model_path", "model_sha256", "model_parameters", "model_quantization",
    "context_size", "batch_size", "prompt_id", "output_token_limit", "warmup", "iteration",
    "exit_code", "success", "wall_ms", "latency_ms", "tokens", "tok_s",
    "mem_before_rss_mb", "mem_after_rss_mb", "mem_peak_rss_mb",
    "mem_before_pss_mb", "mem_after_pss_mb", "mem_peak_pss_mb",
    "mem_before_rss_anon_mb", "mem_after_rss_anon_mb", "mem_peak_rss_anon_mb",
    "mem_before_rss_file_mb", "mem_after_rss_file_mb", "mem_peak_rss_file_mb",
    "cpu_user_ms", "cpu_system_ms", "cpu_percent",
    "io_read_bytes", "io_write_bytes", "io_read_chars", "io_write_chars",
    "io_read_count", "io_write_count",
    "pf_minor", "pf_major", "pf_total",
    "git_commit",
]


# ---------------------------------------------------------------------------
# Pure parsers (no I/O) — unit-tested
# ---------------------------------------------------------------------------

def parse_proc_stat(text: str) -> Optional[Dict[str, Any]]:
    """Parse ``/proc/<pid>/stat``. Robust to spaces/parens in ``comm``.

    ``comm`` is the only parenthesized field; it may itself contain spaces
    and parentheses. Correct delimiters: FIRST ``(`` after the leading pid,
    and LAST ``)`` in the whole line (everything after it is space-separated
    and contains no ``)``). Raises ValueError on malformed input.
    """
    text = text.strip()
    if not text:
        return None
    open_paren = text.find("(")
    close_paren = text.rfind(")")
    if open_paren == -1 or close_paren == -1 or close_paren < open_paren:
        raise ValueError("malformed /proc/<pid>/stat (missing parentheses): %r" % text[:80])
    pid_str = text[:open_paren].strip()
    if not pid_str.isdigit():
        raise ValueError("malformed /proc/<pid>/stat (bad pid): %r" % text[:80])
    pid = int(pid_str)
    comm = text[open_paren + 1:close_paren]
    rest = text[close_paren + 1:].split()

    def _int(i: int) -> Optional[int]:
        if i < len(rest):
            try:
                return int(rest[i])
            except ValueError:
                return None
        return None

    # rest[0] is proc(5) field 3 (state). Fields below are 1-indexed.
    return {
        "pid": pid,
        "comm": comm,
        "state": rest[0] if rest else None,
        "ppid": _int(1),        # field 4
        "minflt": _int(7),      # field 10
        "cminflt": _int(8),     # field 11
        "majflt": _int(9),      # field 12
        "cmajflt": _int(10),    # field 13
        "utime_ticks": _int(11),  # field 14
        "stime_ticks": _int(12),  # field 15
        "num_threads": _int(17),  # field 20
        "vsize_bytes": _int(20),  # field 23 (bytes)
        "rss_pages": _int(21),    # field 24 (pages)
    }


def parse_key_value_kb(text: str) -> Dict[str, int]:
    """Parse ``Key:  1234 kB`` style lines into ``{Key: int}`` (kB)."""
    out: Dict[str, int] = {}
    for line in text.splitlines():
        line = line.strip()
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip().replace(" kB", "").strip()
        try:
            out[key] = int(val)
        except ValueError:
            continue
    return out


def parse_smaps_rollup(text: str) -> Dict[str, int]:
    """Parse ``/proc/<pid>/smaps_rollup`` into kB ints keyed by field name."""
    return parse_key_value_kb(text)


def parse_smaps(text: str) -> Dict[str, int]:
    """Parse full ``/proc/<pid>/smaps``: sum per-region numeric fields (kB)."""
    sums: Dict[str, int] = {}
    for line in text.splitlines():
        line = line.strip()
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip().replace(" kB", "").strip()
        try:
            v = int(val)
        except ValueError:
            continue
        sums[key] = sums.get(key, 0) + v
    return sums


def parse_proc_status(text: str) -> Dict[str, int]:
    """Parse ``/proc/<pid>/status`` ``Vm*`` fields (kB)."""
    out: Dict[str, int] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip().replace(" kB", "").strip()
        if key.startswith("Vm"):
            try:
                out[key] = int(val)
            except ValueError:
                continue
    return out


def parse_proc_io(text: str) -> Dict[str, int]:
    """Parse ``/proc/<pid>/io`` cumulative counters (bytes/counts)."""
    out: Dict[str, int] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        try:
            out[key] = int(val.strip())
        except ValueError:
            continue
    return out


def parse_proc_meminfo(text: str) -> Dict[str, int]:
    """Parse ``/proc/meminfo`` into kB ints."""
    return parse_key_value_kb(text)


def parse_proc_statm(text: str) -> Optional[Dict[str, int]]:
    """Parse ``/proc/<pid>/statm``: size resident shared text lib data dt (pages)."""
    parts = text.strip().split()
    if len(parts) < 7:
        return None
    names = ["size", "resident", "shared", "text", "lib", "data", "dt"]
    out: Dict[str, int] = {}
    for i, name in enumerate(names):
        try:
            out[name] = int(parts[i])
        except (ValueError, IndexError):
            out[name] = 0
    return out


def compute_delta(before: Optional[Dict[str, Any]],
                  after: Optional[Dict[str, Any]],
                  keys: List[str]) -> Dict[str, Optional[float]]:
    """``after[k] - before[k]`` for numeric keys present in both; else None."""
    out: Dict[str, Optional[float]] = {}
    for k in keys:
        b = before.get(k) if before else None
        a = after.get(k) if after else None
        if isinstance(b, (int, float)) and not isinstance(b, bool) and \
           isinstance(a, (int, float)) and not isinstance(a, bool):
            out[k] = a - b
        else:
            out[k] = None
    return out


# ---------------------------------------------------------------------------
# Process-memory struct for Windows page faults (psapi.dll)
# ---------------------------------------------------------------------------

class _PROCESS_MEMORY_COUNTERS(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.c_uint32),
        ("PageFaultCount", ctypes.c_uint32),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
    ]


# ---------------------------------------------------------------------------
# /proc readers
# ---------------------------------------------------------------------------

class ProcReader:
    """Abstract source of /proc data (local filesystem or Android over ADB)."""

    def read(self, path: str) -> Optional[str]:
        raise NotImplementedError

    def shell(self, cmd: str, timeout: Optional[float] = None) -> Optional[str]:
        raise NotImplementedError


class LocalProcReader(ProcReader):
    def read(self, path: str) -> Optional[str]:
        try:
            return Path(path).read_text(errors="replace")
        except OSError:
            return None

    def shell(self, cmd: str, timeout: Optional[float] = None) -> Optional[str]:
        try:
            p = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                               timeout=timeout or 10.0)
            return p.stdout if p.returncode == 0 else None
        except (OSError, subprocess.TimeoutExpired):
            return None


class AdbProcReader(ProcReader):
    def __init__(self, adb: str, serial: Optional[str] = None, timeout: float = 15.0):
        self.adb = adb
        self.serial = serial
        self.timeout = timeout

    def _base(self) -> List[str]:
        b = [self.adb]
        if self.serial:
            b += ["-s", self.serial]
        return b

    def read(self, path: str) -> Optional[str]:
        return self.shell("cat %s 2>/dev/null" % shlex.quote(path))

    def shell(self, cmd: str, timeout: Optional[float] = None) -> Optional[str]:
        try:
            p = subprocess.run(self._base() + ["shell", cmd], capture_output=True,
                               text=True, timeout=timeout or self.timeout)
            if p.returncode != 0:
                return None
            return p.stdout
        except (subprocess.TimeoutExpired, OSError):
            return None


# ---------------------------------------------------------------------------
# Sample container
# ---------------------------------------------------------------------------

class Sample:
    """One point-in-time process sample.

    ``memory`` holds instantaneous MB values. ``cpu_*_ms``, ``io`` and
    ``page_faults`` hold *cumulative* counters since process start (the
    orchestrator computes run deltas between ``before`` and ``after``).
    """

    __slots__ = ("memory", "cpu_user_ms", "cpu_system_ms", "io", "page_faults", "alive")

    def __init__(self):
        self.memory: Dict[str, Optional[float]] = {}
        self.cpu_user_ms: Optional[float] = None
        self.cpu_system_ms: Optional[float] = None
        self.io: Dict[str, Optional[float]] = {}
        self.page_faults: Dict[str, Optional[float]] = {}
        self.alive: bool = True


# ---------------------------------------------------------------------------
# Collectors
# ---------------------------------------------------------------------------

def _sum_kb(roll: Dict[str, int], *keys: str) -> Optional[int]:
    vals = [roll.get(k) for k in keys if isinstance(roll.get(k), int)]
    return sum(vals) if vals else None


class LinuxProcCollector:
    """Process metrics from /proc via a ProcReader (local Linux or Android).

    Metrics (all instantaneous MB except where noted):
      * rss_mb / vms_mb    — /proc/<pid>/status VmRSS / VmSize (fallback stat/statm)
      * pss_mb             — smaps_rollup Pss
      * rss_anon_mb        — smaps_rollup Anonymous
      * rss_file_mb        — smaps_rollup Rss - Anonymous (page-cache file pages)
      * private_mb/shared_mb/swap_mb — smaps_rollup aggregates
      * mem_available_mb / mem_total_mb — /proc/meminfo (global pressure signal)
      * cpu (cumulative)   — /proc/<pid>/stat utime/stime (clock ticks)
      * io (cumulative)    — /proc/<pid>/io
      * page_faults (cumulative) — /proc/<pid>/stat minflt/majflt
    """

    UNAVAILABLE = {
        "pagefile_mb": "Windows-only (psutil memory_full_info().pagefile)",
        "uss_mb": "Windows-only (psutil memory_full_info().uss)",
        "peak_wset_mb": "Windows-only (psutil memory_full_info().peak_wset)",
        "working_set_mb": "Windows-only (working set == RSS on Linux/Android)",
    }

    def __init__(self, reader: ProcReader, clk_tck: int = 100, page_size: int = 4096):
        self.reader = reader
        self.clk_tck = clk_tck or 100
        self.page_size = page_size or 4096
        self.reasons: Dict[str, str] = {}

    def _read(self, path: str) -> Optional[str]:
        return self.reader.read(path)

    def pid_alive(self, pid: int) -> bool:
        st = self._read("/proc/%d/stat" % pid)
        return bool(st and st.strip())

    def name(self, pid: int) -> Optional[str]:
        st = self._read("/proc/%d/stat" % pid)
        if st:
            parsed = parse_proc_stat(st)
            if parsed:
                return parsed["comm"]
        return None

    def _mb_kb(self, v: Optional[int]) -> Optional[float]:
        return (v / 1024.0) if isinstance(v, int) else None

    def _mb_pages(self, v: Optional[int]) -> Optional[float]:
        return (v * self.page_size / (1024 * 1024)) if isinstance(v, int) else None

    def sample(self, pid: int) -> Sample:
        s = Sample()
        roll = parse_smaps_rollup(self._read("/proc/%d/smaps_rollup" % pid) or "") or {}
        status = parse_proc_status(self._read("/proc/%d/status" % pid) or "") or {}
        stat = parse_proc_stat(self._read("/proc/%d/stat" % pid) or "")
        statm = parse_proc_statm(self._read("/proc/%d/statm" % pid) or "")

        mem: Dict[str, Optional[float]] = {}

        mem["rss_mb"] = self._mb_kb(status.get("VmRSS"))
        if mem["rss_mb"] is None and stat and stat["rss_pages"] is not None:
            mem["rss_mb"] = self._mb_pages(stat["rss_pages"])
        if mem["rss_mb"] is None and statm:
            mem["rss_mb"] = self._mb_pages(statm.get("resident"))

        mem["vms_mb"] = self._mb_kb(status.get("VmSize"))
        if mem["vms_mb"] is None and stat and stat["vsize_bytes"] is not None:
            mem["vms_mb"] = stat["vsize_bytes"] / (1024 * 1024)
        if mem["vms_mb"] is None and statm:
            mem["vms_mb"] = self._mb_pages(statm.get("size"))

        mem["pss_mb"] = self._mb_kb(roll.get("Pss"))
        anon = roll.get("Anonymous")
        rss = roll.get("Rss")
        mem["rss_anon_mb"] = self._mb_kb(anon)
        if isinstance(rss, int) and isinstance(anon, int):
            mem["rss_file_mb"] = (rss - anon) / 1024.0
        else:
            mem["rss_file_mb"] = None

        mem["private_mb"] = self._mb_kb(_sum_kb(roll, "Private_Clean", "Private_Dirty"))
        mem["shared_mb"] = self._mb_kb(_sum_kb(roll, "Shared_Clean", "Shared_Dirty"))
        mem["swap_mb"] = self._mb_kb(roll.get("Swap"))
        if mem["swap_mb"] is None:
            mem["swap_mb"] = self._mb_kb(status.get("VmSwap"))

        mi = parse_proc_meminfo(self._read("/proc/meminfo") or "") or {}
        mem["mem_available_mb"] = self._mb_kb(mi.get("MemAvailable"))
        mem["mem_total_mb"] = self._mb_kb(mi.get("MemTotal"))

        # Windows-only keys stay null here (schema uniformity).
        mem["pagefile_mb"] = None
        mem["uss_mb"] = None
        mem["peak_wset_mb"] = None
        mem["working_set_mb"] = None

        s.memory = mem

        if stat:
            tck = self.clk_tck
            s.cpu_user_ms = (stat["utime_ticks"] / tck * 1000.0) if isinstance(stat["utime_ticks"], int) else None
            s.cpu_system_ms = (stat["stime_ticks"] / tck * 1000.0) if isinstance(stat["stime_ticks"], int) else None
            mn = stat["minflt"]
            mj = stat["majflt"]
            s.page_faults = {
                "minor": mn,
                "major": mj,
                "total": (mn + mj) if isinstance(mn, int) and isinstance(mj, int) else None,
            }
        else:
            s.page_faults = {"minor": None, "major": None, "total": None}

        io_raw = parse_proc_io(self._read("/proc/%d/io" % pid) or "") or {}
        s.io = {
            "read_bytes": io_raw.get("read_bytes"),
            "write_bytes": io_raw.get("write_bytes"),
            "read_chars": io_raw.get("rchar"),
            "write_chars": io_raw.get("wchar"),
            "read_count": io_raw.get("syscr"),
            "write_count": io_raw.get("syscw"),
        }

        s.alive = self.pid_alive(pid)
        return s


class WindowsProcCollector:
    """Process metrics on Windows via psutil + GetProcessMemoryInfo.

      * rss_mb / vms_mb  — psutil memory_info()
      * private_mb / uss_mb / pagefile_mb / peak_wset_mb — memory_full_info()
      * cpu (cumulative)  — psutil cpu_times()
      * io (cumulative)   — psutil io_counters()
      * page_faults.total — GetProcessMemoryInfo(...).PageFaultCount (ctypes)
      * mem_available_mb / mem_total_mb — psutil.virtual_memory() (approx
        pressure signal, NOT /proc MemAvailable)
    """

    UNAVAILABLE = {
        "pss_mb": "PSS requires Linux/Android smaps_rollup; not exposed on Windows",
        "rss_anon_mb": "Anonymous/file RSS split requires Linux/Android smaps; not exposed on Windows",
        "rss_file_mb": "Anonymous/file RSS split requires Linux/Android smaps; not exposed on Windows",
        "shared_mb": "Shared memory requires Linux/Android smaps; not exposed on Windows",
        "swap_mb": "Swap metric unavailable via psutil on Windows; pagefile_mb provided instead",
    }

    def __init__(self):
        import psutil  # deferred: keep import-time light
        self._psutil = psutil
        self.reasons: Dict[str, str] = {}

    def pid_alive(self, pid: int) -> bool:
        try:
            return self._psutil.Process(pid).is_running()
        except (self._psutil.NoSuchProcess, self._psutil.AccessDenied):
            return False

    def name(self, pid: int) -> Optional[str]:
        try:
            return self._psutil.Process(pid).name()
        except (self._psutil.NoSuchProcess, self._psutil.AccessDenied):
            return None

    def _page_fault_count(self, pid: int) -> Optional[int]:
        """GetProcessMemoryInfo(...).PageFaultCount via psapi.dll (real source)."""
        try:
            PROCESS_QUERY_INFORMATION = 0x0400
            PROCESS_VM_READ = 0x0010
            kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
            psapi = ctypes.WinDLL("psapi")
            handle = kernel32.OpenProcess(
                PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, False, pid)
            if not handle:
                return None
            try:
                counters = _PROCESS_MEMORY_COUNTERS()
                counters.cb = ctypes.sizeof(_PROCESS_MEMORY_COUNTERS)
                if psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
                    return int(counters.PageFaultCount)
                return None
            finally:
                kernel32.CloseHandle(handle)
        except OSError:
            return None

    def sample(self, pid: int) -> Sample:
        s = Sample()
        psutil = self._psutil
        try:
            p = psutil.Process(pid)
            mi = p.memory_info()
            mem: Dict[str, Optional[float]] = {
                "rss_mb": mi.rss / (1024 * 1024),
                "vms_mb": mi.vms / (1024 * 1024),
                "pss_mb": None,
                "rss_anon_mb": None,
                "rss_file_mb": None,
                "private_mb": None,
                "shared_mb": None,
                "swap_mb": None,
                "pagefile_mb": None,
                "uss_mb": None,
                "peak_wset_mb": None,
                "working_set_mb": mi.rss / (1024 * 1024),
                "mem_available_mb": None,
                "mem_total_mb": None,
            }
            try:
                full = p.memory_full_info()
                if hasattr(full, "private"):
                    mem["private_mb"] = full.private / (1024 * 1024)
                if hasattr(full, "uss"):
                    mem["uss_mb"] = full.uss / (1024 * 1024)
                if hasattr(full, "pagefile"):
                    mem["pagefile_mb"] = full.pagefile / (1024 * 1024)
                if hasattr(full, "peak_wset"):
                    mem["peak_wset_mb"] = full.peak_wset / (1024 * 1024)
            except (psutil.AccessDenied, psutil.NoSuchProcess):
                pass

            try:
                vm = psutil.virtual_memory()
                mem["mem_available_mb"] = vm.available / (1024 * 1024)
                mem["mem_total_mb"] = vm.total / (1024 * 1024)
            except Exception:
                pass

            s.memory = mem

            ct = p.cpu_times()
            s.cpu_user_ms = ct.user * 1000.0
            s.cpu_system_ms = ct.system * 1000.0

            try:
                ioc = p.io_counters()
                s.io = {
                    "read_bytes": ioc.read_bytes,
                    "write_bytes": ioc.write_bytes,
                    "read_chars": getattr(ioc, "read_chars", None),
                    "write_chars": getattr(ioc, "write_chars", None),
                    "read_count": ioc.read_count,
                    "write_count": ioc.write_count,
                }
            except (psutil.AccessDenied, psutil.NoSuchProcess, NotImplementedError):
                s.io = {"read_bytes": None, "write_bytes": None,
                        "read_chars": None, "write_chars": None,
                        "read_count": None, "write_count": None}

            pf = self._page_fault_count(pid)
            # Windows does not split minor/major via GetProcessMemoryInfo.
            s.page_faults = {"minor": None, "major": None, "total": pf}

            s.alive = True
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            s.alive = False
        return s


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

def _round(v: Optional[float], nd: int = 3) -> Optional[float]:
    if isinstance(v, float):
        return round(v, nd)
    return v


class RunTelemetry:
    """Platform-agnostic orchestrator: before/after + periodic sampling."""

    def __init__(self, *, platform: str, collector, run_id: Optional[str] = None,
                 device: Optional[Dict[str, str]] = None, engine: str = "",
                 model: Optional[Dict[str, str]] = None,
                 configuration: Optional[Dict[str, Any]] = None):
        self.platform = platform
        self.collector = collector
        self.run_id = run_id or str(uuid.uuid4())
        self.device = device or {}
        self.engine = engine or ""
        self.model = model or {}
        self.configuration = configuration or {}
        self.before: Optional[Sample] = None
        self.after: Optional[Sample] = None
        self.last: Optional[Sample] = None
        self.peak: Dict[str, Optional[float]] = {}
        self.series: List[Dict[str, Any]] = []
        self._stop = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._lock = threading.Lock()
        self._pid: Optional[int] = None
        self.process_comm: Optional[str] = None

    # -- lifecycle ---------------------------------------------------------

    def capture_before(self, pid: int):
        self._pid = pid
        self.before = self.collector.sample(pid)
        if hasattr(self.collector, "name"):
            try:
                self.process_comm = self.collector.name(pid)
            except Exception:
                self.process_comm = None
        with self._lock:
            self.last = self.before
        if self.before and self.before.alive:
            self._update_peak(self.before)

    def start_monitor(self, pid: Optional[int] = None, interval: float = 0.1):
        if pid is not None:
            self._pid = pid
        assert self._pid is not None, "capture_before() must be called first"
        target = self._pid
        self._stop.clear()

        def _run():
            t0 = time.monotonic()
            while not self._stop.is_set():
                try:
                    s = self.collector.sample(target)
                except Exception:
                    self._stop.wait(interval)
                    continue
                if not s.alive:
                    break
                elapsed_ms = (time.monotonic() - t0) * 1000.0
                with self._lock:
                    self.last = s
                    self._update_peak(s)
                self.series.append({
                    "elapsed_ms": round(elapsed_ms, 1),
                    "rss_mb": _round(s.memory.get("rss_mb")),
                    "pss_mb": _round(s.memory.get("pss_mb")),
                    "rss_anon_mb": _round(s.memory.get("rss_anon_mb")),
                    "rss_file_mb": _round(s.memory.get("rss_file_mb")),
                })
                self._stop.wait(interval)

        self._thread = threading.Thread(target=_run, daemon=True)
        self._thread.start()

    def stop_monitor(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2.0)
            self._thread = None

    def capture_after(self, pid: Optional[int] = None):
        target = pid if pid is not None else self._pid
        assert target is not None, "capture_before() must be called first"
        self.after = self.collector.sample(target)
        if self.after and self.after.alive:
            with self._lock:
                self._update_peak(self.after)

    def _update_peak(self, s: Sample):
        for k, v in s.memory.items():
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                cur = self.peak.get(k)
                if cur is None or v > cur:
                    self.peak[k] = v

    def _effective_after(self) -> Optional[Sample]:
        """Final live sample: prefer the monitor's last sample, then a live
        explicit 'after', then the initial 'before'. Avoids reading a zombie
        (empty memory) on Linux after the process has exited."""
        with self._lock:
            if self.last is not None:
                return self.last
        if self.after is not None and self.after.alive:
            return self.after
        return self.before

    # -- record assembly ---------------------------------------------------

    def _norm_mem(self, d: Dict[str, Optional[float]]) -> Dict[str, Optional[float]]:
        return {k: _round(d.get(k)) for k in MEMORY_KEYS}

    def build_run(self, *, exit_code: int, success: bool, wall_ms: float,
                  latency_ms: Optional[float], tokens: int, tok_s: Optional[float],
                  warmup: bool = False, iteration: int = 0,
                  prompt_id: str = "") -> Dict[str, Any]:
        after = self._effective_after()
        mem_before = self._norm_mem(self.before.memory if self.before else {})
        mem_after = self._norm_mem(after.memory if after else {})
        mem_peak = self._norm_mem(self.peak)

        cpu: Dict[str, Optional[float]] = {"cpu_user_ms": None, "cpu_system_ms": None, "cpu_percent": None}
        if self.before and after:
            du = after.cpu_user_ms - self.before.cpu_user_ms \
                if isinstance(after.cpu_user_ms, (int, float)) and isinstance(self.before.cpu_user_ms, (int, float)) else None
            ds = after.cpu_system_ms - self.before.cpu_system_ms \
                if isinstance(after.cpu_system_ms, (int, float)) and isinstance(self.before.cpu_system_ms, (int, float)) else None
            cpu["cpu_user_ms"] = _round(du)
            cpu["cpu_system_ms"] = _round(ds)
            if du is not None and ds is not None and wall_ms:
                cpu["cpu_percent"] = round((du + ds) / wall_ms * 100.0, 2)

        io = compute_delta(self.before.io if self.before else {},
                           after.io if after else {}, IO_KEYS)
        pf = compute_delta(self.before.page_faults if self.before else {},
                           after.page_faults if after else {}, PAGEFAULT_KEYS)

        # Resolve comm for provenance.
        if self.process_comm is None and after is not None:
            self.process_comm = None  # collectors don't expose comm; set below if known

        run = {
            "schema_version": SCHEMA_VERSION,
            "run_id": self.run_id,
            "timestamp_utc": utcnow_iso(),
            "platform": self.platform,
            "device": self.device,
            "engine": self.engine,
            "model": self.model,
            "configuration": dict(self.configuration, **{
                "warmup": bool(warmup),
                "iteration": int(iteration),
                "prompt_id": prompt_id or "",
            }),
            "result": {
                "exit_code": exit_code,
                "success": bool(success),
                "wall_ms": round(wall_ms, 1),
                "latency_ms": _round(latency_ms),
                "tokens": int(tokens),
                "tok_s": _round(tok_s),
            },
            "process": {
                "pid": self._pid,
                "comm": self.process_comm,
            },
            "memory_before": mem_before,
            "memory_after": mem_after,
            "memory_peak": mem_peak,
            "memory_series": self.series,
            "cpu": cpu,
            "io": io,
            "page_faults": pf,
            "collection_status": self._collection_status(mem_peak, cpu, io, pf),
            "manifest": {
                "git_commit": git_commit(),
                "schema_version": SCHEMA_VERSION,
            },
        }
        return run

    def _collection_status(self, mem_peak, cpu, io, pf) -> Dict[str, Any]:
        unavailable: Dict[str, str] = {}
        for k in MEMORY_KEYS:
            if mem_peak.get(k) is None:
                reason = self.collector.UNAVAILABLE.get(k)
                if reason:
                    unavailable[k] = reason
                else:
                    unavailable[k] = "not collected (process absent or permission denied)"
        for k in IO_KEYS:
            if io.get(k) is None:
                unavailable["io_" + k] = "not collected (/proc/<pid>/io or psutil io_counters unavailable)"
        for k in PAGEFAULT_KEYS:
            if pf.get(k) is None:
                reason = ("Windows GetProcessMemoryInfo does not split minor/major"
                          if self.platform == "windows" and k in ("minor", "major")
                          else "not collected")
                unavailable["pf_" + k] = reason
        if cpu.get("cpu_percent") is None:
            unavailable["cpu_percent"] = "requires before/after CPU counters and wall_ms"

        notes = []
        if self.platform == "windows" and mem_peak.get("mem_available_mb") is not None:
            notes.append("mem_available_mb is psutil.virtual_memory().available (approximate; not /proc MemAvailable)")
        if self.platform in ("android", "linux") and mem_peak.get("rss_file_mb") is not None:
            notes.append("rss_file_mb derived as smaps_rollup Rss - Anonymous (page-cache file pages)")

        return {
            "ok": {k: "ok" for k in mem_peak if mem_peak.get(k) is not None},
            "unavailable": unavailable,
            "notes": notes,
        }


# ---------------------------------------------------------------------------
# Provenance / device / model helpers
# ---------------------------------------------------------------------------

def utcnow_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") + \
        datetime.now(timezone.utc).strftime("%f")[:3] + "Z"


def git_commit(root: Optional[str] = None) -> Optional[str]:
    try:
        p = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True,
                           text=True, timeout=10, cwd=root)
        out = p.stdout.strip()
        return out if out and p.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def sha256_file(path: str) -> Optional[str]:
    try:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return None


def infer_model_meta(path: str) -> Tuple[str, str]:
    """Best-effort parameters/quantization from a GGUF filename. Never throws."""
    name = Path(path).name.lower()
    params = ""
    m = re.search(r"(\d+(?:\.\d+)?)b", name)
    if m:
        params = m.group(1).upper() + "B"
    quant = ""
    mq = re.search(r"(q\d_k_\w+|q\d_k\w+|q8_0|q5_1|q4_0|f16|f32)", name)
    if mq:
        quant = mq.group(1).upper()
    return params, quant


def local_device_info() -> Dict[str, str]:
    return {
        "model": _platform.machine() or "",
        "os": "%s %s" % (_platform.system(), _platform.release()),
        "kernel": _platform.version() or "",
    }


def android_device_info(reader: ProcReader) -> Dict[str, str]:
    def prop(k: str) -> str:
        out = reader.shell("getprop %s" % k)
        return out.strip() if out else ""

    kernel = reader.shell("uname -r")
    return {
        "model": prop("ro.product.model") or "",
        "os": "Android " + (prop("ro.build.version.release") or ""),
        "kernel": (kernel.strip() if kernel else "") or "",
    }


def android_sha256(reader: ProcReader, remote_path: str) -> Optional[str]:
    out = reader.shell("sha256sum %s 2>/dev/null" % shlex.quote(remote_path))
    if out:
        parts = out.strip().split()
        if parts and len(parts[0]) == 64 and all(c in "0123456789abcdef" for c in parts[0]):
            return parts[0]
    return None


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------

def read_jsonl(path) -> List[Dict[str, Any]]:
    p = Path(path)
    if not p.exists():
        return []
    out: List[Dict[str, Any]] = []
    with p.open("r", encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def append_jsonl(path, record: Dict[str, Any]):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")


def flatten_run(run: Dict[str, Any]) -> Dict[str, Any]:
    dev = run.get("device") or {}
    mdl = run.get("model") or {}
    cfg = run.get("configuration") or {}
    res = run.get("result") or {}
    mb = run.get("memory_before") or {}
    ma = run.get("memory_after") or {}
    mp = run.get("memory_peak") or {}
    cpu = run.get("cpu") or {}
    io = run.get("io") or {}
    pf = run.get("page_faults") or {}
    manifest = run.get("manifest") or {}
    return {
        "run_id": run.get("run_id", ""),
        "timestamp_utc": run.get("timestamp_utc", ""),
        "platform": run.get("platform", ""),
        "device_model": dev.get("model", ""),
        "device_os": dev.get("os", ""),
        "device_kernel": dev.get("kernel", ""),
        "engine": run.get("engine", ""),
        "model_path": mdl.get("path", ""),
        "model_sha256": mdl.get("sha256", ""),
        "model_parameters": mdl.get("parameters", ""),
        "model_quantization": mdl.get("quantization", ""),
        "context_size": cfg.get("context_size", 0),
        "batch_size": cfg.get("batch_size", 0),
        "prompt_id": cfg.get("prompt_id", ""),
        "output_token_limit": cfg.get("output_token_limit", 0),
        "warmup": cfg.get("warmup", False),
        "iteration": cfg.get("iteration", 0),
        "exit_code": res.get("exit_code", ""),
        "success": res.get("success", ""),
        "wall_ms": res.get("wall_ms", ""),
        "latency_ms": res.get("latency_ms", ""),
        "tokens": res.get("tokens", ""),
        "tok_s": res.get("tok_s", ""),
        "mem_before_rss_mb": mb.get("rss_mb", ""),
        "mem_after_rss_mb": ma.get("rss_mb", ""),
        "mem_peak_rss_mb": mp.get("rss_mb", ""),
        "mem_before_pss_mb": mb.get("pss_mb", ""),
        "mem_after_pss_mb": ma.get("pss_mb", ""),
        "mem_peak_pss_mb": mp.get("pss_mb", ""),
        "mem_before_rss_anon_mb": mb.get("rss_anon_mb", ""),
        "mem_after_rss_anon_mb": ma.get("rss_anon_mb", ""),
        "mem_peak_rss_anon_mb": mp.get("rss_anon_mb", ""),
        "mem_before_rss_file_mb": mb.get("rss_file_mb", ""),
        "mem_after_rss_file_mb": ma.get("rss_file_mb", ""),
        "mem_peak_rss_file_mb": mp.get("rss_file_mb", ""),
        "cpu_user_ms": cpu.get("cpu_user_ms", ""),
        "cpu_system_ms": cpu.get("cpu_system_ms", ""),
        "cpu_percent": cpu.get("cpu_percent", ""),
        "io_read_bytes": io.get("read_bytes", ""),
        "io_write_bytes": io.get("write_bytes", ""),
        "io_read_chars": io.get("read_chars", ""),
        "io_write_chars": io.get("write_chars", ""),
        "io_read_count": io.get("read_count", ""),
        "io_write_count": io.get("write_count", ""),
        "pf_minor": pf.get("minor", ""),
        "pf_major": pf.get("major", ""),
        "pf_total": pf.get("total", ""),
        "git_commit": manifest.get("git_commit", ""),
    }


def derive_csv(jsonl_path, csv_path):
    rows = read_jsonl(jsonl_path)
    p = Path(csv_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=CSV_COLUMNS, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(flatten_run(r))


def write_session_manifest(path, entry: Dict[str, Any]):
    """Append one execution-session record (command, config, device, model)."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n")

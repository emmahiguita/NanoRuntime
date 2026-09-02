#!/usr/bin/env python3
"""
Unit tests for the reusable telemetry layer (scripts/telemetry.py).

Covers, per the review protocol:
  * /proc/<pid>/stat parser (robust to spaces/parens in `comm`)
  * smaps_rollup parser
  * delta computation
  * unavailable-metric case (null + reason, never fabricated)

Run:  python -m pytest tests/test_telemetry.py -v
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import telemetry as t


# ---------------------------------------------------------------------------
# /proc/<pid>/stat parser
# ---------------------------------------------------------------------------

# proc(5) field layout after comm (rest[0] == field 3 = state):
# state ppid pgrp session tty_nr tpgid flags minflt cminflt majflt cmajflt
# utime stime cutime cstime priority nice num_threads itrealvalue starttime
# vsize rss ...
REAL_STAT = (
    "823 (nanortime) R 1 100 101 0 -1 4194560 150 151 42 43 "
    "2987 1777 0 0 20 0 14 0 123456 2172620800 456789 18446744073709551615 "
    "1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 17 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0"
)


def test_parse_proc_stat_basic():
    r = t.parse_proc_stat(REAL_STAT)
    assert r is not None
    assert r["pid"] == 823
    assert r["comm"] == "nanortime"
    assert r["state"] == "R"
    assert r["ppid"] == 1
    assert r["minflt"] == 150
    assert r["cminflt"] == 151
    assert r["majflt"] == 42
    assert r["cmajflt"] == 43
    assert r["utime_ticks"] == 2987
    assert r["stime_ticks"] == 1777
    assert r["num_threads"] == 14
    assert r["vsize_bytes"] == 2172620800
    assert r["rss_pages"] == 456789


def test_parse_proc_stat_comm_with_spaces():
    line = "999 (my weird name) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24"
    r = t.parse_proc_stat(line)
    assert r["pid"] == 999
    assert r["comm"] == "my weird name"
    assert r["state"] == "S"


def test_parse_proc_stat_comm_with_parens():
    # comm contains BOTH a '(' and a ')' — the last ')' closes the field.
    line = "55 (a(b)c) R 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24"
    r = t.parse_proc_stat(line)
    assert r["pid"] == 55
    assert r["comm"] == "a(b)c"
    assert r["state"] == "R"


def test_parse_proc_stat_comm_with_space_and_parens():
    line = "77 (x ) (y) z) R 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24"
    r = t.parse_proc_stat(line)
    assert r["comm"] == "x ) (y) z"


def test_parse_proc_stat_empty_returns_none():
    assert t.parse_proc_stat("") is None
    assert t.parse_proc_stat("   ") is None


def test_parse_proc_stat_malformed_raises():
    with pytest.raises(ValueError):
        t.parse_proc_stat("1234 no-parens R 1 2 3")


# ---------------------------------------------------------------------------
# smaps_rollup parser
# ---------------------------------------------------------------------------

SMAPS_ROLLUP = """Rss:                123456 kB
Pss:                100000 kB
Pss_Anon:            90000 kB
Pss_File:            10000 kB
Shared_Clean:          500 kB
Shared_Dirty:          300 kB
Private_Clean:        1000 kB
Private_Dirty:        2000 kB
Referenced:          120000 kB
Anonymous:            90000 kB
Swap:                 4000 kB
"""


def test_parse_smaps_rollup():
    r = t.parse_smaps_rollup(SMAPS_ROLLUP)
    assert r["Rss"] == 123456
    assert r["Pss"] == 100000
    assert r["Anonymous"] == 90000
    assert r["Swap"] == 4000


def test_parse_smaps_rollup_skips_non_numeric():
    r = t.parse_smaps_rollup("Rss:                1234 kB\nLocked:                0 kB\nVmFlags: rd ex\n")
    assert r.get("Rss") == 1234
    assert "VmFlags" not in r


# ---------------------------------------------------------------------------
# delta computation
# ---------------------------------------------------------------------------

def test_compute_delta_basic():
    before = {"read_bytes": 1000, "write_bytes": 500, "read_chars": 3000}
    after = {"read_bytes": 1500, "write_bytes": 800, "read_chars": 3000}
    d = t.compute_delta(before, after, ["read_bytes", "write_bytes", "read_chars"])
    assert d["read_bytes"] == 500
    assert d["write_bytes"] == 300
    assert d["read_chars"] == 0


def test_compute_delta_missing_returns_none():
    before = {"read_bytes": 1000}
    after = {}
    d = t.compute_delta(before, after, ["read_bytes", "write_bytes"])
    assert d["read_bytes"] is None
    assert d["write_bytes"] is None


def test_compute_delta_none_inputs():
    assert t.compute_delta(None, None, ["a"]) == {"a": None}


def test_compute_delta_ignores_bools():
    # bool is a subclass of int; must not be treated as a numeric counter.
    d = t.compute_delta({"a": True}, {"a": False}, ["a"])
    assert d["a"] is None


# ---------------------------------------------------------------------------
# unavailable metric (never fabricate)
# ---------------------------------------------------------------------------

class _NullReader(t.ProcReader):
    def read(self, path):
        return None

    def shell(self, cmd, timeout=None):
        return None


def test_unavailable_metric_returns_none_with_reason():
    collector = t.LinuxProcCollector(_NullReader())
    s = collector.sample(999999)
    assert s.alive is False
    assert s.memory["rss_mb"] is None
    assert s.memory["pss_mb"] is None
    # Windows-only keys are structurally unavailable on Linux
    assert "pagefile_mb" in collector.UNAVAILABLE
    assert "uss_mb" in collector.UNAVAILABLE


def test_build_run_collection_status_marks_unavailable():
    collector = t.LinuxProcCollector(_NullReader())
    rt = t.RunTelemetry(platform="linux", collector=collector)
    rt.capture_before(999999)
    rt.capture_after(999999)
    run = rt.build_run(exit_code=-1, success=False, wall_ms=0.0,
                       latency_ms=None, tokens=0, tok_s=None)
    assert run["schema_version"] == "1.0"
    assert run["result"]["success"] is False
    assert run["memory_before"]["rss_mb"] is None
    # collection_status must explain why pss/uss are unavailable, not invent them
    assert "pss_mb" in run["collection_status"]["unavailable"]
    assert run["collection_status"]["unavailable"]["uss_mb"]  # non-empty reason


def test_windows_collector_static_unavailable_reasons():
    collector = t.WindowsProcCollector()
    assert "pss_mb" in collector.UNAVAILABLE
    assert "rss_anon_mb" in collector.UNAVAILABLE
    assert "rss_file_mb" in collector.UNAVAILABLE


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def test_infer_model_meta():
    params, quant = t.infer_model_meta("qwen2.5-1.5b-instruct-q4_k_m.gguf")
    assert params == "1.5B"
    assert quant == "Q4_K_M"
    params, quant = t.infer_model_meta("deepseek-r1-distill-qwen-7b-q4_k_m.gguf")
    assert params == "7B"


def test_sha256_file_nonexistent():
    assert t.sha256_file("Z:/does/not/exist.gguf") is None


def test_flatten_run_roundtrip_keys():
    run = {
        "run_id": "abc", "timestamp_utc": "2026-08-01T00:00:00.000Z",
        "platform": "linux", "device": {"model": "x", "os": "y", "kernel": "z"},
        "engine": "nanortime", "model": {"path": "m.gguf", "sha256": "s", "parameters": "1.5B", "quantization": "Q4_K_M"},
        "configuration": {"context_size": 0, "batch_size": 0, "prompt_id": "", "output_token_limit": 0, "warmup": False, "iteration": 1},
        "result": {"exit_code": 0, "success": True, "wall_ms": 1.0, "latency_ms": 1.0, "tokens": 1, "tok_s": 1.0},
        "memory_before": {}, "memory_after": {}, "memory_peak": {},
        "cpu": {}, "io": {}, "page_faults": {}, "manifest": {"git_commit": "g"},
    }
    flat = t.flatten_run(run)
    for col in t.CSV_COLUMNS:
        assert col in flat

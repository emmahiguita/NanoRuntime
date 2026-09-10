#!/usr/bin/env python3
"""Nano Linux welcome and opt-in system information."""

import os
import socket
import sys
import time

CYAN = "\x1b[36m"
GREEN = "\x1b[32m"
WHITE = "\x1b[37m"
DIM = "\x1b[90m"
RESET = "\x1b[0m"
BOLD = "\x1b[1m"


def memory_mib():
    try:
        values = {}
        with open("/proc/meminfo", encoding="utf-8") as stream:
            for line in stream:
                fields = line.split()
                key = fields[0].rstrip(":") if fields else ""
                if key in ("MemTotal", "MemAvailable"):
                    values[key] = int(fields[1])
        total = values.get("MemTotal", 0) // 1024
        available = values.get("MemAvailable", 0) // 1024
        return total - available, total
    except (OSError, ValueError):
        return 0, 0


def uptime():
    try:
        seconds = int(time.clock_gettime(time.CLOCK_BOOTTIME))
        hours, remainder = divmod(seconds, 3600)
        minutes = remainder // 60
        return f"{hours}h {minutes:02d}m"
    except (AttributeError, OSError, ValueError):
        return "?"


def storage():
    try:
        root = os.environ.get("NANO_ROOTFS", os.path.expanduser("~"))
        stat = os.statvfs(root)
        return f"{stat.f_bavail * stat.f_frsize / 1e9:.1f} GB libres"
    except OSError:
        return "?"


def local_ip():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "loopback"
    finally:
        sock.close()


def compact():
    print(f"{BOLD}{WHITE}Nano Linux{RESET} {DIM}· Openbox · sesión móvil{RESET}")
    print(f"{DIM}Escribe {RESET}{CYAN}nano-info{RESET}{DIM} para ver el estado del sistema.{RESET}")


def detailed():
    used, total = memory_mib()
    rows = (
        ("Sesión", "Nano Linux Mobile Desktop"),
        ("Gestor", "Openbox"),
        ("Pantalla", os.environ.get("DISPLAY", ":1")),
        ("Kernel", os.uname().release),
        ("CPU", f"{os.uname().machine} · {os.cpu_count() or 1} núcleos"),
        ("Memoria", f"{used} / {total} MiB" if total else "?"),
        ("Almacenamiento", storage()),
        ("Red", local_ip()),
        ("Tiempo activo", uptime()),
        ("Shell", os.path.basename(os.environ.get("SHELL", "bash"))),
    )
    print(f"{BOLD}{CYAN}NANO LINUX{RESET} {DIM}SYSTEM INFO{RESET}")
    print(f"{DIM}{'─' * 42}{RESET}")
    for label, value in rows:
        print(f"{GREEN}{label:<15}{RESET} {WHITE}{value}{RESET}")


if "--full" in sys.argv[1:]:
    detailed()
else:
    compact()

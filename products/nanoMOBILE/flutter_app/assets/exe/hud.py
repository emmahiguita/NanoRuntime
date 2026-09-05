#!/usr/bin/env python3
# NanoAI desktop HUD - banner de bienvenida (neofetch-style, python puro).
# Leido por aterm -e en el arranque del desktop y disponible como launcher.
# v3: identidad nanoai — borde verde, openbox NanoAI, panel superior.
import os, sys, time, socket

C = "\x1b[36m"; B = "\x1b[32m"; W = "\x1b[37m"; D = "\x1b[90m"
R = "\x1b[0m"; BLD = "\x1b[1m"; DIM = "\x1b[2m"

LOGO = [
" \u2588\u2588\u2588\u2557   \u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2557   \u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557 ",
" \u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2551\u2588\u2588\u2555\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2551\u2588\u2588\u2555\u2550\u2550\u2550\u2588\u2588\u2557",
" \u2588\u2588\u2554\u2588\u2588\u2557 \u2588\u2588\u2551\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2551\u2588\u2588\u2554\u2588\u2588\u2557 \u2588\u2588\u2551\u2588\u2588\u2551   \u2588\u2588\u2551",
" \u2588\u2588\u2551\u255a\u2588\u2588\u2557\u2588\u2588\u2551\u2588\u2588\u2555\u2550\u2550\u2588\u2588\u2551\u2588\u2588\u2551\u255a\u2588\u2588\u2557\u2588\u2588\u2551\u2588\u2588\u2551   \u2588\u2588\u2551",
" \u2588\u2588\u2551 \u255a\u2588\u2588\u2588\u2588\u2551\u2588\u2588\u2551  \u2588\u2588\u2551\u2588\u2588\u2551 \u255a\u2588\u2588\u2588\u2588\u2551\u255a\u2588\u2588\u2588\u2588\u2588\u2588\u2555",
" \u255a\u2550\u255d  \u255a\u2550\u2550\u2550\u255d\u255a\u2550\u255d  \u255a\u2550\u255d\u255a\u2550\u255d  \u255a\u2550\u2550\u2550\u255d \u255a\u2550\u2550\u2550\u2550\u255d ",
]

HUD = "/data/user/0/dev.nanoai.mobile/files/nano/home/.hud.py"


def kbytes():
    try:
        m = {}
        for line in open("/proc/meminfo"):
            p = line.split()
            if p and p[0][:-1] in ("MemTotal", "MemAvailable"):
                m[p[0][:-1]] = int(p[1])
        return m.get("MemTotal", 0) // 1024, m.get("MemAvailable", 0) // 1024
    except Exception:
        return 0, 0


def uptime():
    # /proc/uptime y /proc/stat estan restringidos bajo run-as (SELinux) en
    # este kernel — CLOCK_BOOTTIME es una syscall directa sin permiso extra.
    try:
        s = int(time.clock_gettime(time.CLOCK_BOOTTIME))
        h, m = s // 3600, (s % 3600) // 60
        return "%dh %02dm" % (h, m)
    except Exception:
        return "?"


def storage():
    try:
        st = os.statvfs("/data/user/0/dev.nanoai.mobile/files")
        return "%.1fG libre" % (st.f_bavail * st.f_frsize / 1e9)
    except Exception:
        return "?"


def local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def cpu_model():
    try:
        for line in open("/proc/cpuinfo"):
            if ("Hardware" in line or "Processor" in line) and ":" in line:
                v = line.split(":", 1)[1].strip()
                if v:
                    return v
    except Exception:
        pass
    return "aarch64"


def mem_bar(pct):
    full = pct // 10
    return "\u2588" * full + "\u2591" * (10 - full)


total, avail = kbytes()
used = total - avail
pct = (used * 100 // total) if total else 0
user = os.environ.get("USER") or os.environ.get("LOGNAME") or "user"
kernel = os.uname().release

left = LOGO
right = [
    BLD + W + "@" + C + BLD + "nano" + R + " " + DIM + W + "linux" + R,
    "\u2500" * 28,
    BLD + C + "SISTEMA" + R + D + ":" + R + W + " NanoAI Linux Desktop" + R,
    BLD + C + "GESTOR DE VENTANAS" + R + D + ":" + R + W + " Openbox (NanoAI)" + R,
    BLD + C + "NÚCLEO" + R + D + ":" + R + W + " %s" % kernel + R,
    BLD + C + "TIEMPO ACTIVO" + R + D + ":" + R + W + " %s" % uptime() + R,
    BLD + C + "MEMORIA" + R + D + ":" + R + W + " %d / %d MiB %s%s  %d%%" % (used, total, D, mem_bar(pct), pct) + R,
    BLD + C + "CPU" + R + D + ":" + R + W + " %s (%d núcleos)" % (cpu_model().split()[0][:22], os.cpu_count() or 1) + R,
    BLD + C + "ALMACENAMIENTO" + R + D + ":" + R + W + " %s" % storage() + R,
    BLD + C + "RED" + R + D + ":" + R + W + " %s" % local_ip() + R,
    BLD + C + "SHELL" + R + D + ":" + R + W + " bash" + R,
    "\u2500" * 28,
]
lines = []
for i in range(max(len(left), len(right))):
    l = left[i] if i < len(left) else ""
    r = right[i] if i < len(right) else ""
    lines.append(C + l + R + DIM + " \u2502 " + R + r)

out = "\x1b[2J\x1b[H"
out += B + BLD + "\u2554" + "\u2550" * 78 + "\u2557" + R + "\n"
for line in lines:
    out += " " + line + "\n"
out += B + BLD + "\u255a" + "\u2550" * 78 + "\u255d" + R + "\n"
out += D + "\n  \u26a1 Entorno aislado: rootfs Termux \u00b7 Xvnc :1 \u00b7 RFB 5901 \u00b7 " + BLD + C + "nano-sec" + R + D + " activo" + R + "\n"
out += D + "  Men\u00fa del escritorio (clic derecho) o panel inferior para lanzar apps.\n"
out += D + "  \u00bfVolver a verlo? " + R + W + "python3 %s" % HUD + R + D + " \u00b7 el shell sigue activo debajo" + R + "\n"
sys.stdout.write(out)
sys.stdout.flush()
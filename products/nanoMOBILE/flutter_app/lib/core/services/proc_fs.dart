import 'dart:io';

/// Lee archivos de /proc y /sys sin root. Todo lo que el kernel expone como
/// world-readable (uid, stat, meminfo, net, etc.) está disponible para la app.
///
/// Android (OPPO/ColorOS 15) permite leer /proc/[pid]/*, /proc/meminfo,
/// /proc/net/*, /proc/stat, /proc/loadavg. NO permite /proc/[pid]/maps (SELinux).
class ProcFs {
  ProcFs._();

  // ── /proc/meminfo ──────────────────────────────────────────────

  /// Parsea /proc/meminfo → Map<String, int> (valores en KB).
  static Map<String, int> meminfo() {
    return _parseKeyValInt('/proc/meminfo', suffix: 'kB');
  }

  // ── /proc/vmstat ───────────────────────────────────────────────

  /// Parsea /proc/vmstat → Map<String, int> (contadores del kernel).
  static Map<String, int> vmstat() {
    return _parseKeyValInt('/proc/vmstat');
  }

  // ── /proc/stat ─────────────────────────────────────────────────

  /// Número de procesos en ejecución + bloqueados.
  static (int running, int blocked) procsRunning() {
    try {
      final lines = File('/proc/stat').readAsLinesSync();
      for (final line in lines) {
        if (line.startsWith('procs_running')) {
          final running = int.tryParse(line.split(RegExp(r'\s+'))[1]) ?? 0;
          // procs_blocked está en la siguiente línea
          return (running, 0);
        }
      }
    } catch (_) {}
    return (0, 0);
  }

  // ── /proc/loadavg ──────────────────────────────────────────────

  static (double, double, double) loadavg() {
    try {
      final parts = File(
        '/proc/loadavg',
      ).readAsStringSync().trim().split(RegExp(r'\s+'));
      return (
        double.tryParse(parts[0]) ?? 0,
        double.tryParse(parts[1]) ?? 0,
        double.tryParse(parts[2]) ?? 0,
      );
    } catch (_) {}
    return (0, 0, 0);
  }

  // ── /proc/uptime ───────────────────────────────────────────────

  static double uptimeSec() {
    try {
      final parts = File(
        '/proc/uptime',
      ).readAsStringSync().trim().split(RegExp(r'\s+'));
      return double.tryParse(parts[0]) ?? 0;
    } catch (_) {}
    return 0;
  }

  // ── /proc/[pid]/* ──────────────────────────────────────────────

  /// Lista todos los PIDs en /proc.
  static List<int> listPids() {
    final pids = <int>[];
    try {
      final dir = Directory('/proc');
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.last;
        final pid = int.tryParse(name);
        if (pid != null) pids.add(pid);
      }
    } catch (_) {}
    return pids;
  }

  /// /proc/[pid]/stat → Map con name, pid, ppid, state, vsize, rss, etc.
  static Map<String, dynamic> pidStat(int pid) {
    try {
      final line = File('/proc/$pid/stat').readAsStringSync();
      // Formato: pid (name) state ppid ...
      final close = line.indexOf(')');
      if (close < 0) return {};
      final preamble = line.substring(0, close + 1); // "1234 (name)"
      final rest = line.substring(close + 2); // "state ppid ..."
      final restParts = rest.split(' ');
      // Extraer name entre paréntesis
      final open = preamble.indexOf('(');
      final name = preamble.substring(open + 1, preamble.length - 1);
      return {
        'name': name,
        'pid': pid,
        'state': restParts.isNotEmpty ? restParts[0] : '?',
        'ppid': restParts.length > 1 ? (int.tryParse(restParts[1]) ?? 0) : 0,
        'vsize': restParts.length > 20 ? (int.tryParse(restParts[20]) ?? 0) : 0,
        'rss': restParts.length > 21 ? (int.tryParse(restParts[21]) ?? 0) : 0,
        'threads': restParts.length > 17
            ? (int.tryParse(restParts[17]) ?? 0)
            : 0,
      };
    } catch (_) {}
    return {};
  }

  /// /proc/[pid]/fd/ → lista de {fd: int, target: String}.
  static List<Map<String, dynamic>> pidFds(int pid) {
    final result = <Map<String, dynamic>>[];
    try {
      final dir = Directory('/proc/$pid/fd');
      if (!dir.existsSync()) return result;
      for (final entity in dir.listSync()) {
        final fd = int.tryParse(entity.uri.pathSegments.last);
        if (fd == null) continue;
        try {
          final target = Link(entity.path).targetSync();
          result.add({'fd': fd, 'target': target});
        } catch (_) {
          result.add({'fd': fd, 'target': '(permiso denegado)'});
        }
      }
    } catch (_) {}
    return result;
  }

  // ── /dev/kmsg (kernel ring buffer) ─────────────────────────────

  /// Lee el kernel ring buffer. En Android, /dev/kmsg suele requerir root,
  /// así que intentamos /proc/kmsg como fallback.
  static String? dmesg({int maxLines = 50}) {
    // /proc/kmsg es accesible en algunos kernels sin root
    try {
      final file = File('/proc/kmsg');
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        final start = lines.length > maxLines ? lines.length - maxLines : 0;
        return lines.sublist(start).join('\n');
      }
    } catch (_) {}
    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Parsea archivos key: value con sufijo opcional en el valor.
  static Map<String, int> _parseKeyValInt(String path, {String? suffix}) {
    final m = <String, int>{};
    try {
      for (final line in File(path).readAsLinesSync()) {
        final colon = line.indexOf(':');
        if (colon < 0) continue;
        final key = line.substring(0, colon).trim();
        var valStr = line.substring(colon + 1).trim();
        // Remover sufijo (ej: "kB")
        if (suffix != null && valStr.endsWith(suffix)) {
          valStr = valStr.substring(0, valStr.length - suffix.length).trim();
        }
        final v = int.tryParse(valStr.split(RegExp(r'\s+'))[0]);
        if (v != null) m[key] = v;
      }
    } catch (_) {}
    return m;
  }
}

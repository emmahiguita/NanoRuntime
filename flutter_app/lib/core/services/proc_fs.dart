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

  /// CPU times: [user, nice, system, idle, iowait, irq, softirq, steal].
  /// Primer valor agregado de todos los cores.
  static List<int> cpuTimes() {
    try {
      final lines = File('/proc/stat').readAsLinesSync();
      for (final line in lines) {
        if (line.startsWith('cpu ')) {
          final parts = line.split(RegExp(r'\s+'));
          return parts.sublist(1, 9).map((s) => int.tryParse(s) ?? 0).toList();
        }
      }
    } catch (_) {}
    return [0, 0, 0, 0, 0, 0, 0, 0];
  }

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
      final parts = File('/proc/loadavg').readAsStringSync().trim().split(RegExp(r'\s+'));
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
      final parts = File('/proc/uptime').readAsStringSync().trim().split(RegExp(r'\s+'));
      return double.tryParse(parts[0]) ?? 0;
    } catch (_) {}
    return 0;
  }

  // ── /proc/net/* ────────────────────────────────────────────────

  /// Parsea /proc/net/tcp (y tcp6, udp, udp6).
  /// Retorna lista de sockets con {localAddr, localPort, remoteAddr, remotePort,
  /// state, uid, inode}.
  static List<Map<String, dynamic>> netTcp({bool ipv6 = false}) {
    return _parseNetSocket(ipv6 ? '/proc/net/tcp6' : '/proc/net/tcp');
  }

  static List<Map<String, dynamic>> netUdp({bool ipv6 = false}) {
    return _parseNetSocket(ipv6 ? '/proc/net/udp6' : '/proc/net/udp');
  }

  static List<Map<String, dynamic>> _parseNetSocket(String path) {
    final result = <Map<String, dynamic>>[];
    try {
      final lines = File(path).readAsLinesSync();
      if (lines.isEmpty) return result;
      // Header: sl local_address rem_address st tx_queue rx_queue tr tm->when retrnsmt uid timeout inode
      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].trim().split(RegExp(r'\s+'));
        if (cols.length < 10) continue;
        // local_address: hex IP:hex port (little-endian)
        final local = _parseHexAddr(cols[1]);
        final remote = _parseHexAddr(cols[2]);
        final stateHex = int.tryParse(cols[3], radix: 16);
        final uid = int.tryParse(cols[7]);
        final inode = int.tryParse(cols[9]);
        result.add({
          'localAddr': local.$1,
          'localPort': local.$2,
          'remoteAddr': remote.$1,
          'remotePort': remote.$2,
          'state': _tcpState(stateHex),
          'stateHex': stateHex,
          'uid': uid,
          'inode': inode,
        });
      }
    } catch (_) {}
    return result;
  }

  /// Hex IP:port (little-endian en /proc/net) → (String addr, int port).
  static (String, int) _parseHexAddr(String hexPair) {
    final parts = hexPair.split(':');
    if (parts.length != 2) return ('?', 0);
    final hexIp = parts[0];
    final hexPort = parts[1];
    // IP en hex little-endian (8 dígitos para IPv4)
    int ipInt = int.tryParse(hexIp, radix: 16) ?? 0;
    final addr =
        '${ipInt & 0xFF}.${(ipInt >> 8) & 0xFF}.${(ipInt >> 16) & 0xFF}.${(ipInt >> 24) & 0xFF}';
    final port = int.tryParse(hexPort, radix: 16) ?? 0;
    return (addr, port);
  }

  static String _tcpState(int? hex) {
    if (hex == null) return '??';
    return switch (hex) {
      1 => 'ESTABLISHED',
      2 => 'SYN_SENT',
      3 => 'SYN_RECV',
      4 => 'FIN_WAIT1',
      5 => 'FIN_WAIT2',
      6 => 'TIME_WAIT',
      7 => 'CLOSE',
      8 => 'CLOSE_WAIT',
      9 => 'LAST_ACK',
      10 => 'LISTEN',
      11 => 'CLOSING',
      _ => 'UNKNOWN($hex)',
    };
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
        'threads': restParts.length > 17 ? (int.tryParse(restParts[17]) ?? 0) : 0,
      };
    } catch (_) {}
    return {};
  }

  /// /proc/[pid]/cmdline (argumentos separados por \0).
  static String pidCmdline(int pid) {
    try {
      final raw = File('/proc/$pid/cmdline').readAsBytesSync();
      // Reemplazar \0 por espacio, excepto el último
      return String.fromCharCodes(raw).replaceAll('\x00', ' ').trim();
    } catch (_) {}
    return '';
  }

  /// /proc/[pid]/status → Map<String, String> (Uid, Gid, Groups, Name, VmRSS...).
  static Map<String, String> pidStatus(int pid) {
    final m = <String, String>{};
    try {
      for (final line in File('/proc/$pid/status').readAsLinesSync()) {
        final colon = line.indexOf(':');
        if (colon < 0) continue;
        m[line.substring(0, colon).trim()] = line.substring(colon + 1).trim();
      }
    } catch (_) {}
    return m;
  }

  /// /proc/[pid]/io → Map con rchar, wchar, read_bytes, write_bytes.
  static Map<String, int> pidIo(int pid) {
    return _parseKeyValInt('/proc/$pid/io');
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

  /// Nombre de usuario para un UID. En Android: u0_aNNN → app_NNN.
  /// Para UIDs del sistema (< 10000), usa nombres estándar.
  static String uidToName(int uid) {
    if (uid == 0) return 'root';
    if (uid < 10000) return 'system';
    // Android app UID: u0_aXXX
    final appId = uid - 10000;
    return appId >= 0 ? 'u0_a$appId' : 'uid$uid';
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

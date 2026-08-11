import 'dart:io';

/// Extracted from _TermState (terminal_core.dart) during SRP refactor.
/// Reads real device identity from /proc and /sys without execve.
///
/// Usage:
///   final info = DeviceInfo.read();
///   print(info.hostname); // "oppo"
class DeviceInfo {
  final String? hostname;
  final int? uid;
  final int? gid;
  final String? groups;
  final String? unameRelease;
  final String? unameMachine;
  final int? cpuCores;
  final double? cpuTempC;
  final String? cpuHardware;
  final int? memTotalKb;
  final int? memAvailKb;
  final double? uptimeSec;

  const DeviceInfo({
    this.hostname, this.uid, this.gid, this.groups,
    this.unameRelease, this.unameMachine, this.cpuCores,
    this.cpuTempC, this.cpuHardware,
    this.memTotalKb, this.memAvailKb, this.uptimeSec,
  });

  Map<String, dynamic> toMap() => {
    if (hostname != null) 'hostname': hostname,
    if (uid != null) 'uid': uid,
    if (gid != null) 'gid': gid,
    if (groups != null) 'groups': groups,
    if (unameRelease != null) 'unameRelease': unameRelease,
    if (unameMachine != null) 'unameMachine': unameMachine,
    if (cpuCores != null) 'cpuCores': cpuCores,
    if (cpuTempC != null) 'cpuTempC': cpuTempC,
    if (cpuHardware != null) 'cpuHardware': cpuHardware,
    if (memTotalKb != null) 'memTotalKb': memTotalKb,
    if (memAvailKb != null) 'memAvailKb': memAvailKb,
    if (uptimeSec != null) 'uptimeSec': uptimeSec,
  };

  // ── /proc readers ──

  static String? _readFile(String path) {
    try { return File(path).readAsStringSync().trim(); }
    catch (_) { return null; }
  }

  static int? _readFirstInt(String path) {
    final s = _readFile(path);
    if (s == null) return null;
    final m = RegExp(r'(\d+)').firstMatch(s);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Lee identidad real del device (sync, sin execve — mismo permiso que
  /// /proc directo). Alternativa a getDeviceIdentity por MethodChannel.
  /// Usado en _TermState como fallback / fuente única de datos /proc.
  static DeviceInfo read() {
    // Uid/Gid/Groups desde /proc/self/status
    int? uid, gid; String? groups;
    final status = _readFile('/proc/self/status');
    if (status != null) {
      for (final line in status.split('\n')) {
        if (line.startsWith('Uid:')) {
          uid = int.tryParse(line.substring(4).trim().split(RegExp(r'\s')).first);
        } else if (line.startsWith('Gid:')) {
          gid = int.tryParse(line.substring(4).trim().split(RegExp(r'\s')).first);
        } else if (line.startsWith('Groups:')) {
          groups = line.substring(7).trim();
        }
      }
    }
    return DeviceInfo(
      hostname: _readFile('/proc/sys/kernel/hostname') ?? 'localhost',
      uid: uid,
      gid: gid,
      groups: groups,
      unameRelease: _readFile('/proc/sys/kernel/osrelease'),
      unameMachine: _readFile('/proc/sys/kernel/arch') ?? _archFromCpuInfo(),
      cpuCores: Platform.numberOfProcessors,
      cpuTempC: readCpuTemp(),
      cpuHardware: _readCpuHardware(),
      memTotalKb: _readFirstInt('/proc/meminfo'),
      memAvailKb: _readMemAvailableKb(),
      uptimeSec: _readUptimeSec(),
    );
  }

  static String? _archFromCpuInfo() {
    final info = _readFile('/proc/cpuinfo');
    if (info == null) return null;
    final archLine = info.split('\n').where((l) => l.contains('architecture')).firstOrNull;
    return archLine?.split(':').last.trim();
  }

  static String? _readCpuHardware() {
    final info = _readFile('/proc/cpuinfo');
    if (info == null) return null;
    for (final line in info.split('\n')) {
      if (line.toLowerCase().contains('hardware')) {
        final v = line.split(':').last.trim();
        if (v.isNotEmpty && !v.contains('Revision')) return v;
      }
    }
    return null;
  }

  static int? _readMemAvailableKb() {
    final f = _readFile('/proc/meminfo');
    if (f == null) return null;
    final m = RegExp(r'MemAvailable:\s+(\d+)').firstMatch(f);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  static double? _readUptimeSec() {
    final u = _readFile('/proc/uptime');
    if (u == null) return null;
    return double.tryParse(u.split(RegExp(r'\s')).first);
  }

  /// Read CPU temperature from thermal zones.
  static double? readCpuTemp() {
    const paths = [
      '/sys/class/thermal/thermal_zone0/temp',
      '/sys/class/thermal/thermal_zone1/temp',
      '/sys/class/thermal/thermal_zone5/temp',
      '/sys/devices/virtual/thermal/thermal_zone0/temp',
    ];
    for (final p in paths) {
      final raw = _readFile(p);
      if (raw == null) continue;
      final v = double.tryParse(raw);
      if (v == null) continue;
      return v > 200 ? v / 1000.0 : v;
    }
    return null;
  }

  /// Read GPU info from Adreno sysfs (kgsl-3d0) + Mali fallback.
  /// Campos: name, freqMhz, gpuLoad, tempC. Ausentes si no legibles.
  static Map<String, dynamic> readGpuInfo() {
    final info = <String, dynamic>{};
    const kgslBase = '/sys/class/kgsl/kgsl-3d0';
    // Frecuencia: gpuclk directo o devfreq/cur_freq
    try {
      final gpuclk = _readFile('$kgslBase/gpuclk');
      final hz = int.tryParse(gpuclk ?? '');
      if (hz != null) info['freqMhz'] = (hz / 1000000).round();
    } catch (_) {}
    if (!info.containsKey('freqMhz')) {
      try {
        final devfreq = _readFile('$kgslBase/devfreq/cur_freq');
        final hz = int.tryParse(devfreq ?? '');
        if (hz != null) info['freqMhz'] = (hz / 1000000).round();
      } catch (_) {}
    }
    try {
      final gpuBusy = _readFile('$kgslBase/gpubusy');
      if (gpuBusy != null) {
        final parts = gpuBusy.split(RegExp(r'\s+'));
        if (parts.length == 2) {
          final busy = double.tryParse(parts[0]);
          final total = double.tryParse(parts[1]);
          if (busy != null && total != null && total > 0) {
            info['gpuLoad'] = (busy / total * 100).roundToDouble();
          }
        }
      }
    } catch (_) {}
    // Temperatura GPU (varía por device)
    for (final p in const [
      '$kgslBase/temp',
      '/sys/class/thermal/thermal_zone2/temp',
      '/sys/class/thermal/thermal_zone5/temp',
    ]) {
      final raw = _readFile(p);
      if (raw == null) continue;
      final v = double.tryParse(raw);
      if (v != null) { info['tempC'] = v > 200 ? v / 1000.0 : v; break; }
    }
    // Nombre: kgsl name → Mali legacy → null
    try { final name = _readFile('$kgslBase/name'); if (name != null) info['name'] = name; } catch (_) {}
    if (!info.containsKey('name')) {
      try {
        final mali = _readFile('/sys/kernel/gpu/gpu_model');
        if (mali != null) info['name'] = mali;
      } catch (_) {}
    }
    return info;
  }
}

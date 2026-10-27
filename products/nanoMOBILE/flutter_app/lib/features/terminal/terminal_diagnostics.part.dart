part of 'terminal_core.dart';

/// Componente diagnostics: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalDiagnostics on _TerminalStateBase {
  @override
  void _registerDiagnostics() {
    _cmds['stat'] = (a, c, o, af) async {
      final all = a.contains('--all'),
          mem = all || a.contains('--memory'),
          cpu = all || a.contains('--cpu');
      o('══ NanoRuntime Status ══', Ln.header);
      if (mem) {
        final d = _devId;
        final double totalKb = (d?['memTotalKb'] as num?)?.toDouble() ?? 0.0;
        final double availKb = (d?['memAvailKb'] as num?)?.toDouble() ?? 0.0;
        final double usedKb = totalKb > 0 ? totalKb - availKb : 0.0;
        String fmt(double kb) => kb >= 1048576
            ? '${(kb / 1048576).toStringAsFixed(2)} GB'
            : '${(kb / 1024).toStringAsFixed(0)} MB';
        if (totalKb > 0) {
          final pct = totalKb > 0 ? (usedKb / totalKb * 100).round() : 0;
          final cachedKb = ProcFs.meminfo()['Cached'];
          final cacheStr = cachedKb != null
              ? ' | PageCache: ${fmt(cachedKb.toDouble())}'
              : '';
          o(
            'RAM: ${fmt(totalKb)} | Used: ${fmt(usedKb)} ($pct%) | Free: ${fmt(availKb)}$cacheStr',
            Ln.stdout,
          );
        } else {
          o('RAM: (leyendo /proc/meminfo...)', Ln.stdout);
        }
        o(
          'Modelo/KV: sin datos del motor LLM — usa "tune" para diagnóstico real',
          Ln.info,
        );
      }
      if (cpu) {
        final cores =
            _devId?['cpuCores'] as int? ?? Platform.numberOfProcessors;
        final hw = _devId?['cpuHardware'] as String?;
        final tempC = await _readCpuTemp();
        final tempStr = tempC != null
            ? ' | Temp: ${tempC.toStringAsFixed(1)}Â°C'
            : '';
        o(
          'CPU: $cores cores${hw != null ? ' ($hw)' : ''}$tempStr | Procs: ${ProcFs.listPids().length}',
          Ln.stdout,
        );
      }
    };
  }

  @override
  void _registerGpu() {
    _cmds['gpu'] = (a, c, o, af) {
      final info = _hw.readGpuInfo();
      // Sin nombre real del sysfs: 'desconocida', nunca una marca inventada.
      final name = info['name'] as String? ?? 'desconocida';
      final freq = info['freqMhz'];
      final temp = info['tempC'];
      final freqStr = freq != null ? ' | Freq: $freq MHz' : '';
      final tempStr = temp != null
          ? ' | Temp: ${temp.toStringAsFixed(1)}Â°C'
          : '';
      o('GPU: $name$freqStr$tempStr', Ln.stdout);
      final load = info['gpuLoad'];
      if (load != null) {
        o('  Load: ${load.toStringAsFixed(1)}%', Ln.stdout);
      }
      if (freq == null && temp == null) {
        final hw = _devId?['cpuHardware'] as String?;
        if (hw != null) {
          o(
            '  SoC: $hw (GPU info via /sys/class/kgsl/ no disponible)',
            Ln.info,
          );
        }
      }
    };
    _cmds['nvtop'] = (a, c, o, af) {
      final info = _hw.readGpuInfo();
      final name = (info['name'] as String?) ?? 'desconocida';
      final freq = info['freqMhz'];
      o('â•”══ nvtop ══â•—', Ln.header);
      o('â•‘ GPU: $name ${" ".padLeft(15 - name.length)}â•‘', Ln.header);
      if (freq != null) {
        o('â•‘ Freq: $freq MHz ${" ".padLeft(8)}â•‘', Ln.header);
      }
      o('â•š═══════════â•', Ln.header);
    };
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'terminal_modifier_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/services/llm_engine_client.dart';
import '../../core/services/rootfs_manager.dart';
import '../../core/services/proot_manager.dart';
import '../../core/services/kali_manager.dart';
import '../../core/services/docker_manager.dart';
import '../../core/services/proc_fs.dart';
import '../../core/services/pty_shell.dart';
import '../../core/services/hardware_info_service.dart';
import '../../core/services/terminal_dependencies.dart';
import 'i_bin_executor.dart';
import 'keyboard_mapper.dart';
import 'command_tagger.dart';
import 'noar_persistence.dart';

import 'noar_panel.dart';
import 'ansi_terminal.dart';
import 'command_dispatcher.dart';
import 'cron_scheduler.dart';
import 'pty_manager.dart';
import 'real_fs_shell.dart';
import 'terminal_types.dart';
import 'terminalservices.dart';
import 'plugins/system_plugin.dart';
import 'plugins/devops_plugin.dart';
import 'plugins/dashboard_plugin.dart';
import 'plugins/monitor_plugin.dart';
import 'plugins/network_plugin.dart';
import 'plugins/pkg_plugin.dart';
import 'plugins/process_plugin.dart';

class NanoTerminal extends StatefulWidget {
  final int sessionId;
  final String initialCwd;
  final LLMEngineClient? engine;
  final void Function(String title)? onTitle;

  /// true = pestaña visible en el IndexedStack. Dirige pause/resume del
  /// polling PTY: solo la pestaña activa consume 20 polls/seg (rate limit).
  final bool visible;
  final TerminalDependencies? deps; // optional override for testing

  /// Comando que se ejecuta una sola vez cuando el shell está listo
  /// (ej: "kali shell" desde la card Kali del dashboard). Cuando existe,
  /// se suprime el bash PTY automático para que el stream del comando
  /// sea el dueño del terminal.
  final String? initialCommand;
  const NanoTerminal({
    super.key,
    this.sessionId = 0,
    this.initialCwd = '/home/nanoai',
    this.engine,
    this.onTitle,
    this.visible = true,
    this.deps,
    this.initialCommand,
  });
  @override
  State<NanoTerminal> createState() => _TermState();
}

class _TermState extends State<NanoTerminal> {
  TerminalDependencies get _deps =>
      widget.deps ?? TerminalDependencies.instance;
  IBinExecutor? get _shell => _deps.shell;
  RootfsManager? get _rootfs => _deps.rootfs;
  ProotManager? get _proot => _deps.proot;
  KaliManager? get _kali => _deps.kali;
  DockerManager? get _docker => _deps.docker;

  /// TerminalServices para plugins (DIP). Cached to avoid re-allocation on
  /// every plugin call — the closures capture `this` so the instance stays
  /// valid for the widget's lifetime.
  late final TerminalServices _services = TerminalServices(
    ctx: _ctx,
    out: _out,
    after: _after,
    rootfsEnv: _deps.rootfsEnv,
    getEngine: () => _engine,
    audit: (cmd, tag, data) {},
    shell: _shell,
    rootfs: _rootfs,
    docker: _docker,
    kali: _kali,
    proot: _proot,
    deviceId: _devId,
    onClear: () {
      if (mounted) setState(() => _lines.clear());
    },
    onNavigate: (route) {
      if (!mounted) return;
      try {
        context.push(route);
      } catch (_) {
        Navigator.of(context).pushNamed(route);
      }
    },
    mounted: mounted,
  );

  final HardwareInfoService _hw = HardwareInfoService();
  Map<String, dynamic>? get _devId => _hw.deviceId;

  final _in = TextEditingController(),
      _sc = ScrollController(),
      _fn = FocusNode();
  final _lines = <TL>[], _hist = <String>[], _timers = <Timer>[];
  final _ctx = TerminalCtx();
  int _hIdx = -1;
  bool _ctrl = false, _alive = true;
  bool _initialCmdDone = false;
  LLMEngineClient? _engine;
  PtySession? _pty;
  final _ptyLines = <String>[]; // buffer acumulado del output PTY
  AnsiTerminal? _ansi;
  CronScheduler? _cron;
  final _cmds = <String, CmdFn>{};
  CommandDispatcher? _dispatcher;
  PtyManager? _ptyManager;

  String get _baseDir {
    final usr = _shell?.usrDir ?? _rootfs?.usrDir ?? '';
    return usr.endsWith('/usr') ? usr.substring(0, usr.length - 4) : usr;
  }

  String get _usrDir => _shell?.usrDir ?? _rootfs?.usrDir ?? '';

  Offset _fabOffset = Offset.zero;
  bool _fabInit = false;
  static const double _fabSize = 40;

  String _bashCwd = '/';

  /// Fallback dart:io real (ver real_fs_shell.dart). Solo se usa en hosts sin
  /// binarios Android (desktop/tests): los comandos FS operan sobre el
  /// filesystem real del host bajo un raíz sandbox. En Android manda el motor
  /// NanoRuntime (BusyBox vía Nanoshell FFI / rootfs).
  late final RealFsShell _realFs;

  /// Whitelist de comandos con ejecución real vía BusyBox (ver realCommands
  /// en terminal_types.dart). En hosts sin binarios Android, RealFsShell
  /// implementa el subconjunto dart:io como fallback real.
  String get _ps1 {
    final h = _devId?['hostname'] as String? ?? 'oppo';
    String home = _bashCwd;
    if (home == '/systemTemp/nano_real_root' || home == '/') {
      home = '~';
    } else if (home.startsWith('/systemTemp/nano_real_root/')) {
      home = home.substring('/systemTemp/nano_real_root'.length);
    }
    return 'nanoai@$h:$home\$ ';
  }

  static const int _maxLines = 10000;
  bool _scrollPending = false;

  void _out(String t, Ln ty) {
    if (t.isEmpty && ty == Ln.stdout) return;
    setState(() {
      _lines.add(TL(t, ty));
      if (_lines.length > _maxLines) {
        _lines.removeRange(0, _lines.length - _maxLines);
      }
    });
    if (!_scrollPending) {
      _scrollPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollPending = false;
        if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
      });
    }
  }

  void _after(Duration d, VoidCallback cb) {
    late final Timer t;
    t = Timer(d, () {
      _timers.remove(t); // no acumular timers muertos en sesiones largas
      if (_alive) cb();
    });
    _timers.add(t);
  }

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? LLMEngineClient();
    _ctx.cwd = widget.initialCwd;
    _realFs = RealFsShell(
      root: Platform.isAndroid
          ? '/data/data/dev.nanoai.mobile/files/nano'
          : '${Directory.systemTemp.path}/nano_real_root',
    );
    _buildRegistry(); // terminal-specific commands (ai, gpu, docker, kali, etc.)
    _fetchDeviceIdentity(); // async: uid, uname, hostname reales del device
    _initShell(); // async: extrae bash/toybox + verifica rootfs (crea ShellExecutor + RootfsManager compartidos)
    _noar.load(); // async: carga librería de comandos guardados
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fabInit && mounted) {
        final sz = MediaQuery.of(context).size;
        setState(() {
          _fabOffset = Offset(sz.width - _fabSize - 12, sz.height * 0.35);
          _fabInit = true;
        });
      }
    });
    _out('NanoTerminal  rootfs ARM64', Ln.header);
    _out('Modo: auto-PTY (bash interactivo real)', Ln.info);
    _out('', Ln.stdout);
    _loadHistory();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(covariant NanoTerminal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      final pm = _ptyManager;
      if (pm != null) {
        if (widget.visible) {
          pm.resumePolling();
        } else {
          pm.pausePolling();
        }
      }
    }
  }

  /// Obtiene identidad real del device (uid, uname, hostname, meminfo...) desde la plataforma. Los comandos usan estos datos para devolver info auténtica sin depender de execve() (bloqueado por SELinux en este device).
  Future<void> _fetchDeviceIdentity() => _hw.fetchDeviceIdentity();

  Future<double?> _readCpuTemp() => _hw.readCpuTemp();

  /// Extrae bash y toybox de assets/bin/ al dir privado de la app y los marca ejecutables. Luego verifica/instala el rootfs Termux completo.  ¡IMPORTANTE! ShellExecutor y terminal_core comparten la MISMA instancia de RootfsManager para que el estado de instalación esté sincronizado.
  Future<void> _initShell() async {
    if (_deps.rootfs == null) {
      await _deps.initAll(onProgress: (msg) => _out('[init] $msg', Ln.system));
    }
    _dispatcher = CommandDispatcher(
      shell: _shell,
      ctx: _ctx,
      out: _out,
      getBaseDir: () => _baseDir,
      getUsrDir: () => _usrDir,
      rootfsEnv: _deps.rootfsEnv,
    );
    _dispatcher!.buildRegistry();
    _ptyManager = PtyManager(
      rootfs: _rootfs,
      rootfsEnv: _deps.rootfsEnv,
      onTitle: widget.onTitle,
      // P1: sin este callback, _ansi seguía apuntando al ChangeNotifier ya
      // dispuesto por el manager tras el fin de la sesión (Ctrl-D/exit) —
      // cualquier rebuild posterior lanzaba "used after being disposed".
      onSessionEnd: () {
        if (!mounted) return;
        setState(() => _ansi = null);
      },
    );
    if (_shell?.initialized == true) {
      _out('[shell] bash + toybox listos en ${_shell!.binDir}', Ln.system);
    }
    final installed = _rootfs?.isInstalled == true;
    if (installed) {
      _out('[rootfs] detectado en ${_rootfs!.usrDir}', Ln.success);
      if (_shell != null && _shell!.usrDir != null && _shell!.baseDir != null) {
        final usr = _shell!.usrDir!;
        final base = _shell!.baseDir!;
        _ctx.env['HOME'] = '$base/home';
        _ctx.env['PREFIX'] = usr;
        _ctx.env['PATH'] = '$usr/bin:$usr/bin/applets:/system/bin:/system/xbin';
        _ctx.env['SHELL'] = '$usr/bin/bash';
        _ctx.env['TMPDIR'] = '$usr/tmp';
        _ctx.env['LD_LIBRARY_PATH'] = '$usr/lib';
        _ctx.env['TERMUX'] = 'true';
        _ctx.env['TERMUX_VERSION'] = '0.118.0';
        _ctx.env['TERMUX_APP__PID'] = '$pid';
        _ctx.env['TERMUX_APK_RELEASE'] = 'F_DROID';
        _ctx.env['TERMUX_APP__IS_DEBUGGABLE'] = 'false';
        _ctx.env['ANDROID_DATA'] = '/data';
        _ctx.env['ANDROID_ROOT'] = '/system';
        _ctx.env['LANG'] = 'en_US.UTF-8';
        _bashCwd = '$base/home';
        try {
          Directory('$base/home').createSync(recursive: true);
        } catch (_) {}
        try {
          Directory('$usr/tmp').createSync(recursive: true);
        } catch (_) {}
        try {
          Directory('$usr/var/lib/dpkg').createSync(recursive: true);
        } catch (_) {}
        try {
          Directory('$usr/var/log').createSync(recursive: true);
        } catch (_) {}
      }
      // Sin comando inicial inyectado: bash PTY automático. Con comando
      // inicial (ej: kali shell), el dispatcher y su stream proot son el
      // dueño del terminal; abrir bash encima mezclaría las dos sesiones.
      if (widget.initialCommand == null) {
        _after(const Duration(milliseconds: 500), () => _ptyOpen(['bash']));
      }
    } else {
      _out('[rootfs] no instalado. Ejecuta "bootstrap".', Ln.info);
    }
    if (_proot != null && _proot!.isReady) {
      _out('[proot] listo → chroot sin root disponible', Ln.system);
    } else {
      _out('[proot] no disponible (ptrace bloqueado por SELinux?)', Ln.warn);
    }
    if (_kali != null) {
      await _kali!.checkInstalled();
      if (_kali!.isInstalled) {
        _out('[kali] detectado en ${_kali!.kaliRoot}', Ln.success);
      }
    }
    if (_docker != null) {
      _out('[docker] runtime listo', Ln.system);
    }
    // Comando inicial inyectado desde la UI (card Kali del dashboard):
    // dispatcher ya construido, se ejecuta una sola vez.
    if (widget.initialCommand != null && !_initialCmdDone) {
      _initialCmdDone = true;
      _execAsync(widget.initialCommand!);
    }
  }

  @override
  void dispose() {
    _saveHistory();
    _alive = false;
    _ptyClose(notify: false);
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _cron?.dispose();
    _cron = null;
    try {
      _shell?.killAll();
    } catch (_) {}
    try {
      _docker?.dispose();
    } catch (_) {}
    _in.dispose();
    _sc.dispose();
    _fn.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Builds the legacy command registry. Common Linux commands (ls, cat, etc.) are handled by CommandDispatcher. This registry only adds terminal-specific commands (ai, gpu, docker, kali, help, noar, etc.) and simulated fallbacks.
  void _buildRegistry() {
    final s = _services;
    void r(String n, CmdFn f) => _cmds[n] = f;
    SystemPlugin().register(r, s);

    MonitorPlugin().register(r, s);
    ProcessPlugin().register(r, s);
    PkgPlugin().register(r, s);
    NetworkPlugin().register(r, s);
    DevOpsPlugin().register(r, s);
    DashboardPlugin().register(r, s);
    // crontab/watch REALES: timers que ejecutan _execAsync de verdad.
    // Registrados después de DevOpsPlugin para pisar cualquier stub.
    // P2: la instancia se guarda — antes su dispose() nunca se llamaba y
    // los timers de crontab/watch quedaban vivos para siempre.
    _cron = CronScheduler(
      execCmd: (raw) => _execAsync(raw),
      isAlive: () => _alive,
    )..register(r, _out);
    // pty REAL: abre sesión interactiva via _ptyOpen (el stub del plugin
    // nunca finge apertura — este registro lo reemplaza por el real).
    _cmds['pty'] = (a, c, o, af) {
      final usr = _rootfs?.usrDir;
      if (usr == null) {
        o('pty: rootfs no instalado', Ln.stderr);
        return;
      }
      final bashPath = a.isNotEmpty ? a[0] : '$usr/bin/bash';
      _ptyOpen([bashPath, ...a.sublist(1)], o: o);
    };
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
            ? ' | Temp: ${tempC.toStringAsFixed(1)}°C'
            : '';
        o(
          'CPU: $cores cores${hw != null ? ' ($hw)' : ''}$tempStr | Procs: ${ProcFs.listPids().length}',
          Ln.stdout,
        );
      }
    };
    _cmds['infer'] = (a, c, o, af) {
      if (a.isEmpty) {
        o('infer: prompt requerido', Ln.stderr);
        return;
      }
      final prompt = a.join(' ');
      final engine = _engine;
      if (engine == null) {
        o('infer: motor LLM no disponible', Ln.stderr);
        return;
      }
      o('[NanoRuntime] Enviando a ${engine.baseUrl}...', Ln.system);
      final start = DateTime.now();
      engine
          .generate(prompt: prompt, maxTokens: 128)
          .then((res) {
            if (!_alive || !mounted) return;
            final ms = DateTime.now().difference(start).inMilliseconds;
            for (final line in res.text.split('\n')) {
              if (line.isNotEmpty) o(line, Ln.success);
            }
            o('${ms}ms @ ${res.tps?.toStringAsFixed(1) ?? "?"} tok/s', Ln.info);
          })
          .catchError((e) {
            if (!_alive || !mounted) return;
            o('infer: el motor no respondió — $e', Ln.stderr);
          });
    };
    _cmds['ai'] = (a, c, o, af) {
      if (a.isEmpty) {
        o('ai: escribe un prompt. Ej: ai ¿cómo optimizar RAM?', Ln.stderr);
        return;
      }
      final prompt = a.join(' ');
      final engine = _engine;
      if (engine == null) {
        o('ai: motor LLM no disponible', Ln.stderr);
        return;
      }
      o('[NanoAI] Pensando... (${engine.baseUrl})', Ln.info);
      engine
          .generate(prompt: prompt, maxTokens: 512)
          .then((res) {
            if (!_alive || !mounted) return;
            for (final line in res.text.split('\n')) {
              if (line.isNotEmpty) o(line, Ln.stdout);
            }
            if (res.tps != null) {
              o('${res.tps!.toStringAsFixed(1)} tok/s', Ln.info);
            }
          })
          .catchError((e) {
            if (!_alive || !mounted) return;
            o(
              'ai: el motor no respondió. ¿Está corriendo llama.cpp en 127.0.0.1:8080?',
              Ln.stderr,
            );
            o('  $e', Ln.stderr);
          });
    };
    _cmds['tune'] = (a, c, o, af) async {
      o('══ NanoAI Auto-Tune ══', Ln.header);
      final mem = ProcFs.meminfo();
      final totalMb = (mem['MemTotal'] ?? 0) ~/ 1024;
      final availMb = (mem['MemAvailable'] ?? mem['MemFree'] ?? 0) ~/ 1024;
      final cores = _devId?['cpuCores'] as int? ?? Platform.numberOfProcessors;
      final tempC = await _readCpuTemp();
      o(
        'Device: ${totalMb}MB RAM, ${availMb}MB libre, $cores cores'
        '${tempC != null ? ', ${tempC.toStringAsFixed(1)}°C' : ''}',
        Ln.info,
      );
      final engine = _engine;
      if (engine == null) {
        o('Motor LLM: no configurado (sin engine client)', Ln.warn);
        o('Sugerencias: instala llama.cpp en 127.0.0.1:8080', Ln.info);
        return;
      }
      o('Motor URL: ${engine.baseUrl}', Ln.info);
      final online = await engine.isOnline();
      if (!online) {
        o('Motor: OFFLINE (no responde en ${engine.baseUrl})', Ln.warn);
        o('Sugerencia: lanza llama.cpp con --server --port 8080', Ln.info);
        return;
      }
      o('Motor: ONLINE', Ln.success);
      o('Benchmark TPS... (prompt de prueba)', Ln.info);
      try {
        final res = await engine.generate(
          prompt: 'Hello',
          maxTokens: 10,
          temperature: 0.0,
        );
        o(
          'Respuesta: "${res.text.length > 40 ? '${res.text.substring(0, 40)}...' : res.text}"',
          Ln.stdout,
        );
        if (res.tps != null) {
          o('Velocidad: ${res.tps!.toStringAsFixed(1)} tok/s', Ln.success);
          if (res.tps! < 5) {
            o('⚠ TPS bajo. Considera:', Ln.warn);
            o(
              '  - Usar un modelo más pequeño (Qwen 0.5B en vez de 1.5B)',
              Ln.info,
            );
            o('  - Reducir context window (--ctx-size 512)', Ln.info);
            o('  - Deshabilitar GPU layers si tenés poca RAM', Ln.info);
          } else if (res.tps! < 20) {
            o('TPS aceptable. Optimizaciones:', Ln.info);
            o('  - Subir --threads a $cores para mejor rendimiento', Ln.info);
            o('  - Aumentar --batch-size a 512 si tenés RAM', Ln.info);
          } else {
            o('TPS excelente. Sugerencias:', Ln.info);
            o('  - Podés usar modelos más grandes (Qwen 3B, 7B)', Ln.info);
            o('  - Aumentar --ctx-size a 4096 para prompts largos', Ln.info);
          }
        }
        if (availMb < 500) {
          o(
            '⚠ RAM baja (${availMb}MB libre). Riesgo de OOM con modelos grandes.',
            Ln.warn,
          );
        } else if (availMb > 2000) {
          o(
            'RAM suficiente para modelos de hasta ~2B parámetros (Qwen-1.5B, Gemma-2B).',
            Ln.info,
          );
        } else {
          o('RAM adecuada para modelos de ~1B parámetros.', Ln.info);
        }
      } on LLMEngineException catch (e) {
        o('Benchmark falló: ${e.message}', Ln.stderr);
      }
    };
    _cmds['gpu'] = (a, c, o, af) {
      final info = _hw.readGpuInfo();
      // Sin nombre real del sysfs: 'desconocida', nunca una marca inventada.
      final name = info['name'] as String? ?? 'desconocida';
      final freq = info['freqMhz'];
      final temp = info['tempC'];
      final freqStr = freq != null ? ' | Freq: $freq MHz' : '';
      final tempStr = temp != null
          ? ' | Temp: ${temp.toStringAsFixed(1)}°C'
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
      o('╔══ nvtop ══╗', Ln.header);
      o('║ GPU: $name ${" ".padLeft(15 - name.length)}║', Ln.header);
      if (freq != null) o('║ Freq: $freq MHz ${" ".padLeft(8)}║', Ln.header);
      o('╚═══════════╝', Ln.header);
    };
  }

  List<String> _tok(String c) {
    final t = <String>[], b = StringBuffer();
    bool sq = false, dq = false;
    for (int i = 0; i < c.length; i++) {
      final ch = c[i];
      if (ch == "'" && !dq) {
        sq = !sq;
        continue;
      }
      if (ch == '"' && !sq) {
        dq = !dq;
        continue;
      }
      if (ch == ' ' && !sq && !dq) {
        if (b.isNotEmpty) {
          t.add(b.toString());
          b.clear();
        }
        continue;
      }
      b.write(ch);
    }
    if (b.isNotEmpty) t.add(b.toString());
    return t;
  }

  /// Detecta operadores de shell (| > < >> && || ;) fuera de comillas. Si están presentes, el comando debe delegarse a bash -c.
  bool _hasShellOps(String cmd) {
    bool sq = false, dq = false;
    for (int i = 0; i < cmd.length; i++) {
      final ch = cmd[i];
      if (ch == "'" && !dq) {
        sq = !sq;
        continue;
      }
      if (ch == '"' && !sq) {
        dq = !dq;
        continue;
      }
      if (sq || dq) continue;
      if (ch == '|') return true;
      if (ch == '>' || ch == '<') return true;
      if (ch == '&' && i + 1 < cmd.length && cmd[i + 1] == '&') return true;
      if (ch == '|' && i + 1 < cmd.length && cmd[i + 1] == '|') return true;
      if (ch == ';') return true;
    }
    return false;
  }

  void _exec(String raw) {
    _execAsync(raw);
  } // puente sync→async para onSubmitted

  bool get _ptyActive => _pty != null && !_pty!.isClosed;

  int _ptyRows = 24, _ptyCols = 80;

  /// Aplica el tamaño del área visible al PTY y al buffer ANSI. Los apps fullscreen (vim/htop) consultan TIOCGWINSZ en cada redibujo; sin resize real dibujan en 24x80 aunque la pantalla sea mayor. Se difiere a post-frame porque toca ChangeNotifier (evita rebuild en build).
  ///
  /// Usa las MISMAS métricas de celda que AnsiTerminalView (AnsiMetrics):
  /// antes se asumía 7.6px de ancho y 20px de alto a mano; con la fuente
  /// real del device el grid del render y el del buffer divergían y las
  /// cajas/columnas de apps fullscreen se descuadraban (errores de píxel).
  void _applyPtySize(double w, double h) {
    if (_pty == null || !_ptyActive || _ansi == null) return;
    final m = AnsiMetrics.measure();
    final rows = (h / m.cellH).floor().clamp(1, 200);
    final cols = (w / m.cellW).floor().clamp(1, 300);
    if (rows == _ptyRows && cols == _ptyCols) return;
    _ptyRows = rows;
    _ptyCols = cols;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ansi?.reset(rows: rows, cols: cols);
      _pty!.resize(rows, cols);
    });
  }

  /// Abre una sesión PTY con [argv]. Si falla, vuelca error por [o].
  Future<void> _ptyOpen(
    List<String> argv, {
    Map<String, String>? env,
    String? ldPreload,
    void Function(String, Ln)? o,
  }) async {
    final out = o ?? _out;
    // Diagnóstico temprano: binario ausente → sugerir pkg install.
    if (argv.isNotEmpty && argv.first.contains('/')) {
      try {
        if (!File(argv.first).existsSync()) {
          final name = argv.first.split('/').last;
          out(
            'pty: "$name" no está en el rootfs. Ejecuta "pkg install $name".',
            Ln.stderr,
          );
          return;
        }
      } catch (_) {}
    }
    final pm = _ptyManager;
    if (pm == null) {
      out('[pty] gestor de sesiones no inicializado.', Ln.stderr);
      return;
    }
    final ok = await pm.open(argv, env: env, ldPreload: ldPreload);
    if (!ok) {
      // Un único camino de apertura. El fallback histórico abría una segunda
      // sesión PtySession paralela duplicando el ciclo de vida del
      // AnsiTerminal y sus listeners (riesgo de doble dispose). El error se
      // reporta y PtyManager deja el estado limpio.
      out('[pty] no se pudo abrir la sesión interactiva.', Ln.stderr);
      return;
    }
    _pty = pm.session;
    _ansi = pm.ansi;
    if (mounted) setState(() {});
    out(
      '— terminal interactivo (Ctrl+C para SIGINT, escribe "exit") —',
      Ln.system,
    );
    out('pty> ', Ln.prompt);
  }

  Future<void> _ptyClose({bool notify = true}) async {
    final p = _pty;
    _pty = null;
    _ptyLines.clear();
    // Defer AnsiTerminal dispose to post-frame so AnsiTerminalView can
    // removeListener() during its own dispose() before the ChangeNotifier dies.
    final oldAnsi = _ansi;
    _ansi = null;
    if (oldAnsi != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          oldAnsi.dispose();
        } catch (_) {}
      });
    }
    if (p != null) {
      try {
        await p.signal(2);
      } catch (_) {}
      try {
        await p.close();
      } catch (_) {}
    }
    if (notify && mounted) setState(() {});
  }

  /// Persistencia Noar (librería de comandos). SRP: la lógica vive en
  /// [NoarPersistence]; este campo es la instancia que la UI lee.
  final NoarPersistence _noar = NoarPersistence();
  List<Map<String, dynamic>> get _noarLib => _noar.entries;

  /// Clasifica un comando en un tag basado en su nombre (canonical: CommandTagger).
  String _tagFor(String cmd) => CommandTagger.tag(cmd);

  Future<void> _execAsync(String raw) async {
    if (_ptyActive) {
      final cmd = raw.trim();
      if (cmd == 'exit' || cmd == 'logout' || cmd == '^D') {
        await _ptyClose();
        return;
      }
      // In PTY mode, onChanged already sent each character as it was typed.
      // onSubmitted only needs to send CR (Enter). Sending the full text again
      // would duplicate every character the user typed.
      _pty!.writeBytes([0x0d]);
      return;
    }
    _out(_ps1 + raw, Ln.prompt);
    final cmd = raw.trim();
    if (cmd.isEmpty) return;
    _hist.add(cmd);
    _hIdx = -1;
    _in.clear();
    _noar.save(cmd, CommandTagger.tag(cmd));
    if (cmd == 'exit' || cmd == 'logout') {
      _out('— Sesion finalizada ($cmd) —', Ln.system);
      return;
    }
    if (_dispatcher != null && !_hasShellOps(cmd)) {
      final parts = cmd.split(RegExp(r'\s+'));
      if (parts.isNotEmpty &&
          _dispatcher!.dispatch(
            parts[0],
            parts.length > 1 ? parts.sublist(1) : <String>[],
          )) {
        return;
      }
    }
    // persistir en libreria Noar

    if (cmd.startsWith('!')) {
      final shellCmd = cmd.substring(1).trim();
      if (shellCmd.isEmpty) return;
      if (shellCmd.startsWith('cd ') || shellCmd == 'cd') {
        final target = shellCmd.length > 3 ? shellCmd.substring(3).trim() : '/';
        if (target == '..') {
          _bashCwd = _bashCwd == '/'
              ? '/'
              : _bashCwd.substring(0, _bashCwd.lastIndexOf('/'));
          if (_bashCwd.isEmpty) _bashCwd = '/';
        } else if (target.startsWith('/')) {
          _bashCwd = target;
        } else if (target.isNotEmpty) {
          _bashCwd = _bashCwd == '/' ? '/$target' : '$_bashCwd/$target';
        }
        _out('[ash] cd → $_bashCwd', Ln.system);
      }
      if (_shell != null && _shell!.initialized) {
        _out('[ash] $shellCmd', Ln.system);
        final extraEnv = _rootfs?.isInstalled == true
            ? <String, String>{
                'LD_PRELOAD': 'libnanoroot.so',
                'NANO_ROOTFS': _shell!.usrDir!,
                'LD_LIBRARY_PATH': '${_shell!.usrDir}/lib',
                'HOME': '${_shell!.baseDir!}/home',
                'PATH':
                    '${_shell!.usrDir}/bin:${_shell!.usrDir}/bin/applets:/system/bin:/system/xbin',
                'TERMUX': 'true',
                'LANG': 'en_US.UTF-8',
              }
            : null;
        final r = await _shell!.toybox([
          'ash',
          '-c',
          shellCmd,
        ], extraEnv: extraEnv);
        _shellOut(r);
      } else {
        _out('! : shell no disponible (binarios no extraídos)', Ln.stderr);
      }
      return;
    }
    if (_hasShellOps(cmd)) {
      // Host con sh real (Linux/macOS desktop): pipes/redirección/&& reales
      // delegando a `sh -c` sobre el sandbox real. En Android manda toybox
      // ash del motor NanoRuntime. Sin ninguno: error honesto.
      if (!Platform.isAndroid && _realFs.hasRealShell) {
        await _realFs.runShell(cmd, out: _out);
        return;
      }
      if (_shell != null && _shell!.initialized) {
        _out('[ash] $cmd', Ln.system);
        final extraEnv = _rootfs?.isInstalled == true
            ? _deps.rootfsEnv(ldPreload: 'libnanoroot.so')
            : null;
        final r = await _shell!.toybox(['ash', '-c', cmd], extraEnv: extraEnv);
        _shellOut(r);
        return;
      }
      _out('sh: no disponible (sin rootfs ni shell del host)', Ln.stderr);
      return;
    }
    var parts = _tok(cmd);
    if (parts.isNotEmpty && _ctx.aliases.containsKey(parts[0])) {
      parts = _tok(_ctx.aliases[parts[0]]!);
    }
    if (parts.isEmpty) return;
    final name = parts[0], args = parts.sublist(1);
    if (name == 'bash' && _shell != null && _shell!.initialized) {
      final shellCmd = args.isNotEmpty ? args.join(' ') : '-i';
      _out('[ash] $shellCmd', Ln.system);
      final r = await _shell!.toybox(['ash', '-c', shellCmd]);
      _shellOut(r);
      return;
    }
    if (name == 'toybox' && _shell != null && _shell!.initialized) {
      final result = await _shell!.toybox(args);
      _shellOut(result);
      return;
    }
    if (realCommands.contains(name)) {
      if (_shell != null && _shell!.initialized && Platform.isAndroid) {
        final r = await _shell!.toybox([name, ...args]);
        _shellOut(r);
      } else if (!Platform.isAndroid &&
          (_realFs.supports(name) || _realFs.hasRealShell)) {
        // Desktop: binario real del host (sed/awk/tar/chmod... GNU reales)
        // con fallback dart:io para el subconjunto soportado.
        await _realFs.run(name, args, out: _out);
        if (name == 'cd') _bashCwd = _realFs.cwd;
      } else if (!Platform.isAndroid) {
        _out('$name: no disponible (sin binarios en este host)', Ln.stderr);
      } else {
        _out('$name: shell engine not initialized.', Ln.stderr);
      }
      return;
    }
    // Fallback dart:io para comandos fuera de realCommands (tree, source)
    // en hosts sin binarios Android.
    if (!Platform.isAndroid && _realFs.supports(name)) {
      await _realFs.run(name, args, out: _out);
      if (name == 'cd') _bashCwd = _realFs.cwd;
      return;
    }
    if (name == 'source') {
      if (args.isEmpty) {
        _out('source: falta archivo', Ln.stderr);
        return;
      }
      if (_shell != null && _shell!.initialized) {
        final r = await _shell!.toybox(['ash', '-c', 'source ${args[0]}']);
        _shellOut(r);
      } else {
        _out('source: shell engine not initialized.', Ln.stderr);
      }
      return;
    }
    final handler = _cmds[name];
    if (handler != null) {
      final result = handler(args, _ctx, _out, _after);
      if (result is Future) await result;
    } else {
      _out('$name: comando no encontrado. "help" para ver todos.', Ln.stderr);
    }
  }

  /// Vuelca la salida de un ShellResult en el buffer del terminal.
  void _shellOut(ShellResult r) {
    if (!_alive || !mounted) return;
    for (final l in r.stdout.split('\n')) {
      if (l.isNotEmpty) _out(l, Ln.stdout);
    }
    for (final l in r.stderr.split('\n')) {
      if (l.isNotEmpty) _out(l, Ln.stderr);
    }
  }

  /// Handler global de teclado (HardwareKeyboard).  En modo PTY interactivo cada keydown se convierte a bytes y se envía al terminal (vim/htop/python necesitan teclas individuales, no líneas con Enter). Fuera de PTY conserva Ctrl+L/C de la shell integrada.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) {
      if (e is KeyUpEvent &&
          (e.logicalKey == LogicalKeyboardKey.controlLeft ||
              e.logicalKey == LogicalKeyboardKey.controlRight)) {
        _ctrl = false;
      }
      return false;
    }
    if (e.logicalKey == LogicalKeyboardKey.controlLeft ||
        e.logicalKey == LogicalKeyboardKey.controlRight) {
      _ctrl = true;
      return false;
    }
    if (_ptyActive) {
      if (_ctrl) {
        if (e.logicalKey == LogicalKeyboardKey.keyC) {
          _ctrl = false;
          _pty!.signal(2);
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyL) {
          _ctrl = false;
          _pty!.write('\x0c');
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyZ) {
          _ctrl = false;
          _pty!.write('\x1a');
          return true;
        }
        if (e.logicalKey == LogicalKeyboardKey.keyD) {
          _ctrl = false;
          _pty!.write('\x04');
          return true;
        }
        final ch = const KeyboardMapper().logicalToChar(e.logicalKey);
        if (ch != null && ch >= 0x61 && ch <= 0x7a) {
          _pty!.writeBytes([ch - 0x60]);
          return true;
        }
        if (ch != null && ch >= 0x41 && ch <= 0x5a) {
          _pty!.writeBytes([ch - 0x40]);
          return true;
        }
        return false;
      }
      if (HardwareKeyboard.instance.isAltPressed &&
          !HardwareKeyboard.instance.isControlPressed) {
        final bytes = const KeyboardMapper().keyToPtyBytes(
          e.logicalKey,
          ctrl: _ctrl,
        );
        if (bytes != null && bytes.length == 1 && bytes[0] >= 0x20) {
          _pty!.writeBytes([0x1b, bytes[0]]);
          return true;
        }
      }
      final bytes = const KeyboardMapper().keyToPtyBytes(
        e.logicalKey,
        ctrl: _ctrl,
      );
      if (bytes != null) _pty!.writeBytes(bytes);
      return bytes != null;
    }
    if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyL) {
      setState(() => _lines.clear());
      _ctrl = false;
      return true;
    }
    if (_ctrl && e.logicalKey == LogicalKeyboardKey.keyC) {
      _out('^C', Ln.stdout);
      _in.clear();
      _ctrl = false;
      return true;
    }
    return false;
  }

  List<String> _sug() {
    final p = _in.text.trim();
    if (p.isEmpty) return _cmds.keys.take(8).toList();
    return _cmds.keys.where((c) => c.startsWith(p)).take(10).toList();
  }

  Future<void> _loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final j = p.getString('term_hist_${widget.sessionId}');
      if (j != null) _hist.addAll((jsonDecode(j) as List).cast<String>());
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        'term_hist_${widget.sessionId}',
        jsonEncode(
          _hist.length > 500 ? _hist.sublist(_hist.length - 500) : _hist,
        ),
      );
    } catch (_) {}
  }

  Color _c(Ln t, Color fg, NanoColors c) => switch (t) {
    Ln.prompt => fg.withValues(alpha: 0.9),
    Ln.stdout => fg.withValues(alpha: 0.78),
    Ln.stderr => c.danger,
    Ln.success => fg,
    Ln.info => fg.withValues(alpha: 0.65),
    Ln.warn => c.warning,
    Ln.system => fg.withValues(alpha: 0.55),
    Ln.header => c.success,
  };

  @override
  Widget build(BuildContext context) {
    final c = NanoThemeExtension.of(context).colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chrome = dark ? const Color(0xFF07192B) : c.terminalBg;
    final fg = dark ? const Color(0xFF21F2B2) : c.terminalGreen;
    final sug = _sug();
    return Stack(
      children: [
        Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              color: chrome,
              child: Text(
                _ptyActive
                    ? 'PTY: bash (rootfs real)'
                    : 'OFFLINE (rootfs no instalado)',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  color: _ptyActive ? c.success : c.warning,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ScanlinePainter(
                          _ansi != null ? fg.withValues(alpha: 0.4) : fg,
                        ),
                      ),
                    ),
                  ),
                  if (_ansi != null)
                    GestureDetector(
                      onTap: () => _fn.requestFocus(),
                      onTapDown: _ansi?.mouseEnabled == true
                          ? (d) {
                              final m = AnsiMetrics.measure();
                              final row = (d.localPosition.dy / m.cellH)
                                  .floor();
                              final col = (d.localPosition.dx / m.cellW)
                                  .floor();
                              _pty?.writeBytes([
                                0x1b,
                                0x5b,
                                0x4d,
                                32,
                                col + 33,
                                row + 33,
                              ]);
                            }
                          : null,
                      child: ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: LayoutBuilder(
                          builder: (context, cons) {
                            _applyPtySize(cons.maxWidth, cons.maxHeight);
                            return SelectionArea(
                              child: AnsiTerminalView(_ansi!),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    SelectionArea(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 2.5,
                        child: GestureDetector(
                          onTap: () => _fn.requestFocus(),
                          child: ListView.builder(
                            controller: _sc,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: _lines.length,
                            itemBuilder: (_, i) {
                              final line = _lines[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 1.5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 10,
                                          color: fg.withValues(alpha: 0.15),
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        line.text,
                                        style: TextStyle(
                                          fontFamily: 'JetBrainsMono',
                                          fontSize: 12.5,
                                          color: _c(line.type, fg, c),
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_ptyActive)
              TerminalModifierBar(
                fg: fg,
                chrome: chrome,
                ctrlActive: _ctrl,
                onToggleCtrl: () {
                  setState(() {
                    _ctrl = !_ctrl;
                  });
                },
                onWriteBytes: (bytes) => _pty?.writeBytes(bytes),
                onWrite: (text) => _pty?.write(text),
                bracketedPasteEnabled:
                    _ansi?.screen.bracketedPasteMode ?? false,
              ),
            if (sug.isNotEmpty && _in.text.isNotEmpty && _fn.hasFocus)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: chrome,
                  border: Border(
                    top: BorderSide(color: fg.withValues(alpha: 0.08)),
                  ),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: sug
                      .map(
                        (s) => GestureDetector(
                          onTap: () {
                            _in.text = s;
                            _in.selection = TextSelection.collapsed(
                              offset: s.length,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: fg.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: fg.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11.5,
                                color: fg.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: chrome,
                border: Border(
                  top: BorderSide(color: fg.withValues(alpha: 0.12)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      _ps1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                          if (_hIdx < _hist.length - 1) {
                            _hIdx++;
                            _in.text = _hist.reversed.toList()[_hIdx];
                            _in.selection = TextSelection.collapsed(
                              offset: _in.text.length,
                            );
                          }
                        },
                        const SingleActivator(
                          LogicalKeyboardKey.arrowDown,
                        ): () {
                          if (_hIdx > 0) {
                            _hIdx--;
                            _in.text = _hist.reversed.toList()[_hIdx];
                          } else {
                            _hIdx = -1;
                            _in.clear();
                          }
                        },
                        const SingleActivator(LogicalKeyboardKey.tab): () {
                          if (sug.isNotEmpty) {
                            _in.text = sug.first;
                            _in.selection = TextSelection.collapsed(
                              offset: _in.text.length,
                            );
                          }
                        },
                      },
                      child: TextField(
                        controller: _in,
                        focusNode: _fn,
                        autofocus: true,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13,
                          color: fg,
                          height: 1.5,
                        ),
                        cursorColor: fg,
                        cursorWidth: 2,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: _ptyActive
                              ? 'terminal interactivo — escribe directo (Ctrl+C salir)'
                              : 'comando o "ai <pregunta>"...',
                          hintStyle: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 13,
                            color: fg.withValues(alpha: 0.18),
                          ),
                        ),
                        onSubmitted: _exec,
                        onChanged: (v) {
                          if (_ptyActive && v.isNotEmpty) {
                            // Send raw bytes including printable chars. Control chars
                            // (backspace 0x7F, etc.) are handled by _onKey/modifier row,
                            // not the soft keyboard, so filtering >= 0x20 is correct.
                            final bytes = utf8.encode(v);
                            if (bytes.isNotEmpty) _pty!.writeBytes(bytes);
                            // Clear without triggering another onChanged (avoid loop).
                            _in.value = TextEditingValue.empty;
                            return;
                          }
                          _hIdx = -1;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_fabInit)
          Positioned(
            left: _fabOffset.dx,
            top: _fabOffset.dy,
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  final sw = MediaQuery.of(context).size.width;
                  final sh = MediaQuery.of(context).size.height;
                  _fabOffset = Offset(
                    (_fabOffset.dx + d.delta.dx).clamp(0.0, sw - _fabSize),
                    (_fabOffset.dy + d.delta.dy).clamp(
                      40.0,
                      sh - _fabSize - 100,
                    ),
                  );
                });
              },
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _fabInit ? 0.55 : 0.0,
                child: Material(
                  color: chrome,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            NoarPanel(library: _noarLib, fg: fg, dark: dark),
                      );
                    },
                    child: Container(
                      width: _fabSize,
                      height: _fabSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: fg.withValues(alpha: 0.18)),
                      ),
                      child: Icon(Icons.menu_book_rounded, color: fg, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Subtle scanline effect for retro terminal feel
class _ScanlinePainter extends CustomPainter {
  final Color color;
  _ScanlinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.015);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

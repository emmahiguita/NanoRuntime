part of 'terminal_core.dart';

/// Componente shell_init: mantiene las operaciones existentes y el dueño de sesión.
mixin _TerminalShellInit on _TerminalStateBase {
  /// Obtiene identidad real del device (uid, uname, hostname, meminfo...) desde la plataforma. Los comandos usan estos datos para devolver info auténtica sin depender de execve() (bloqueado por SELinux en este device).
  @override
  Future<void> _fetchDeviceIdentity() => _hw.fetchDeviceIdentity();

  /// TER-21: OSC 7 del bash PTY — el shell reporta su cwd real con cada
  /// prompt. Sincroniza la línea de estado; antes era heurística Dart
  /// que se desfasaba al hacer `cd` dentro del bash real.
  void _onBashCwd(String cwd) {
    if (cwd == _bashCwd.value) {
      return;
    }
    debugPrint('[TER-21] bash cwd: $cwd');
    _bashCwd.value = cwd;
    if (mounted) setState(() {});
  }

  @override
  Future<double?> _readCpuTemp() => _hw.readCpuTemp();

  /// Extrae bash y toybox de assets/bin/ al dir privado de la app y los marca ejecutables. Luego verifica/instala el rootfs Termux completo.  ¡IMPORTANTE! ShellExecutor y terminal_core comparten la MISMA instancia de RootfsManager para que el estado de instalación esté sincronizado.
  @override
  Future<void> _initShell() async {
    try {
      if (_deps.rootfs == null) {
        await _deps.initAll(
          onProgress: (msg) => _out('[init] $msg', Ln.system),
        );
      }
    } catch (e) {
      _out('[init] inicio parcial ($e)', Ln.warn);
    }

    // QUÉ: detiene la inicialización si la pestaña se cerró durante initAll.
    // POR QUÉ: evita crear managers o ejecutar el comando inicial tras dispose.
    if (!_alive || !mounted) return;
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
      shell: _shell,
      rootfsEnv: _deps.rootfsEnv,
      onTitle: widget.onTitle,
      // TER-21: cwd real del bash (OSC 7) → línea de estado.
      onCwd: _onBashCwd,
      onSessionEnd: () {
        if (!mounted) return;
        setState(() {
          _ansi = null;
          _pty = null;
        });
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
        // TER-IDENT-01 — honestidad: este entorno no es F-Droid Termux,
        // es el bootstrap nanoMOBILE (pilar 4: jamás identidad falsa).
        _ctx.env['TERMUX_APK_RELEASE'] = 'nanoMOBILE';
        _ctx.env['TERMUX_APP__IS_DEBUGGABLE'] = 'false';
        _ctx.env['ANDROID_DATA'] = '/data';
        _ctx.env['ANDROID_ROOT'] = '/system';
        _ctx.env['LANG'] = 'en_US.UTF-8';
        _bashCwd.value = '$base/home';
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
    } else {
      _out(
        '[rootfs] no instalado. Usa bootstrap si requieres apt/dpkg.',
        Ln.info,
      );
    }
    // Auto-apertura PTY en la sesión activa: disponible con rootfs o con shell local
    if (widget.initialCommand == null && widget.visible) {
      _autoOpenBash();
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

    // checkInstalled también es asíncrono; vuelve a comprobar el ciclo de vida.
    if (!_alive || !mounted) return;
    // Comando inicial inyectado desde la UI (card Kali del dashboard):
    // dispatcher ya construido, se ejecuta una sola vez.
    if (widget.initialCommand != null && !_initialCmdDone) {
      _initialCmdDone = true;
      CommandExecutor.execute(widget.initialCommand!, _execCtx());
    }
  }
}

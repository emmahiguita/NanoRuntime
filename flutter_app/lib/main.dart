import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';
import 'core/router/app_router.dart';
import 'core/services/rootfs_manager.dart';
import 'core/services/shell_executor.dart';
import 'features/terminal/terminal_screen.dart';

void main() => runApp(const ProviderScope(child: NanoPlatformApp()));

class NanoPlatformApp extends ConsumerStatefulWidget {
  const NanoPlatformApp({super.key});
  @override ConsumerState<NanoPlatformApp> createState() => _NanoPlatformAppState();
}

class _NanoPlatformAppState extends ConsumerState<NanoPlatformApp> {
  @override void initState() { super.initState(); _bootRootfsNow(); }

  static const _essentialPkgs = ['python', 'htop', 'git'];

  Future<void> _bootRootfsNow() async {
    try {
      final rootfs = RootfsManager.instance;
      final ok = rootfs.isInstalled;
      if (!ok) {
        debugPrint('[boot] rootfs no instalado — auto-bootstrap en background...');
        await rootfs.install();
        debugPrint('[boot] auto-bootstrap: ${rootfs.isInstalled ? "OK" : "FALLÓ"}');
      } else {
        debugPrint('[boot] rootfs ya instalado en ${rootfs.usrDir}');
      }
      if (rootfs.isInstalled) {
        _setupBashrc(rootfs);
        _copyNanorootLib(rootfs);
        await _installEssentials(rootfs);
      }
    } catch (e) {
      debugPrint('[boot] error de bootstrap: $e');
    }
  }

  Future<void> _installEssentials(RootfsManager rootfs) async {
    try {
      final shell = ShellExecutor(rootfs: rootfs);
      await shell.init();
      final missing = <String>[];
      for (final p in _essentialPkgs) {
        final bin = File('${rootfs.usrDir}/bin/$p');
        if (!bin.existsSync()) missing.add(p);
      }
      if (missing.isEmpty) {
        debugPrint('[boot] paquetes esenciales ya instalados');
        _installDesktop(rootfs);
        return;
      }
      debugPrint('[boot] instalando paquetes: ${missing.join(", ")}...');
      final ok = await shell.installPackages(missing);
      debugPrint('[boot] instalador directo: ${ok ? "OK" : "FALLÓ"}');
      if (ok) {
        debugPrint('[boot] paquetes instalados: ${missing.join(", ")}');
        _installDesktop(rootfs);
      }
    } catch (e) {
      debugPrint('[boot] install essentials falló: $e');
    }
  }

  Future<void> _installDesktop(RootfsManager rootfs) async {
    try {
      final xvnc = File('${rootfs.usrDir}/bin/Xvnc');
      if (xvnc.existsSync()) {
        debugPrint('[boot] escritorio ya instalado');
        _patchVncBinaries(rootfs);
        final shell = ShellExecutor(rootfs: rootfs);
        await shell.init();
        final port = await shell.startVnc();
        debugPrint('[boot] VNC server en puerto $port');
        AppRouter.router.go('/desktop');
        return;
      }
      debugPrint('[boot] instalando escritorio VNC...');
      final shell = ShellExecutor(rootfs: rootfs);
      await shell.init();
      final ok = await shell.installGraphical();
      debugPrint('[boot] escritorio: ${ok ? "OK" : "FALLÓ"}');
      if (ok) {
        _patchVncBinaries(rootfs);
        final port = await shell.startVnc();
        debugPrint('[boot] VNC server en puerto $port');
        AppRouter.router.go('/desktop');
      }
    } catch (e) {
      debugPrint('[boot] escritorio falló: $e');
    }
  }

  void _patchVncBinaries(RootfsManager rootfs) {
    try {
      final usr = rootfs.usrDir!;
      final xvnc = File('$usr/bin/Xvnc');
      if (!xvnc.existsSync() || File('$usr/bin/Xvnc.bak').existsSync()) return;
      debugPrint('[boot] aplicando parches VNC...');
      final prefixSrc = '/data/data/com.termux/files/usr';
      final prefixDst = '/data/data/dev.nanoai.mobile/f\x00';
      for (final bin in ['Xvnc', 'openbox', 'tint2']) {
        final f = File('$usr/bin/$bin');
        if (!f.existsSync()) continue;
        f.copySync('$usr/bin/$bin.bak');
        final data = f.readAsBytesSync();
        final src = prefixSrc.codeUnits;
        final dst = prefixDst.codeUnits;
        final replaced = _replaceBytes(data, src, dst);
        f.writeAsBytesSync(replaced);
        debugPrint('[boot] patch $bin: ${data.length} bytes');
      }
      // Symlinks (ignorar si ya existen)
      try { Link('/data/data/dev.nanoai.mobile/f').createSync('files/nano/usr', recursive: false); } catch (_) {}
      try { Link('$usr/share/X11/xkb').createSync('../xkeyboard-config-2', recursive: false); } catch (_) {}
      for (final dir in ['compat','geometry','keycodes','rules','symbols','types']) {
        try { Link('$usr/$dir').createSync('share/xkeyboard-config-2/$dir', recursive: false); } catch (_) {}
      }
      // xkbcomp wrapper
      File('$usr/bin/xkbcomp').writeAsStringSync('#!/bin/sh\nfor a in "\$@"; do case "\$a" in *.xkm) touch "\$a";; esac;done\nexit 0\n');
      try { Process.runSync('chmod', ['755', '$usr/bin/xkbcomp']); } catch (_) {}
      debugPrint('[boot] VNC patches aplicados');
    } catch (e) {
      debugPrint('[boot] VNC patch error: $e');
    }
  }

  List<int> _replaceBytes(List<int> data, List<int> from, List<int> to) {
    final result = <int>[];
    var i = 0;
    while (i < data.length) {
      if (i + from.length <= data.length && _match(data, i, from)) {
        result.addAll(to);
        i += from.length;
      } else {
        result.add(data[i]);
        i++;
      }
    }
    return result;
  }

  bool _match(List<int> data, int start, List<int> pattern) {
    for (var j = 0; j < pattern.length; j++) {
      if (data[start + j] != pattern[j]) return false;
    }
    return true;
  }

  void _copyNanorootLib(RootfsManager rootfs) {
    try {
      final dst = File('${rootfs.usrDir}/lib/libnanoroot.so');
      if (dst.existsSync()) return;
      debugPrint('[boot] libnanoroot.so no encontrado en rootfs');
    } catch (e) {
      debugPrint('[boot] copy libnanoroot falló: $e');
    }
  }

  void _setupBashrc(RootfsManager rootfs) {
    final usr = rootfs.usrDir; if (usr == null) return;
    final homeDir = Directory('${File(usr).parent.path}/home');
    if (!homeDir.existsSync()) homeDir.createSync(recursive: true);
    final bashrc = File('${homeDir.path}/.bashrc');
    if (bashrc.existsSync()) return;
    bashrc.writeAsStringSync(r'''
# NanoAI Terminal — .bashrc
export PS1='\[\e[32m\]\u@nano\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias free='free -h'
alias pkg='apt'
alias py='python3'
alias nv='nvtop'
export TERM=xterm-256color
export PAGER=less
export EDITOR=vim
''');
    debugPrint('[boot] .bashrc creado en ${homeDir.path}');
  }

  ThemeMode _themeMode = ThemeMode.dark;
  @override Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'NanoPlatform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}

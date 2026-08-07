import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/rootfs_manager.dart';
import 'core/services/shell_executor.dart';

void main() {
  // Offline-first: nunca intentar descargar fuentes por HTTP.
  // Usa las cached si existen, si no fallback del sistema.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const ProviderScope(child: NanoPlatformApp()));
}

class NanoPlatformApp extends ConsumerStatefulWidget {
  const NanoPlatformApp({super.key});
  @override ConsumerState<NanoPlatformApp> createState() => _NanoPlatformAppState();
}

class _NanoPlatformAppState extends ConsumerState<NanoPlatformApp> {
  @override
  void initState() {
    super.initState();
    // Carga persistida de ajustes en el arranque: el tema guardado se
    // aplica desde el primer frame, sin esperar a visitar Ajustes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).init();
    });
    // Bootstrap global del rootfs Termux: instala en background si falta.
    // Corre al ARRANCAR la app (no solo al abrir la pestaÃ±a Terminal), asÃ­
    // el terminal interactivo queda operativo sin intervenciÃ³n manual.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootRootfsNow());
  }

  /// Descarga e instala el rootfs Termux si no estÃ¡ presente. No bloquea el
  /// primer frame; reporta por debugPrint (la UI del terminal muestra su
  /// propio progreso vÃ­a RootfsManager compartido).
  Future<void> _bootRootfsNow() async {
    try {
      final rootfs = ref.read(rootfsProvider);
      final ok = await rootfs.checkInstalled();
      if (!ok) {
        debugPrint('[boot] rootfs no instalado â€” auto-bootstrap en background...');
        await rootfs.install();
        debugPrint('[boot] auto-bootstrap: ${rootfs.isInstalled ? "OK" : "FALLÃ“"}');
      } else {
        debugPrint('[boot] rootfs ya instalado en ${rootfs.usrDir}');
      }

      // Instalar paquetes esenciales (vim/python/htop/git) si el rootfs
      // quedÃ³ operativo y aÃºn no estÃ¡n. Los binarios interactivos NO vienen
      // en el bootstrap base â€” este paso los inyecta automÃ¡ticamente.
      if (rootfs.isInstalled) {
        _setupBashrc(rootfs);
        _copyNanorootLib(rootfs);
        await _installEssentials(rootfs);
      }
    } catch (e) {
      debugPrint('[boot] error de bootstrap: $e');
    }
  }

  /// Paquetes esenciales del rootfs (faltan en el bootstrap base).
  /// vim se omite del batch automÃ¡tico porque su data.tar.xz descomprime
  /// ~200MB â€” el heap Flutter+Vulkan no deja espacio. Se instala luego
  /// bajo demanda vÃ­a la terminal.
  static const _essentialPkgs = ['python', 'htop', 'git'];

  /// Instala los paquetes esenciales vÃ­a apt (binario PIE dlopen-able con
  /// nanoroot fakechroot + LD_LIBRARY_PATH del namespace de la app).
  Future<void> _installEssentials(RootfsManager rootfs) async {
    try {
      final shell = ShellExecutor(rootfs: rootfs);
      await shell.init();
      // Verificar cuÃ¡les faltan: usr/bin/<pkg> no existe.
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
      // apt binario es stripped (no exporta "main") â†’ no dlopen-able.
      // El instalador directo (Kotlin) descarga los .deb, resuelve deps y
      // extrae con tar del rootfs via worker. Es lo que apt/dpkg hace por
      // dentro, sin depender del binario.
      final ok = await shell.installPackages(missing);
      debugPrint('[boot] instalador directo: ${ok ? "OK" : "FALLÃ“"}');
      if (ok) {
        debugPrint('[boot] paquetes instalados: ${missing.join(", ")}');
        // Instalar escritorio VNC en segundo plano
        _installDesktop(rootfs);
      }
    } catch (e) {
      debugPrint('[boot] install essentials fallÃ³: $e');
    }
  }

  Future<void> _installDesktop(RootfsManager rootfs) async {
    try {
      final xvnc = File('${rootfs.usrDir}/bin/Xvnc');
      if (xvnc.existsSync()) {
        debugPrint('[boot] escritorio ya instalado');
        // Auto-start VNC server so desktop button connects instantly
        final shell = ShellExecutor(rootfs: rootfs);
        await shell.init();
        final port = await shell.startVnc();
        debugPrint('[boot] VNC server en puerto $port');
        // Auto-navegar al escritorio visual
        AppRouter.router.go('/desktop');
        return;
      }
      debugPrint('[boot] instalando escritorio VNC (tigervnc+openbox+xterm)...');
      final shell = ShellExecutor(rootfs: rootfs);
      await shell.init();
      final ok = await shell.installGraphical();
      debugPrint('[boot] escritorio: ${ok ? "OK" : "FALLÃ“"}');
      if (ok) {
        final port = await shell.startVnc();
        debugPrint('[boot] VNC server en puerto $port');
        AppRouter.router.go('/desktop');
      }
    } catch (e) {
      debugPrint('[boot] escritorio fallÃ³: $e');
    }
  }

  /// Crea ~/.bashrc con aliases y configuraciÃ³n si no existe.
  void _setupBashrc(RootfsManager rootfs) {
    final usr = rootfs.usrDir; if (usr == null) return;
    final homeDir = Directory('${File(usr).parent.path}/home');
    if (!homeDir.existsSync()) homeDir.createSync(recursive: true);
    final bashrc = File('${homeDir.path}/.bashrc');
    if (bashrc.existsSync()) return;
    bashrc.writeAsStringSync(r'''
# NanoAI Terminal â€” .bashrc
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

  /// Copia libnanoroot.so al rootfs para que LD_PRELOAD funcione via linker64.
  /// La librerÃ­a estÃ¡ en el APK (jniLibs) pero no en el filesystem del rootfs.
  void _copyNanorootLib(RootfsManager rootfs) {
    try {
      final dst = File('${rootfs.usrDir}/lib/libnanoroot.so');
      if (dst.existsSync()) return;
      // libnanoroot.so se copia via Gradle build task o manualmente.
      // La librerÃ­a estÃ¡ en el APK pero no en el filesystem del rootfs.
      debugPrint('[boot] libnanoroot.so no encontrado en rootfs â€” copia manual requerida');
    } catch (e) {
      debugPrint('[boot] copy libnanoroot fallÃ³: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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

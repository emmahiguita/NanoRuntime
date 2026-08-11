/// Constructor único del entorno Termux-style del rootfs.
///
/// Fuente de verdad única para HOME/PREFIX/PATH/LD_LIBRARY_PATH/TERMUX_* y el
/// bloque LD_PRELOAD+NANO_ROOTFS. Los tres consumidores históricos
/// (ShellExecutor._linuxEnv, TerminalDependencies.rootfsEnv y _TermState)
/// definían el mismo mapa por separado con diferencias finas (p. ej. el
/// TERMUX_APP__PID salía hardcodeado a '0' en un sitio y real en otro).
/// Centralizarlos aquí evita drift: cualquier variable nueva se añade una vez
/// y todos los caminos de ejecución (PTY, ash, apt, pkg, worker) la reciben.
///
/// Semántica de [base]: directorio padre de `usr` (files/nano/). Se usa para
/// HOME y TERMUX_HOME, que viven fuera del PREFIX.
class RootfsEnv {
  const RootfsEnv._();

  /// Parámetros:
  ///  - [usr]: path absoluto al PREFIX del rootfs (…/files/nano/usr).
  ///  - [base]: path absoluto a files/nano/ (padre de usr).
  ///  - [ldPreload]: si se pasa ("libnanoroot.so"), añade LD_PRELOAD y
  ///    NANO_ROOTFS (redirección de rutas hardcodeadas del binario).
  ///  - [extra]: pares adicionales que pisan cualquier valor anterior.
  ///  - [appPid]: PID del proceso Dart (TERMUX_APP__PID). Null → '0'.
  static Map<String, String> build({
    required String usr,
    required String base,
    String? ldPreload,
    Map<String, String>? extra,
    int? appPid,
  }) {
    return {
      // ── Termux estándar ──
      'HOME': '$base/home',
      'PREFIX': usr,
      'PATH': '$usr/bin:$usr/bin/applets:/system/bin:/system/xbin',
      'LD_LIBRARY_PATH': '$usr/lib',
      'TMPDIR': '$usr/tmp',
      'SHELL': '$usr/bin/bash',
      'TERM': 'xterm-256color',
      'LANG': 'en_US.UTF-8',
      // ── Identidad Termux (apt/pkg los checan) ──
      'TERMUX': 'true',
      'TERMUX_PREFIX': usr,
      'TERMUX_HOME': '$base/home',
      'TERMUX_VERSION': '0.118.0',
      'TERMUX_APP__PID': '${appPid ?? 0}',
      'TERMUX_APK_RELEASE': 'F_DROID',
      'TERMUX_APP__IS_DEBUGGABLE': 'false',
      // ── Puente Android ──
      'ANDROID_DATA': '/data',
      'ANDROID_ROOT': '/system',
      // ── Fakechroot / redirección de rutas ──
      if (ldPreload != null && ldPreload.isNotEmpty) 'LD_PRELOAD': ldPreload,
      if (ldPreload != null && ldPreload.isNotEmpty) 'NANO_ROOTFS': usr,
      if (extra != null) for (final e in extra.entries) e.key: e.value,
    };
  }
}
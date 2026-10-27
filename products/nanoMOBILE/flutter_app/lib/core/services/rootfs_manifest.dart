part of 'rootfs_manager.dart';

/// LINUX-PROD-01 — NanoRootfsManifest: rootfs PINNED (nunca 'latest').
///
/// Un bootstrap upstream nuevo puede romper paths, linker, TERMUX_*, X11 o
/// el escritorio sin aviso. En producción Nano instala EXACTAMENTE este
/// release: tag + URL + SHA-256 verificados (hash del asset publicado,
/// re-verificado por descarga local al fijar el pin). El pin solo cambia con
/// un commit deliberado (bump + validación física), jamás por lo que
/// upstream publique hoy.
///
/// Escape hatch: en builds DEBUG (kDebugMode) se permite seguir el release
/// 'latest' dinámico para desarrollo; en release la constante pinned es la
/// ÚNICA ruta (fail-closed: sin red o hash distinto = instalación abortada).
class NanoRootfsManifest {
  /// Release exacto fijado (asset verificado el 2026-09-05).
  static const String bootstrapTag = 'bootstrap-2026.08.30-r1+apt.android-7';

  /// ABI soportada por este pin (el bootstrap de Nano es aarch64).
  static const String abi = 'aarch64';

  /// SHA-256 del asset bootstrap-aarch64.zip del tag fijado (verificado por
  /// descarga local + Get-FileHash al fijar; minúsculas).
  static const String bootstrapSha256 =
      '7e92f4c435d16207cdda63d5629e666ab98441f09eefa6a8423037ef13263346';

  /// URL del asset EXACTO (tag en el path, jamás /latest/ en release).
  static const String bootstrapUrl =
      'https://github.com/termux/termux-packages/releases/download/'
      '$bootstrapTag/bootstrap-aarch64.zip';

  /// Versionado de compatibilidad del pin (paths/linker/X11 del rootfs).
  static const int compatibilityVersion = 1;

  /// Android mínimo requerido por el pin (linker namespaces del proyecto).
  static const String minimumAndroidSdk = '26';

  /// true SOLO en debug: seguir 'latest' dinámico. En release siempre false
  /// (constante: el tree-shaker elimina la rama dinámica).
  static bool get allowDynamicLatestInDebug => kDebugMode;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/package_service.dart';
import 'package:nanoai/core/services/rootfs_manager.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Pantalla de control y lanzamiento del escritorio Linux.
///
/// Incluye:
/// - Temporizador/CronÃ³metro en vivo (`00:01`, `00:02`...) para medir el tiempo de arranque.
/// - Barra de progreso animada con etapas (25%, 50%, 75%, 100%).
/// - TransiciÃ³n automÃ¡tica e inmediata al visor grÃ¡fico (/desktop/vnc) en cuanto Xvnc responde.
class DesktopLaunchScreen extends ConsumerStatefulWidget {
  const DesktopLaunchScreen({super.key});

  @override
  ConsumerState<DesktopLaunchScreen> createState() =>
      _DesktopLaunchScreenState();
}

class _DesktopLaunchScreenState extends ConsumerState<DesktopLaunchScreen> {
  final RootfsManager _rootfs = RootfsManager.instance;
  final PackageService _pkg = const PackageService();
  Timer? _probeTimer;
  Timer? _stopwatchTimer;

  bool _busy = false;
  bool _rootfsReady = false;
  bool _desktopReady = false;
  bool _killedByOs = false;
  int _port = 5901;
  double _progress = 0.0;
  int _elapsedSeconds = 0;

  String _status = 'Comprobando entorno Linux';
  String _detail = 'Verificando archivos rootfs y puerto Xvnc local.';
  String _stageLabel = 'Inicializando';

  @override
  void initState() {
    super.initState();
    _refresh();
    _probeTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _probeOnly(),
    );
  }

  @override
  void dispose() {
    _probeTimer?.cancel();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  void _startStopwatch() {
    _elapsedSeconds = 0;
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _stopStopwatch() {
    _stopwatchTimer?.cancel();
  }

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final rootfsReady = await _rootfs.checkInstalled();
      final desktopStatus = await _pkg.getDesktopStatus();
      if (!mounted) return;
      setState(() {
        _rootfsReady = rootfsReady;
        _applyDesktopStatus(desktopStatus);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error al comprobar entorno';
          _detail = '$e';
        });
      }
    }
  }

  Future<void> _probeOnly() async {
    if (!mounted || _busy) return;
    final desktopStatus = await _pkg.getDesktopStatus();
    if (!mounted) return;
    setState(() => _applyDesktopStatus(desktopStatus));
  }

  void _applyDesktopStatus(DesktopStatus desktopStatus) {
    if (desktopStatus.port > 0) _port = desktopStatus.port;
    _desktopReady = desktopStatus.reachable;

    // U-10: kill del OS — el runtime anterior murió en segundo plano
    // (ahorro de batería de ColorOS). Aviso honesto: nada se perdió.
    // Se limpia solo cuando el runtime vuelve a estar corriendo o el
    // usuario detiene explícitamente (ack implícito en stop()).
    _killedByOs = desktopStatus.wasKilledByOs && !desktopStatus.running;

    if (desktopStatus.failed) {
      // Etapa real del backend en fallo â€” el error viene de Xvnc/watchdog,
      // no de un timeout inventado.
      _status = 'Fallo al arrancar el escritorio';
      _detail =
          desktopStatus.lastError ??
          'El backend grÃ¡fico reportÃ³ un error. Revisa el log.';
      _stageLabel = 'Error';
      _progress = 0.0;
      return;
    }

    if (_desktopReady) {
      _status = 'Escritorio Linux activo';
      _detail = 'Desktop listo en 127.0.0.1:$_port. Puedes abrir el visor.';
      _stageLabel = 'Listo (100%)';
      _progress = 1.0;
      return;
    }

    // Etapas reales reportadas por DesktopSessionManager (idle/starting/
    // xvnc/rfb/wm/ready) â€” en vez de porcentajes inventados.
    switch (desktopStatus.stage) {
      case 'starting':
      case 'xvnc':
        _status = 'Iniciando servidor Xvnc';
        _detail = 'Lanzando backend grÃ¡fico nativo...';
        _stageLabel = 'Xvnc (60%)';
        _progress = 0.6;
        return;
      case 'rfb':
        _status = 'Esperando handshake RFB';
        _detail = 'Verificando que Xvnc responde en el puerto $_port...';
        _stageLabel = 'RFB (75%)';
        _progress = 0.75;
        return;
      case 'wm':
        _status = 'Iniciando entorno de escritorio';
        _detail = 'Arrancando openbox y tint2...';
        _stageLabel = 'Entorno (90%)';
        _progress = 0.9;
        return;
      case 'ready':
        _status = 'Xvnc listo';
        _detail = 'Conectando visor...';
        _stageLabel = 'Conectando (95%)';
        _progress = 0.95;
        return;
    }

    if (desktopStatus.installed) {
      _status = 'Rootfs y X11 listos';
      _detail = 'Toca "Entrar al Escritorio" para iniciar Xvnc y Openbox.';
      _stageLabel = 'Preparado (50%)';
      _progress = 0.5;
      return;
    }

    if (_rootfsReady) {
      _status = 'Rootfs listo';
      _detail =
          'Faltan paquetes X11. El arranque los instalarÃ¡ automÃ¡ticamente.';
      _stageLabel = 'Rootfs (25%)';
      _progress = 0.25;
      return;
    }

    _status = 'Rootfs pendiente';
    _detail = 'Toca "Entrar al Escritorio" para instalar e iniciar.';
    _stageLabel = 'Pendiente (0%)';
    _progress = 0.0;
  }

  /// Inicia la preparaciÃ³n con animaciones de tiempo y progreso, y navega automÃ¡ticamente al visor.
  Future<void> _prepareStartAndEnter() async {
    if (_busy) return;

    if (_desktopReady) {
      _openVisor();
      return;
    }

    _startStopwatch();
    setState(() {
      _busy = true;
      _progress = 0.15;
      _stageLabel = 'Verificando Rootfs';
      _status = 'Preparando entorno Linux';
      _detail = 'Verificando estructura de archivos e Ã­ndices nativos...';
    });

    try {
      _rootfsReady = await _rootfs.checkInstalled();
      if (!_rootfsReady) {
        setState(() {
          _progress = 0.30;
          _stageLabel = 'Instalando Bootstrap';
          _status = 'Descargando Rootfs';
          _detail =
              'Extrayendo paquetes de Termux en almacenamiento interno...';
        });
        _rootfsReady = await _rootfs.install();
      }

      if (!_rootfsReady) {
        _stopStopwatch();
        setState(() {
          _progress = 0.0;
          _status = 'Rootfs no instalado';
          _detail =
              'No se pudo instalar el rootfs. Revisa red y almacenamiento.';
        });
        return;
      }

      // #20: instalar el set grÃ¡fico SOLO si falta â€” antes cada click (y cada
      // boot vÃ­a boot_orchestrator) relanzaba installGraphical() completo.
      // graphicalExtras cubre los extras nuevos (dbus/pcmanfm/feh/mousepad):
      // el instalador es idempotente y salta todo lo ya registrado en dpkg.
      final statusBefore = await _pkg.getDesktopStatus();
      if (!statusBefore.installed || !statusBefore.graphicalExtras) {
        setState(() {
          _progress = 0.60;
          _stageLabel = 'Entorno GrÃ¡fico';
          _status = 'Instalando Paquetes X11';
          _detail = 'Descargando Xvnc, Openbox, tint2 y dependencias...';
        });
        final installed = await _pkg.installGraphical();
        if (!installed) {
          _stopStopwatch();
          setState(() {
            _progress = 0.0;
            _status = 'Entorno grÃ¡fico incompleto';
            _detail = 'Faltan paquetes del entorno grÃ¡fico. Reintenta.';
          });
          return;
        }
      }

      setState(() {
        _progress = 0.85;
        _stageLabel = 'Iniciando VNC';
        _status = 'Iniciando Servidor VNC';
        _detail = 'Arrancando Xvnc y Openbox...';
      });

      // Xvnc arranca con el password VNC persistido (Ajustes â†’ Escritorio).
      // VacÃ­o = SecurityTypes None (sin auth), como siempre.
      // D-1: framebuffer con el aspect del viewport (cap 1920 en backend).
      // U-9: sizeOf devuelve dp lÃ³gicos; el backend espera pÃ­xeles fÃ­sicos
      // (ver vnc_screen.dart â€” mismo fix). Sin el factor, Xvnc en 360x800.
      if (!mounted) return;
      final viewport = MediaQuery.sizeOf(context);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      await _pkg.startDesktop(
        vncPassword: ref.read(settingsProvider).vncPassword,
        width: (viewport.width * dpr).round(),
        height: (viewport.height * dpr).round(),
      );

      // startDesktop responde cuando el backend reporta onReady (puerto RFB
      // abierto) o lanza PlatformException(desktop_failed) si Xvnc falla.
      // Sin polling extra: el visor VNC maneja cualquier carrera residual
      // con su propia reconexiÃ³n exponencial.
      _stopStopwatch();

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _stageLabel = 'VNC Listo';
        });
        context.pushReplacement('/desktop/vnc?port=$_port');
      }
    } catch (e) {
      _stopStopwatch();
      // El error real del backend (si existe) llega vÃ­a DesktopStatus.
      var detail = '$e';
      try {
        final failedStatus = await _pkg.getDesktopStatus();
        if (failedStatus.failed && failedStatus.lastError != null) {
          detail = failedStatus.lastError!;
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _progress = 0.0;
          _status = 'Fallo al arrancar escritorio';
          _detail = detail;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Deteniendo escritorio';
      _detail = 'Cerrando servidor Xvnc y gestor de ventanas...';
    });
    try {
      await _pkg.stopDesktop();
      await Future.delayed(const Duration(milliseconds: 500));
      final desktopStatus = await _pkg.getDesktopStatus();
      if (mounted) _applyDesktopStatus(desktopStatus);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openVisor() {
    // Visor VNC interno (RFB 3.8 sobre Xvnc :1). El visor tiene su propio
    // auto-arranque resiliente (_ensureDesktopStarted): si el puerto no
    // responde, instala rootfs y lanza Xvnc/Openbox Ã©l mismo. AquÃ­ solo
    // navegamos â€” sin duplicar el flujo de preparaciÃ³n del botÃ³n principal.
    context.pushReplacement('/desktop/vnc?port=$_port');
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final bg = colors.background;
    final mobileMode = ref.watch(settingsProvider).desktopMobileMode;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            children: [
              _TopBar(colors: colors, onBack: () => context.pop()),
              const SizedBox(height: 12),
              _HeroCard(
                colors: colors,
                busy: _busy,
                vncReady: _desktopReady,
                status: _status,
                detail: _detail,
                stageLabel: _stageLabel,
                progress: _progress,
                formattedTime: _formattedTime,
                onEnter: _prepareStartAndEnter,
                onDirectVisor: _openVisor,
              ),
              const SizedBox(height: 12),
              if (_killedByOs) ...[
                _KillRestoreBanner(colors: colors),
                const SizedBox(height: 12),
              ],
              if (!mobileMode)
                _StatusBadges(
                  colors: colors,
                  rootfsReady: _rootfsReady,
                  vncReady: _desktopReady,
                  port: _port,
                  formattedTime: _formattedTime,
                  busy: _busy,
                ),
              const SizedBox(height: 12),
              if (!mobileMode)
                _ActionGrid(
                  colors: colors,
                  busy: _busy,
                  vncReady: _desktopReady,
                  onEnter: _prepareStartAndEnter,
                  onDirectVisor: _openVisor,
                  onStop: _stop,
                  onTerminal: () => context.go('/terminal'),
                ),
              const SizedBox(height: 12),
              _InfoSection(colors: colors),
              if (mobileMode) ...[
                const SizedBox(height: 12),
                _CompactMobileHint(colors: colors),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// U-10: aviso honesto de restauración tras un cached-kill del OS.
class _KillRestoreBanner extends StatelessWidget {
  final NanoColors colors;

  const _KillRestoreBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.restore_rounded, color: colors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El sistema operativo cerró el escritorio en segundo plano '
              '(ahorro de batería). Nada se perdió: toca arrancar para '
              'restaurarlo limpio.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final NanoColors colors;
  final VoidCallback onBack;

  const _TopBar({required this.colors, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          tooltip: 'Volver',
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escritorio Linux',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            Text(
              'Xvnc + Openbox + Terminal GrÃ¡fica',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final NanoColors colors;
  final bool busy;
  final bool vncReady;
  final String status;
  final String detail;
  final String stageLabel;
  final double progress;
  final String formattedTime;
  final VoidCallback onEnter;
  final VoidCallback onDirectVisor;

  const _HeroCard({
    required this.colors,
    required this.busy,
    required this.vncReady,
    required this.status,
    required this.detail,
    required this.stageLabel,
    required this.progress,
    required this.formattedTime,
    required this.onEnter,
    required this.onDirectVisor,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = colors.surface;
    final accentColor = vncReady
        ? colors.success
        : (busy ? colors.info : colors.primary);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  vncReady
                      ? Icons.desktop_windows_rounded
                      : (busy ? Icons.sync_rounded : Icons.computer_rounded),
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          status,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                        if (busy)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 12,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Barra de progreso animada con porcentaje y etiqueta de etapa
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stageLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  tween: Tween<double>(begin: 0, end: progress),
                  builder: (context, val, _) {
                    return LinearProgressIndicator(
                      value: busy ? null : val,
                      backgroundColor: accentColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 8,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: busy ? null : onEnter,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      vncReady
                          ? Icons.launch_rounded
                          : Icons.play_arrow_rounded,
                      size: 22,
                    ),
              label: Text(
                vncReady
                    ? 'Entrar al Escritorio Linux'
                    : 'Arrancar e Iniciar Escritorio',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadges extends StatelessWidget {
  final NanoColors colors;
  final bool rootfsReady;
  final bool vncReady;
  final int port;
  final String formattedTime;
  final bool busy;

  const _StatusBadges({
    required this.colors,
    required this.rootfsReady,
    required this.vncReady,
    required this.port,
    required this.formattedTime,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BadgeItem(
            label: 'Rootfs Linux',
            value: rootfsReady ? 'Instalado' : 'Pendiente',
            ok: rootfsReady,
            icon: Icons.folder_zip_rounded,
            colors: colors,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BadgeItem(
            label: busy ? 'Tiempo Transcurrido' : 'Servidor Xvnc',
            value: busy
                ? formattedTime
                : (vncReady ? 'Puerto $port' : 'Detenido'),
            ok: vncReady || busy,
            icon: busy ? Icons.timer_rounded : Icons.dns_rounded,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;
  final IconData icon;
  final NanoColors colors;

  const _BadgeItem({
    required this.label,
    required this.value,
    required this.ok,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final bg = colors.surface;
    final statusColor = ok ? colors.success : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final NanoColors colors;
  final bool busy;
  final bool vncReady;
  final VoidCallback onEnter;
  final VoidCallback onDirectVisor;
  final VoidCallback onStop;
  final VoidCallback onTerminal;

  const _ActionGrid({
    required this.colors,
    required this.busy,
    required this.vncReady,
    required this.onEnter,
    required this.onDirectVisor,
    required this.onStop,
    required this.onTerminal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDirectVisor,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text(
                  'Abrir Visor Directo',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onStop,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: colors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                label: const Text(
                  'Detener Xvnc',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onTerminal,
            icon: const Icon(Icons.terminal_rounded, size: 18),
            label: const Text(
              'Ir a Terminal CLI',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactMobileHint extends StatelessWidget {
  final NanoColors colors;

  const _CompactMobileHint({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.smartphone_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo móvil activo: la pantalla prioriza el visor y reduce acciones repetidas.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final NanoColors colors;

  const _InfoSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Xvnc interno proyecta Openbox en el puerto 5901 vÃ­a RFB 3.8. '
              'El visor integrado muestra el escritorio en tiempo real con control tÃ¡ctil y teclado.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

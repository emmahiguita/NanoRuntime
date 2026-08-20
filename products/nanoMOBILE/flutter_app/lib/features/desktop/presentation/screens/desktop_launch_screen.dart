import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/services/package_service.dart';
import 'package:nanoai/core/services/rootfs_manager.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';

/// Pantalla de control y lanzamiento del escritorio Linux (White Optical Glass + M3 Motion).
///
/// Incluye:
/// - Temporizador/Cronómetro en vivo (`00:01`, `00:02`...) para medir el tiempo de arranque.
/// - Barra de progreso animada con etapas (25%, 50%, 75%, 100%).
/// - Transición automática e inmediata al visor gráfico (/desktop/vnc) en cuanto Xvnc responde.
/// - Superficies ópticas translúcidas multicapa y biseles metálicos.
class DesktopLaunchScreen extends ConsumerStatefulWidget {
  const DesktopLaunchScreen({super.key});

  @override
  ConsumerState<DesktopLaunchScreen> createState() =>
      _DesktopLaunchScreenState();
}

class _DesktopLaunchScreenState extends ConsumerState<DesktopLaunchScreen>
    with SingleTickerProviderStateMixin {
  final RootfsManager _rootfs = RootfsManager.instance;
  final PackageService _pkg = const PackageService();
  Timer? _probeTimer;
  Timer? _stopwatchTimer;
  late final AnimationController _reflectionController;

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
    _reflectionController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.ambient,
    )..repeat();

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
    _reflectionController.dispose();
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

    _killedByOs = desktopStatus.wasKilledByOs && !desktopStatus.running;

    if (desktopStatus.failed) {
      _status = 'Fallo al arrancar el escritorio';
      _detail =
          desktopStatus.lastError ??
          'El backend gráfico reportó un error. Revisa el log.';
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

    switch (desktopStatus.stage) {
      case 'starting':
      case 'xvnc':
        _status = 'Iniciando servidor Xvnc';
        _detail = 'Lanzando backend gráfico nativo...';
        _stageLabel = 'Xvnc (60%)';
        _progress = 0.6;
        return;
      case 'rfb':
        _status = 'Esperando handshake RFB';
        _detail = 'Verificando que Xvnc responde en el puerto $_port...';
        _stageLabel = 'RFB (80%)';
        _progress = 0.8;
        return;
      case 'wm':
        _status = 'Iniciando gestor Openbox';
        _detail = 'Cargando entorno gráfico y panel...';
        _stageLabel = 'Openbox (90%)';
        _progress = 0.9;
        return;
      case 'idle':
      default:
        if (_rootfsReady) {
          _status = 'Escritorio Linux listo para arrancar';
          _detail = 'Rootfs instalado. Toca el botón para iniciar sesión Xvnc.';
          _stageLabel = 'Listo para inicio';
          _progress = 0.0;
        } else {
          _status = 'Entorno Linux no instalado';
          _detail =
              'El rootfs de Kali Linux se instalará automáticamente antes de arrancar.';
          _stageLabel = 'Requiere instalación';
          _progress = 0.0;
        }
        return;
    }
  }

  Future<void> _prepareStartAndEnter() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0.10;
      _stageLabel = 'Iniciando...';
      _status = 'Preparando entorno';
      _detail = 'Comprobando estado previo y liberando recursos...';
    });

    _startStopwatch();

    try {
      if (!_rootfsReady) {
        setState(() {
          _progress = 0.25;
          _stageLabel = 'Instalando Rootfs';
          _status = 'Instalando Entorno Linux';
          _detail = 'Extrayendo sistema base (puede tardar unos segundos)...';
        });
        final ok = await _rootfs.install();
        if (!ok) {
          _stopStopwatch();
          if (mounted) {
            setState(() {
              _progress = 0.0;
              _status = 'Fallo en la instalación';
              _detail = 'No se pudo instalar el rootfs. Revisa el espacio libre.';
            });
          }
          return;
        }
        _rootfsReady = true;
      }

      setState(() {
        _progress = 0.50;
        _stageLabel = 'Verificando paquetes';
        _status = 'Comprobando Entorno Gráfico';
        _detail = 'Verificando paquetes X11, Openbox y utilidades...';
      });

      final desktopStatus = await _pkg.getDesktopStatus();
      if (!desktopStatus.graphicalExtras) {
        setState(() {
          _progress = 0.65;
          _stageLabel = 'Instalando extras';
          _status = 'Instalando Paquetes Gráficos';
          _detail = 'Instalando paquetes gráficos esenciales...';
        });
        final installed = await _pkg.installGraphical();
        if (!installed && mounted) {
          _stopStopwatch();
          setState(() {
            _progress = 0.0;
            _status = 'Entorno gráfico incompleto';
            _detail = 'Faltan paquetes del entorno gráfico. Reintenta.';
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

      if (!mounted) return;
      final viewport = MediaQuery.sizeOf(context);
      final dpr = MediaQuery.devicePixelRatioOf(context);
      await _pkg.startDesktop(
        vncPassword: ref.read(settingsProvider).vncPassword,
        width: (viewport.width * dpr).round(),
        height: (viewport.height * dpr).round(),
      );

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
    context.pushReplacement('/desktop/vnc?port=$_port');
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final mobileMode = ref.watch(settingsProvider).desktopMobileMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        }
      },
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Stack(
          children: [
            const Positioned.fill(
              child: NanoAmbientBackground(),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _TopBar(
                        colors: colors,
                        onBack: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                      ),
                    const SizedBox(height: 16),
                    _HeroCard(
                      colors: colors,
                      busy: _busy,
                      vncReady: _desktopReady,
                      status: _status,
                      detail: _detail,
                      stageLabel: _stageLabel,
                      progress: _progress,
                      formattedTime: _formattedTime,
                      reflectionController: _reflectionController,
                      onEnter: _prepareStartAndEnter,
                      onDirectVisor: _openVisor,
                    ),
                    const SizedBox(height: 14),
                    if (_killedByOs) ...[
                      _KillRestoreBanner(colors: colors),
                      const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
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
                    const SizedBox(height: 14),
                    _InfoSection(colors: colors),
                    if (mobileMode) ...[
                      const SizedBox(height: 14),
                      _CompactMobileHint(colors: colors),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}

// =============================================================
// HEADER TOP BAR (OPTICAL GLASS)
// =============================================================

class _TopBar extends StatelessWidget {
  final NanoColors colors;
  final VoidCallback onBack;

  const _TopBar({required this.colors, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NanoOpticalSurface(
          geometry: NanoSurfaceGeometry.circle,
          blurSigma: 10,
          borderStrength: 0.65,
          reflectionStrength: 0.50,
          accent: colors.accentSky,
          onTap: onBack,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.65, 0.85, 1.0],
                    colors: [
                      colors.textPrimary,
                      colors.textPrimary,
                      colors.accentSky,
                      colors.accentCyan,
                    ],
                  ).createShader(rect);
                },
                child: const Text(
                  'Escritorio Linux',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Xvnc + Openbox + Terminal Gráfica',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================
// HERO CARD (WHITE OPTICAL GLASS)
// =============================================================

class _HeroCard extends StatelessWidget {
  final NanoColors colors;
  final bool busy;
  final bool vncReady;
  final String status;
  final String detail;
  final String stageLabel;
  final double progress;
  final String formattedTime;
  final AnimationController reflectionController;
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
    required this.reflectionController,
    required this.onEnter,
    required this.onDirectVisor,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = vncReady
        ? colors.accentMint
        : (busy ? colors.accentCyan : colors.accentSky);

    return RepaintBoundary(
      child: NanoOpticalSurface(
        borderRadius: NanoRadius.large,
        blurSigma: 18,
        borderStrength: 0.90,
        reflectionStrength: 0.90,
        accent: accentColor,
        reflectionController: reflectionController,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NanoOpticalSurface(
                  geometry: NanoSurfaceGeometry.circle,
                  blurSigma: 10,
                  borderStrength: 0.65,
                  reflectionStrength: 0.60,
                  accent: accentColor,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      vncReady
                          ? Icons.desktop_windows_rounded
                          : (busy ? Icons.sync_rounded : Icons.computer_rounded),
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: NanoMotionDurations.quick,
                              child: Text(
                                status,
                                key: ValueKey(status),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ),
                          if (busy) const SizedBox(width: 8),
                          if (busy)
                            NanoOpticalSurface(
                              geometry: NanoSurfaceGeometry.capsule,
                              blurSigma: 10,
                              borderStrength: 0.60,
                              reflectionStrength: 0.40,
                              accent: accentColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.0,
                          color: colors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barra de progreso animada
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
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 7,
                    color: colors.metalSilver.withValues(alpha: 0.45),
                    child: TweenAnimationBuilder<double>(
                      duration: NanoMotionDurations.standard,
                      curve: NanoMotionCurves.standardDecel,
                      tween: Tween<double>(begin: 0, end: progress),
                      builder: (context, val, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: busy ? null : val.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: LinearGradient(
                                colors: [accentColor, colors.accentCyan],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            NanoOpticalSurface(
              borderRadius: NanoRadius.medium,
              blurSigma: 14,
              borderStrength: 0.85,
              reflectionStrength: 0.70,
              accent: accentColor,
              onTap: busy ? null : onEnter,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: colors.textPrimary,
                        ),
                      )
                    else
                      Icon(
                        vncReady
                            ? Icons.launch_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: colors.textPrimary,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      vncReady
                          ? 'Entrar al Escritorio Linux'
                          : 'Arrancar e Iniciar Escritorio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// STATUS BADGES
// =============================================================

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
            label: busy ? 'Tiempo' : 'Servidor Xvnc',
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
    final statusColor = ok ? colors.accentMint : colors.textSecondary;

    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      blurSigma: 14,
      borderStrength: 0.65,
      reflectionStrength: 0.45,
      accent: ok ? colors.accentMint : colors.accentSky,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    letterSpacing: -0.2,
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

// =============================================================
// ACTION GRID
// =============================================================

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
              child: NanoOpticalSurface(
                borderRadius: NanoRadius.medium,
                blurSigma: 14,
                borderStrength: 0.65,
                reflectionStrength: 0.50,
                accent: colors.accentSky,
                onTap: onDirectVisor,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 18, color: colors.textPrimary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Visor Directo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NanoOpticalSurface(
                borderRadius: NanoRadius.medium,
                blurSigma: 14,
                borderStrength: 0.65,
                reflectionStrength: 0.50,
                accent: colors.error,
                onTap: busy ? null : onStop,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 18, color: colors.error),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Detener Xvnc',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        NanoOpticalSurface(
          borderRadius: NanoRadius.medium,
          blurSigma: 12,
          borderStrength: 0.50,
          reflectionStrength: 0.35,
          accent: colors.accentCyan,
          onTap: onTerminal,
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.terminal_rounded, size: 18, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Ir a Terminal CLI',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================
// INFO & BANNER SECTIONS
// =============================================================

class _KillRestoreBanner extends StatelessWidget {
  final NanoColors colors;
  const _KillRestoreBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      blurSigma: 14,
      borderStrength: 0.70,
      reflectionStrength: 0.40,
      accent: colors.warning,
      padding: const EdgeInsets.all(14),
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
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMobileHint extends StatelessWidget {
  final NanoColors colors;
  const _CompactMobileHint({required this.colors});

  @override
  Widget build(BuildContext context) {
    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      blurSigma: 14,
      borderStrength: 0.60,
      reflectionStrength: 0.35,
      accent: colors.accentSky,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.smartphone_rounded, color: colors.accentSky, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo móvil activo: la pantalla prioriza el visor y reduce acciones repetidas.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.35,
                color: colors.textSecondary,
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
    return NanoOpticalSurface(
      borderRadius: NanoRadius.medium,
      blurSigma: 14,
      borderStrength: 0.50,
      reflectionStrength: 0.30,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Xvnc interno proyecta Openbox en el puerto 5901 vía RFB 3.8. '
              'El visor integrado muestra el escritorio en tiempo real con control táctil y teclado.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

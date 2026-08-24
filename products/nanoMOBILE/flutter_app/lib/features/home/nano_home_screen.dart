import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';

import 'nano_home_models.dart';

// =============================================================
// NANO HOME SCREEN (UNIVERSAL WHITE OPTICAL METAL GLASS + MOTION)
// =============================================================

class NanoHomeScreen extends StatefulWidget {
  final NanoTelemetryData telemetry;
  final KaliStatus kaliStatus;
  final String? chatSubtitle;
  final String? terminalSubtitle;

  final VoidCallback onTerminalTap;
  final VoidCallback onChatTap;
  final VoidCallback onModelsTap;
  final VoidCallback? onDesktopTap;
  final VoidCallback? onAutomationTap;
  final VoidCallback onKaliTap;

  /// Estados EN VIVO reales (providers) para los indicadores pulsantes.
  final bool chatOn;
  final bool termOn;
  final bool modelOn;

  const NanoHomeScreen({
    super.key,
    required this.telemetry,
    required this.kaliStatus,
    this.chatSubtitle,
    this.terminalSubtitle,
    required this.onTerminalTap,
    required this.onChatTap,
    required this.onModelsTap,
    this.onDesktopTap,
    this.onAutomationTap,
    required this.onKaliTap,
    this.chatOn = false,
    this.termOn = false,
    this.modelOn = false,
  });

  @override
  State<NanoHomeScreen> createState() => _NanoHomeScreenState();
}

class _NanoHomeScreenState extends State<NanoHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  late final AnimationController _reflectionController;
  late final AnimationController _entryController;
  int _currentPage = 1;
  bool _showTelemetry = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pageController = PageController(initialPage: 1, viewportFraction: 0.66);

    _reflectionController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.ambient,
    );

    // Entrada cinemática escalonada (<450ms)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    )..forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_reflectionController.isAnimating &&
          !MediaQuery.disableAnimationsOf(context)) {
        _reflectionController.repeat();
      }
    } else {
      if (_reflectionController.isAnimating) {
        _reflectionController.stop();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCarouselViewport();
    _syncReflectionAnimation();
  }

  // La reflexión ambiental es decorativa: nunca repite con
  // disableAnimations (accesibilidad, ahorro de batería, tests).
  void _syncReflectionAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_reflectionController.isAnimating) {
        _reflectionController.stop();
      }
    } else if (!_reflectionController.isAnimating) {
      _reflectionController.repeat();
    }
  }

  void _syncCarouselViewport() {
    final size = MediaQuery.sizeOf(context);
    final target = _viewportFractionFor(size);
    if ((target - _pageController.viewportFraction).abs() > 0.001) {
      _pageController.dispose();
      _pageController = PageController(
        initialPage: _currentPage,
        viewportFraction: target,
      );
    }
  }

  double _viewportFractionFor(Size size) {
    final isLandscape = size.width > size.height;
    if (isLandscape) return 0.38;
    return size.width < 360 ? 0.70 : 0.66;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _reflectionController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final terminalSub =
        widget.terminalSubtitle ??
        switch (widget.kaliStatus) {
          KaliStatus.running => 'Linux listo',
          KaliStatus.stopped => 'La sesión está detenida',
          KaliStatus.error => 'No fue posible iniciar Kali',
          KaliStatus.notInitialized ||
          KaliStatus.starting => 'Preparando Linux',
        };
    final chatSub = widget.chatSubtitle ?? 'Habla con';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final maxHeight = constraints.maxHeight;
                final isLandscape = maxWidth > maxHeight;

                if (isLandscape) {
                  // ─────────────────────────────────────────────
                  // COMPOSICIÓN LANDSCAPE HORIZONTAL ADAPTATIVA
                  // ─────────────────────────────────────────────
                  const headerRowHeight = 26.0;
                  final telemetryRowHeight = _showTelemetry ? 46.0 : 34.0;
                  final availableForCarousel =
                      maxHeight -
                      headerRowHeight -
                      4.0 -
                      telemetryRowHeight -
                      12.0;
                  // Sin mínimo forzado: el clamp(150, …) desbordaba el Column
                  // en ventanas paisaje muy bajas (altura < ~238px). La card
                  // escala al espacio real disponible, nunca fuerza overflow.
                  final carouselHeight = availableForCarousel.clamp(0.0, 260.0);

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          math.max(4, media.padding.bottom),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 240),
                              crossFadeState: _showTelemetry
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              firstChild: _TelemetryGlass(
                                ram: widget.telemetry.ram,
                                cpu: widget.telemetry.cpu,
                                temperature: widget.telemetry.temperature,
                                storage: widget.telemetry.freeStorage,
                                battery: widget.telemetry.battery,
                                kaliStatus: widget.kaliStatus,
                                onKaliTap: widget.onKaliTap,
                                compact: true,
                                onCollapse: () =>
                                    setState(() => _showTelemetry = false),
                              ),
                              secondChild: _TelemetryCornerBadge(
                                onExpand: () =>
                                    setState(() => _showTelemetry = true),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  height: carouselHeight,
                                  child: _FeatureCarousel(
                                    controller: _pageController,
                                    reflectionController: _reflectionController,
                                    currentPage: _currentPage,
                                    terminalSubtitle: terminalSub,
                                    chatSubtitle: chatSub,
                                    onPageChanged: (index) {
                                      setState(() => _currentPage = index);
                                    },
                                    onChat: widget.onChatTap,
                                    onTerminal: widget.onTerminalTap,
                                    onModels: widget.onModelsTap,
                                    onDesktop: widget.onDesktopTap,
                    onAutomation: widget.onAutomationTap ?? () {},
                                    chatOn: widget.chatOn,
                                    termOn: widget.termOn,
                                    modelOn: widget.modelOn,
                                    isLandscape: true,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // ─────────────────────────────────────────────
                // COMPOSICIÓN PORTRAIT MOBILE-FIRST
                // ─────────────────────────────────────────────
                final carouselHeight =
                    (_showTelemetry ? (maxHeight * 0.70) : (maxHeight * 0.82))
                        .clamp(300.0, 540.0);
                final horizontalPadding = maxWidth < 360
                    ? 12.0
                    : (maxWidth < 430 ? 16.0 : 20.0);

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        4,
                        horizontalPadding,
                        math.max(12, media.padding.bottom + 8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 240),
                            crossFadeState: _showTelemetry
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: _AnimatedEntrance(
                              controller: _entryController,
                              begin: 0.05,
                              end: 0.40,
                              slideOffset: const Offset(0, -8),
                              child: _TelemetryGlass(
                                ram: widget.telemetry.ram,
                                cpu: widget.telemetry.cpu,
                                temperature: widget.telemetry.temperature,
                                storage: widget.telemetry.freeStorage,
                                battery: widget.telemetry.battery,
                                kaliStatus: widget.kaliStatus,
                                onKaliTap: widget.onKaliTap,
                                compact: true,
                                onCollapse: () =>
                                    setState(() => _showTelemetry = false),
                              ),
                            ),
                            secondChild: _TelemetryCornerBadge(
                              onExpand: () =>
                                  setState(() => _showTelemetry = true),
                            ),
                          ),
                          const Spacer(),
                          _AnimatedEntrance(
                            controller: _entryController,
                            begin: 0.15,
                            end: 0.75,
                            slideOffset: const Offset(0, 16),
                            child: SizedBox(
                              height: carouselHeight,
                              child: _FeatureCarousel(
                                controller: _pageController,
                                reflectionController: _reflectionController,
                                currentPage: _currentPage,
                                terminalSubtitle: terminalSub,
                                chatSubtitle: chatSub,
                                onPageChanged: (index) {
                                  setState(() => _currentPage = index);
                                },
                                onChat: widget.onChatTap,
                                onTerminal: widget.onTerminalTap,
                                onModels: widget.onModelsTap,
                                onDesktop: widget.onDesktopTap,
                    onAutomation: widget.onAutomationTap ?? () {},
                                chatOn: widget.chatOn,
                                termOn: widget.termOn,
                                modelOn: widget.modelOn,
                                isLandscape: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}

// =============================================================
// IDENTIDAD NANOAI + SUPERFICIE KALI (chip honesto de estado)
// =============================================================
// TELEMETRY CON MICRO-MEDIDORES Y TRANSICIONES SUAVES
// =============================================================

class _TelemetryGlass extends StatelessWidget {
  final String ram;
  final String cpu;
  final String temperature;
  final String storage;
  final String battery;
  final KaliStatus? kaliStatus;
  final VoidCallback? onKaliTap;
  final bool compact;
  final VoidCallback? onCollapse;

  const _TelemetryGlass({
    required this.ram,
    required this.cpu,
    required this.temperature,
    required this.storage,
    required this.battery,
    this.kaliStatus,
    this.onKaliTap,
    this.compact = false,
    this.onCollapse,
  });

  Color _statusColor(KaliStatus status, NanoColors colors) {
    switch (status) {
      case KaliStatus.running:
        return colors.accentMint;
      case KaliStatus.starting:
        return colors.accentSky;
      case KaliStatus.stopped:
        return NanoTextColors.forText(colors.warning, colors);
      case KaliStatus.error:
        return NanoTextColors.forText(colors.error, colors);
      case KaliStatus.notInitialized:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    final metrics = [
      _MetricData('RAM', ram, Icons.memory_rounded, colors.accentBlue),
      _MetricData('CPU', cpu, Icons.developer_board_rounded, colors.accentSky),
      _MetricData(
        'TEMP.',
        temperature,
        Icons.thermostat_rounded,
        colors.accentLavender,
      ),
      _MetricData('LIBRE', storage, Icons.storage_rounded, colors.accentSky),
      _MetricData(
        'BATERÍA',
        battery,
        Icons.battery_full_rounded,
        colors.accentMint,
      ),
      if (kaliStatus != null)
        _MetricData(
          'LINUX',
          kaliStatus!.label,
          Icons.terminal_rounded,
          _statusColor(kaliStatus!, colors),
        ),
    ];

    return RepaintBoundary(
      child: NanoOpticalSurface(
        borderRadius: NanoRadius.medium,
        blurSigma: 14,
        borderStrength: 0.65,
        reflectionStrength: 0.45,
        // Firma del módulo automation en el dashboard: tilt 3D (pointer) +
        // barrido especular animado (autoReflect). Seguro: la telemetry card
        // no está en el carousel, así que no reproduce el texto sub-píxel
        // que motivó evitar rotateY en las cards deslizantes.
        tilt: true,
        tiltIntensity: 0.06,
        autoReflect: true,
        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
        child: Row(
          children: [
            for (int i = 0; i < metrics.length; i++) ...[
              Expanded(
                child: metrics[i].label == 'LINUX' && onKaliTap != null
                    ? InkWell(
                        onTap: onKaliTap,
                        borderRadius: BorderRadius.circular(6),
                        child: _Metric(data: metrics[i], compact: true),
                      )
                    : _Metric(data: metrics[i], compact: true),
              ),
              if (i < metrics.length - 1)
                Container(
                  width: 0.8,
                  height: 20,
                  color: colors.metalSilver.withValues(alpha: 0.50),
                ),
            ],
            if (onCollapse != null) ...[
              Container(
                width: 0.8,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: colors.metalSilver.withValues(alpha: 0.50),
              ),
              InkWell(
                onTap: onCollapse,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close_fullscreen_rounded,
                    size: 13,
                    color: colors.textSecondary.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TelemetryCornerBadge extends StatelessWidget {
  final VoidCallback onExpand;
  const _TelemetryCornerBadge({required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        NanoOpticalSurface(
          geometry: NanoSurfaceGeometry.capsule,
          blurSigma: 12,
          borderStrength: 0.70,
          reflectionStrength: 0.50,
          onTap: onExpand,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentMint,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentMint.withValues(alpha: 0.55),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'TELEMETRÍA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_full_rounded,
                size: 11,
                color: colors.accentSky,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _Metric extends StatelessWidget {
  final _MetricData data;
  final bool compact;

  const _Metric({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 15, color: data.color),
          const SizedBox(height: 1),
          Text(
            data.label,
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.textSecondary,
              fontSize: 9.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 1),
          AnimatedSwitcher(
            duration: NanoMotionDurations.quick,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: NanoMotionCurves.standardDecel,
                        ),
                      ),
                  child: child,
                ),
              );
            },
            child: Text(
              data.value,
              key: ValueKey(data.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.textPrimary,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// CAROUSEL CON FÍSICA SPATIAL Y PARALLAX MULTICAPA
// =============================================================

class _FeatureCarousel extends StatelessWidget {
  final PageController controller;
  final AnimationController reflectionController;
  final int currentPage;
  final String terminalSubtitle;
  final String chatSubtitle;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onChat;
  final VoidCallback onTerminal;
  final VoidCallback onModels;
  final VoidCallback? onDesktop;
  final VoidCallback? onAutomation;
  final bool isLandscape;

  /// Estados EN VIVO reales (provider) para el indicador pulsante de cada card.
  final bool chatOn;
  final bool termOn;
  final bool modelOn;

  const _FeatureCarousel({
    required this.controller,
    required this.reflectionController,
    required this.currentPage,
    required this.terminalSubtitle,
    required this.chatSubtitle,
    required this.onPageChanged,
    required this.onChat,
    required this.onTerminal,
    required this.onModels,
    this.onDesktop,
    this.onAutomation,
    this.isLandscape = false,
    this.chatOn = false,
    this.termOn = false,
    this.modelOn = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    final items = [
      NanoFeatureData(
        id: 'chat',
        title: 'Chat',
        line1: chatSubtitle,
        line2: 'NanoAI',
        icon: Icons.chat_bubble_outline_rounded,
        accent: colors.accentLavender,
        secondaryAccent: colors.accentCyan,
        statusColor: chatOn ? colors.success : colors.warning,
        statusLabel: chatOn ? 'EN VIVO' : 'MOTOR APAGADO',
        onTap: onChat,
      ),
      NanoFeatureData(
        id: 'terminal',
        title: 'Terminal',
        line1: 'Accede a tu sistema',
        line2: terminalSubtitle,
        icon: Icons.terminal_rounded,
        accent: colors.accentCyan,
        secondaryAccent: colors.accentMint,
        statusColor: termOn ? colors.success : colors.warning,
        statusLabel: termOn ? 'LINUX LISTO' : 'PREPARANDO LINUX',
        onTap: onTerminal,
      ),
      NanoFeatureData(
        id: 'models',
        title: 'Modelos',
        line1: 'Gestionar y',
        line2: 'ejecutar modelos',
        icon: Icons.view_in_ar_rounded,
        accent: colors.accentBlue,
        secondaryAccent: colors.accentLavender,
        statusColor: modelOn ? colors.success : colors.warning,
        statusLabel: modelOn ? 'MODELO ACTIVO' : 'SIN MODELO',
        onTap: onModels,
      ),
      NanoFeatureData(
        id: 'desktop',
        title: 'Escritorio',
        line1: 'Linux en tu',
        line2: 'pantalla',
        icon: Icons.desktop_windows_rounded,
        accent: colors.accentMint,
        secondaryAccent: colors.accentSky,
        onTap: onDesktop ?? () {},
      ),
      NanoFeatureData(
        id: 'automation',
        title: 'Automatización',
        line1: 'Agente que',
        line2: 'ejecuta acciones',
        icon: Icons.auto_awesome_rounded,
        accent: colors.accentLavender,
        secondaryAccent: colors.accentMint,
        onTap: onAutomation ?? () {},
      ),
    ];

    return RepaintBoundary(
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: const ValueKey('nano-home-carousel'),
              clipBehavior: Clip.none,
              controller: controller,
              itemCount: items.length,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                onPageChanged(index);
              },
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    double page = controller.initialPage.toDouble();
                    if (controller.hasClients &&
                        controller.position.haveDimensions) {
                      page = controller.page ?? page;
                    }

                    final delta = index - page;
                    final distance = delta.abs().clamp(0.0, 1.0);

                    final reduceMotion = NanoMotion.reduceMotion(context);

                    // Coverflow 3D: rotateY por desplazamiento de página.
                    // La card enfocada (delta≈0) queda plana/nítida; las
                    // adyacentes giran con perspectiva suave. El ángulo se
                    // acota (~10°) y las adyacentes ya van atenuadas +escaladas,
                    // evitando el texto sub-píxel del ángulo grande anterior.
                    final scale = reduceMotion ? 1.0 : (1.0 - distance * 0.06);
                    final translationY = reduceMotion
                        ? distance * 2.0
                        : distance * 6.0;
                    final translationX = reduceMotion ? 0.0 : -delta * 4.0;
                    final rotationY = reduceMotion
                        ? 0.0
                        : (-delta.clamp(-1.0, 1.0) * 0.17);
                    final perspective = reduceMotion ? 0.0 : 0.00135;

                    // Desplazamiento cáustico inercial reactivo al gesto
                    final specularDrift = -(page - page.roundToDouble()) * 0.22;

                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, perspective)
                        ..setTranslationRaw(translationX, translationY, 0.0)
                        ..rotateY(rotationY)
                        ..scaleByDouble(scale, scale, 1.0, 1.0),
                      child: Opacity(
                        opacity: (1.0 - distance * 0.16).clamp(0.0, 1.0),
                        child: NanoFeatureCard(
                          key: ValueKey('nano-feature-${items[index].id}'),
                          data: items[index],
                          reflectionController: reflectionController,
                          isLandscape: isLandscape,
                          distance: distance,
                          delta: delta,
                          specularDrift: specularDrift,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _LiquidPageIndicator(
            controller: controller,
            count: items.length,
            current: currentPage,
          ),
        ],
      ),
    );
  }
}

class NanoFeatureData {
  final String id;
  final String title;
  final String line1;
  final String line2;
  final IconData icon;
  final Color accent;
  final Color secondaryAccent;
  final VoidCallback onTap;

  /// Indicador de estado EN VIVO (datos reales del provider) que pulsa.
  /// Vacío/null = no mostrar pill.
  final String statusLabel;
  final Color? statusColor;

  const NanoFeatureData({
    required this.id,
    required this.title,
    required this.line1,
    required this.line2,
    required this.icon,
    required this.accent,
    required this.secondaryAccent,
    required this.onTap,
    this.statusLabel = '',
    this.statusColor,
  });
}

// =============================================================
// FEATURE CARD CON PARALLAX MULTICAPA DESACOPLADO
// =============================================================

/// Indicador de estado EN VIVO: dot que pulsa (animación siempre activa, se
/// ve en reposo) + etiqueta. Refleja datos reales del provider (motor,
/// Linux, modelo) — no un simple texto estático.
class _LiveStatusPill extends StatefulWidget {
  const _LiveStatusPill({
    required this.color,
    required this.label,
    this.isLandscape = false,
  });

  final Color color;
  final String label;
  final bool isLandscape;

  @override
  State<_LiveStatusPill> createState() => _LiveStatusPillState();
}

class _LiveStatusPillState extends State<_LiveStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final pulse = reduceMotion ? 0.0 : _c.value;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isLandscape ? 6 : 8,
            vertical: widget.isLandscape ? 1 : 2,
          ),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10 + pulse * 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.30 + pulse * 0.22),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5 + pulse * 0.4),
                      blurRadius: 5 + pulse * 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontFamily: 'Inter',
                  fontSize: widget.isLandscape ? 8.5 : 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NanoFeatureCard extends StatelessWidget {
  final NanoFeatureData data;
  final AnimationController reflectionController;
  final bool isLandscape;
  final double distance;
  final double delta;
  final double specularDrift;

  const NanoFeatureCard({
    super.key,
    required this.data,
    required this.reflectionController,
    this.isLandscape = false,
    this.distance = 0.0,
    this.delta = 0.0,
    this.specularDrift = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final reduceMotion = NanoMotion.reduceMotion(context);

    // Parallax desacoplado por capa espacial (Z-Axis simulation)
    final iconOffset = reduceMotion
        ? Offset.zero
        : Offset(-delta * 12.0, -distance * 5.0);
    final textOffset = reduceMotion ? Offset.zero : Offset(-delta * 5.0, 0.0);
    final buttonOffset = reduceMotion
        ? Offset.zero
        : Offset(-delta * 8.0, distance * 3.0);

    return Center(
      child: AspectRatio(
        aspectRatio: isLandscape ? 1.05 : 0.82,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: NanoOpticalSurface(
            borderRadius: NanoRadius.large,
            blurSigma: 18,
            borderStrength: (0.92 - distance * 0.25).clamp(0.55, 0.92),
            reflectionStrength: (0.92 - distance * 0.30).clamp(0.55, 0.92),
            accent: data.accent,
            reflectionController: reflectionController,
            specularDrift: specularDrift,
            onTap: data.onTap,
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isLandscape ? 8 : 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Capa Z-Elevada: Icono flotante con parallax.
                // Flexible + FittedBox(scaleDown): la caja (46px fija) no
                // desborda el AspectRatio en alturas compactas (CPH2557);
                // se escala manteniendo la proporción (sin franjas amarillas).
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Transform.translate(
                      offset: iconOffset,
                      child: _FeatureIcon(
                        icon: data.icon,
                        accent: data.accent,
                        isLandscape: isLandscape,
                        distance: distance,
                      ),
                    ),
                  ),
                ),
                // Capa Z-Media: Textos con micro-desplazamiento
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Transform.translate(
                      offset: textOffset,
                      child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isLandscape ? 0 : 2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: colors.textPrimary,
                              fontSize: isLandscape ? 13.5 : 17.5,
                              height: isLandscape ? 1.1 : 1.2,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                            ),
                          ),
                          if (data.statusLabel.isNotEmpty &&
                              data.statusColor != null) ...[
                            SizedBox(height: isLandscape ? 1 : 3),
                            _LiveStatusPill(
                              color: data.statusColor!,
                              label: data.statusLabel,
                              isLandscape: isLandscape,
                            ),
                          ],
                          if (data.line1.isNotEmpty) ...[
                            SizedBox(height: isLandscape ? 0 : 2),
                            Text(
                              data.line1,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.textSecondary,
                                fontSize: isLandscape ? 10.5 : 12.5,
                                height: isLandscape ? 1.05 : 1.15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                          if (data.line2.isNotEmpty) ...[
                            SizedBox(height: isLandscape ? 0 : 1),
                            Text(
                              data.line2,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: data.secondaryAccent,
                                fontSize: isLandscape ? 10.5 : 12.5,
                                height: isLandscape ? 1.05 : 1.15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                ),
                // Capa Z-Elevada: Botón interactivo de acción
                Transform.translate(
                  offset: buttonOffset,
                  child: _ArrowGlass(
                    accent: data.accent,
                    isLandscape: isLandscape,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool isLandscape;
  final double distance;

  const _FeatureIcon({
    required this.icon,
    required this.accent,
    this.isLandscape = false,
    this.distance = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLandscape ? 40.0 : 46.0;
    final iconSize = isLandscape ? 22.0 : 24.0;
    final isCenter = distance < 0.15;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isCenter
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: NanoOpticalSurface(
        borderRadius: NanoRadius.small,
        blurSigma: 10,
        borderStrength: 0.70,
        reflectionStrength: 0.65,
        accent: accent,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: accent, size: iconSize),
        ),
      ),
    );
  }
}

class _ArrowGlass extends StatefulWidget {
  final Color accent;
  final bool isLandscape;

  const _ArrowGlass({required this.accent, this.isLandscape = false});

  @override
  State<_ArrowGlass> createState() => _ArrowGlassState();
}

class _ArrowGlassState extends State<_ArrowGlass>
    with SingleTickerProviderStateMixin {
  late AnimationController _arrowController;
  late Animation<double> _translateAnimation;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _translateAnimation = Tween<double>(begin: 0.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _arrowController,
        curve: NanoMotionCurves.press,
        reverseCurve: NanoMotionCurves.glassSpring,
      ),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _arrowController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _arrowController.reverse();
  }

  void _handleTapCancel() {
    _arrowController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final size = widget.isLandscape ? 32.0 : 36.0;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _translateAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_translateAnimation.value, 0),
            child: NanoOpticalSurface(
              geometry: NanoSurfaceGeometry.circle,
              blurSigma: 10,
              borderStrength: 0.65,
              reflectionStrength: 0.55,
              accent: widget.accent,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: colors.textPrimary,
                  size: widget.isLandscape ? 16 : 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// LIQUID CAPSULE PAGE INDICATOR
// =============================================================

class _LiquidPageIndicator extends StatelessWidget {
  final PageController controller;
  final int count;
  final int current;

  const _LiquidPageIndicator({
    required this.controller,
    required this.count,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final reduceMotion = NanoMotion.reduceMotion(context);

    if (reduceMotion) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = index == current;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? colors.accentCyan : colors.metalSilver,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        double page = current.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? page;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            final delta = (index - page).abs();
            final closeness = (1.0 - delta).clamp(0.0, 1.0);

            // Morphing elástico continuo de la cápsula
            final width = 8.0 + (closeness * 18.0);
            final activeColor = index == 0
                ? colors.accentLavender
                : (index == 1 ? colors.accentCyan : colors.accentBlue);

            final indicatorColor = Color.lerp(
              colors.metalSilver.withValues(alpha: 0.60),
              activeColor,
              closeness,
            )!;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3.5),
              width: width,
              height: 5,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(999),
                boxShadow: closeness > 0.4
                    ? [
                        BoxShadow(
                          color: indicatorColor.withValues(
                            alpha: 0.35 * closeness,
                          ),
                          blurRadius: 6 * closeness,
                          spreadRadius: -1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

// =============================================================
// STAGGERED CINEMATIC ENTRANCE ANIMATION
// =============================================================

class _AnimatedEntrance extends StatelessWidget {
  final AnimationController controller;
  final double begin;
  final double end;
  final Offset slideOffset;
  final Widget child;

  const _AnimatedEntrance({
    required this.controller,
    required this.begin,
    required this.end,
    this.slideOffset = const Offset(0, 14),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (NanoMotion.reduceMotion(context)) {
      return child;
    }

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, end, curve: NanoMotionCurves.emphasized),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              slideOffset.dx * (1 - value),
              slideOffset.dy * (1 - value),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

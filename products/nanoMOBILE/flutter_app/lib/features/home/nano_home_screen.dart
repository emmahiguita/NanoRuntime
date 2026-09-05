import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';

import 'nano_home_models.dart';

// =============================================================
// NANO HOME SCREEN (HERO ARTWORK BACKGROUND + OPTICAL TELEMETRY)
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  bool _showTelemetry = true;

  @override
  void initState() {
    super.initState();
    // Entrada cinemática escalonada (<450ms)
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

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
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      math.max(4, media.padding.bottom),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
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
                        const Spacer(),
                        _HeroMascotSection(
                          compact: true,
                          maxHeight: maxHeight,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            }

            // ─────────────────────────────────────────────
            // COMPOSICIÓN PORTRAIT MOBILE-FIRST
            // ─────────────────────────────────────────────
            final horizontalPadding = maxWidth < 360
                ? 12.0
                : (maxWidth < 430 ? 16.0 : 20.0);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
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
                          onExpand: () => setState(() => _showTelemetry = true),
                        ),
                      ),
                      const Spacer(),
                      _AnimatedEntrance(
                        controller: _entryController,
                        begin: 0.12,
                        end: 0.50,
                        slideOffset: const Offset(0, 16),
                        child: _HeroMascotSection(
                          maxHeight: maxHeight,
                        ),
                      ),
                      const Spacer(),
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

// =============================================================
// HERO MASCOT & BRANDING SECTION (CRISP VECTOR & OPTICAL GLASS)
// =============================================================

class _HeroMascotSection extends StatefulWidget {
  final bool compact;
  final double maxHeight;

  const _HeroMascotSection({
    this.compact = false,
    this.maxHeight = 300,
  });

  @override
  State<_HeroMascotSection> createState() => _HeroMascotSectionState();
}

class _HeroMascotSectionState extends State<_HeroMascotSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = NanoMotion.reduceMotion(context);

    final owlSize = widget.compact
        ? (widget.maxHeight * 0.40).clamp(50.0, 88.0)
        : (widget.maxHeight * 0.34).clamp(95.0, 175.0);

    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatOffset = reduceMotion
            ? 0.0
            : math.sin(_floatController.value * math.pi) *
                (widget.compact ? 3.0 : 6.0);

        return Transform.translate(
          offset: Offset(0, -floatOffset),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mascot Owl with subtle luminous halo
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: owlSize * 1.35,
                height: owlSize * 1.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark ? colors.nanoCyan : colors.accentCyan).withValues(
                        alpha: isDark ? 0.22 : 0.26,
                      ),
                      (isDark ? colors.nanoBlue : colors.accentSky).withValues(
                        alpha: isDark ? 0.08 : 0.09,
                      ),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              Image.asset(
                'assets/nano/nano_owl.png',
                width: owlSize,
                height: owlSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 4 : 8),
          // Clean title
          Text(
            'N A N O   A I',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: widget.compact ? 15 : 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.8,
              color: colors.textPrimary,
              shadows: [
                Shadow(
                  color: (isDark ? colors.accentCyan : colors.accentBlue)
                      .withValues(alpha: isDark ? 0.40 : 0.18),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          SizedBox(height: widget.compact ? 2 : 4),
          // Slogan
          Text(
            'Un mundo más simple contigo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: widget.compact ? 10.5 : 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              color: colors.textSecondary,
            ),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 10),
            // Optical capsule pill
            NanoOpticalSurface(
              geometry: NanoSurfaceGeometry.capsule,
              blurSigma: 12,
              borderStrength: 0.60,
              reflectionStrength: 0.40,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 11,
                    color: colors.accentMint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Piensa • Crea • Automatiza • Explora',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: colors.textPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


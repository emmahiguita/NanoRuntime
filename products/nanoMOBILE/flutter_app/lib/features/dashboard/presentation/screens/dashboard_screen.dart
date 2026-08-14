import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/app_providers.dart';

// ════════════════════════════════════════════════════════════════════
// Dashboard — NanoAI Launcher (diseño de referencia 2026-08-13)
// ════════════════════════════════════════════════════════════════════
// Pantalla de inicio limpia: sin AppBar ni navegación inferior (el
// ScaffoldShell oculta la barra en el index 0). Los cards llevan a
// Terminal/Chat/Modelos; el resto de la navegación vive en las demás
// pestañas.

/// Paleta del launcher (fondo y acentos de los cards).
abstract final class NanoPalette {
  static const background = Color(0xFF020611);
  static const emerald = Color(0xFF21F2B2);
  static const cyan = Color(0xFF42D9FF);
  static const blue = Color(0xFF6592FF);
  static const slate = Color(0xFF8FA3B8);
}

/// Vista pura del launcher: recibe datos y callbacks, sin providers.
class NanoHomeScreen extends StatelessWidget {
  const NanoHomeScreen({
    super.key,
    required this.ramFreeGb,
    required this.cpuCores,
    required this.temperatureC,
    required this.storageFreeGb,
    required this.batteryPercent,
    required this.linuxReady,
    required this.onTerminal,
    required this.onChat,
    required this.onModels,
    required this.onDesktop,
    required this.onSettings,
  });

  final double? ramFreeGb;
  final int? cpuCores;
  final double? temperatureC;
  final double? storageFreeGb;
  final int? batteryPercent;
  final bool linuxReady;

  final VoidCallback onTerminal;
  final VoidCallback onChat;
  final VoidCallback onModels;
  final VoidCallback onDesktop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NanoPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _CrystalBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 700;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(14, compact ? 10 : 18, 14, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 30,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NanoHeader(compact: compact),
                        SizedBox(height: compact ? 10 : 16),
                        _MetricsStrip(
                          ramFreeGb: ramFreeGb,
                          cpuCores: cpuCores,
                          temperatureC: temperatureC,
                          storageFreeGb: storageFreeGb,
                          batteryPercent: batteryPercent,
                        ),
                        SizedBox(height: compact ? 10 : 14),
                        GlassActionCard(
                          title: 'Terminal',
                          subtitle: linuxReady
                              ? 'Linux listo'
                              : 'Preparando Linux',
                          icon: Icons.terminal_rounded,
                          colors: const [Color(0xAA006B51), Color(0x77005A70)],
                          accent: NanoPalette.emerald,
                          height: compact ? 260 : 330,
                          onTap: onTerminal,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GlassActionCard(
                                title: 'Chat',
                                subtitle: 'Habla con NanoAI',
                                icon: Icons.chat_bubble_outline_rounded,
                                colors: const [
                                  Color(0x99005270),
                                  Color(0x77004485),
                                ],
                                accent: NanoPalette.cyan,
                                height: compact ? 190 : 220,
                                onTap: onChat,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassActionCard(
                                title: 'Modelos',
                                subtitle: 'Gestionar modelos',
                                icon: Icons.view_in_ar_rounded,
                                colors: const [
                                  Color(0x88003977),
                                  Color(0x88092160),
                                ],
                                accent: NanoPalette.blue,
                                height: compact ? 190 : 220,
                                onTap: onModels,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GlassActionCard(
                                title: 'Escritorio',
                                subtitle: 'Linux completo',
                                icon: Icons.desktop_windows_rounded,
                                colors: const [
                                  Color(0x8800496B),
                                  Color(0x77002B4D),
                                ],
                                accent: NanoPalette.emerald,
                                height: compact ? 170 : 160,
                                onTap: onDesktop,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassActionCard(
                                title: 'Ajustes',
                                subtitle: 'Configuración',
                                icon: Icons.settings_rounded,
                                colors: const [
                                  Color(0x88001A30),
                                  Color(0x77000F24),
                                ],
                                accent: NanoPalette.slate,
                                height: compact ? 170 : 160,
                                onTap: onSettings,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Encabezado NanoAI
// ════════════════════════════════════════════════════════════════════

class _NanoHeader extends StatelessWidget {
  const _NanoHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final titleSize = clampDouble(screenWidth * 0.18, 52.0, 74.0);

    return Semantics(
      header: true,
      label: 'NanoAI, inteligencia local',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'nanoai',
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? titleSize * 0.84 : titleSize,
              fontWeight: FontWeight.w300,
              height: 0.95,
              letterSpacing: -3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'local intelligence',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: compact ? 15 : 18,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Panel compacto de métricas
// ════════════════════════════════════════════════════════════════════

class _MetricsStrip extends StatelessWidget {
  const _MetricsStrip({
    required this.ramFreeGb,
    required this.cpuCores,
    required this.temperatureC,
    required this.storageFreeGb,
    required this.batteryPercent,
  });

  final double? ramFreeGb;
  final int? cpuCores;
  final double? temperatureC;
  final double? storageFreeGb;
  final int? batteryPercent;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        Icons.memory_rounded,
        'RAM',
        ramFreeGb == null ? '—' : '${ramFreeGb!.toStringAsFixed(1)} GB',
      ),
      _MetricData(
        Icons.developer_board_rounded,
        'CPU',
        cpuCores == null ? '—' : '$cpuCores',
      ),
      _MetricData(
        Icons.thermostat_rounded,
        'TEMP.',
        temperatureC == null ? '—' : '${temperatureC!.toStringAsFixed(0)} °C',
      ),
      _MetricData(
        Icons.storage_rounded,
        'LIBRE',
        storageFreeGb == null ? '—' : '${storageFreeGb!.toStringAsFixed(0)} GB',
      ),
      _MetricData(
        Icons.battery_full_rounded,
        'BATERÍA',
        batteryPercent == null ? '—' : '$batteryPercent%',
      ),
    ];

    return GlassPanel(
      padding: const EdgeInsets.symmetric(vertical: 10),
      borderRadius: 14,
      blur: 12,
      tint: const Color(0xFF092034),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: _MetricItem(data: items[index])),
              if (index < items.length - 1)
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${data.label}: ${data.value}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            size: 17,
            color: Colors.white.withValues(alpha: 0.88),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            maxLines: 1,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              data.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Tarjetas estilo Windows Mobile moderno
// ════════════════════════════════════════════════════════════════════

class GlassActionCard extends StatefulWidget {
  const GlassActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.accent,
    required this.height,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color accent;
  final double height;
  final VoidCallback onTap;

  @override
  State<GlassActionCard> createState() => _GlassActionCardState();
}

class _GlassActionCardState extends State<GlassActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}',
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.98 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.accent.withValues(alpha: 0.82),
                    width: 1.25,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    onHighlightChanged: (value) {
                      setState(() => _pressed = value);
                    },
                    splashColor: widget.accent.withValues(alpha: 0.16),
                    highlightColor: Colors.white.withValues(alpha: 0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Icon(
                                widget.icon,
                                size: widget.height > 250
                                    ? 104
                                    : (widget.height < 180 ? 48 : 72),
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: widget.accent, blurRadius: 18),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Superficie de cristal
// ════════════════════════════════════════════════════════════════════

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 18,
    this.blur = 12,
    this.tint = const Color(0xFF081727),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.62),
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: NanoPalette.cyan.withValues(alpha: 0.12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Fondo oscuro
// ════════════════════════════════════════════════════════════════════

class _CrystalBackground extends StatelessWidget {
  const _CrystalBackground();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF020611),
              Color(0xFF04101D),
              Color(0xFF001326),
              Color(0xFF02050C),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 160,
              right: -130,
              child: _Glow(size: 340, color: Color(0xFF0066CC)),
            ),
            Positioned(
              top: 380,
              left: -170,
              child: _Glow(size: 390, color: Color(0xFF00C896)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Conexión con Riverpod y las rutas
// ════════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final rootfs = ref.watch(rootfsProvider);

    return NanoHomeScreen(
      ramFreeGb: dashboard.ramTotalGb > 0 ? dashboard.ramFreeGb : null,
      cpuCores: dashboard.cpuCores > 0 ? dashboard.cpuCores : null,
      temperatureC: dashboard.tempC > 0 ? dashboard.tempC : null,
      storageFreeGb: dashboard.storageTotalGb > 0
          ? dashboard.storageFreeGb
          : null,
      batteryPercent: dashboard.batteryPct >= 0
          ? dashboard.batteryPct.round()
          : null,
      // `isReady` del spec adaptado al nombre real del estado:
      // RootfsManager expone `isInstalled` (bash presente en el rootfs).
      linuxReady: rootfs.isInstalled,
      onTerminal: () => context.go('/terminal'),
      onChat: () => context.go('/chat'),
      onModels: () => context.go('/models'),
      onDesktop: () => context.push('/desktop'),
      onSettings: () => context.go('/settings'),
    );
  }
}

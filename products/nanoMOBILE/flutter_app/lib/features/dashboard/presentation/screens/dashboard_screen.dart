import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';

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
class NanoHomeScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - t)),
          child: Opacity(opacity: t, child: child),
        );
      },
      child: Scaffold(
        backgroundColor: NanoPalette.background,
        body: Stack(
          children: [
            const Positioned.fill(child: NanoAmbientBackground()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  final narrow = constraints.maxWidth < 700;
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight;
                final cardGap = narrow ? 8.0 : 10.0;
                // Todo el Inicio cabe en UNA pantalla, sin alturas exageradas:
                // retrato compacto y horizontal usan medidas reducidas.
                final actionHeight = landscape
                    ? 108.0
                    : (narrow ? 112.0 : (compact ? 140.0 : 170.0));
                final terminalHeight = landscape
                    ? 132.0
                    : (narrow ? 142.0 : (compact ? 170.0 : 260.0));
                final tileAspect = landscape ? 1.02 : (narrow ? 1.5 : 1.72);

                // Especificación única de las 4 acciones: el layout portrait
                // (columna/grid) y el landscape (mosaico 2x2) comparten datos
                // sin duplicarlos.
                final actionCards = <_ActionSpec>[
                  _ActionSpec(
                    title: 'Chat',
                    subtitle: 'Habla con NanoAI',
                    icon: Icons.chat_bubble_outline_rounded,
                    colors: const [Color(0x99005270), Color(0x77004485)],
                    accent: NanoPalette.cyan,
                    onTap: onChat,
                  ),
                  _ActionSpec(
                    title: 'Modelos',
                    subtitle: 'Gestionar modelos',
                    icon: Icons.view_in_ar_rounded,
                    colors: const [Color(0x88003977), Color(0x88092160)],
                    accent: NanoPalette.blue,
                    onTap: onModels,
                  ),
                  _ActionSpec(
                    title: 'Escritorio',
                    subtitle: 'Linux completo',
                    icon: Icons.desktop_windows_rounded,
                    colors: const [Color(0x8800496B), Color(0x77002B4D)],
                    accent: NanoPalette.emerald,
                    onTap: onDesktop,
                  ),
                  _ActionSpec(
                    title: 'Ajustes',
                    subtitle: 'Configuración',
                    icon: Icons.settings_rounded,
                    colors: const [Color(0x88001A30), Color(0x77000F24)],
                    accent: NanoPalette.slate,
                    onTap: onSettings,
                  ),
                ];

                Widget buildActionCard(
                  _ActionSpec spec,
                  int index, {
                  bool dense = false,
                }) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.96, end: 1),
                    duration: Duration(milliseconds: 420 + (index * 80)),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: GlassActionCard(
                      title: spec.title,
                      subtitle: spec.subtitle,
                      icon: spec.icon,
                      colors: spec.colors,
                      accent: spec.accent,
                      height: dense ? null : actionHeight,
                      dense: dense,
                      onTap: spec.onTap,
                    ),
                  );
                }

                Widget buildActionGrid() {
                  // Teléfono retrato: mosaico 2x2 — la columna de 4 cards
                  // no cabía en una pantalla y obligaba a scroll.
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: constraints.maxWidth < 1000 ? 2 : 3,
                    childAspectRatio: tileAspect,
                    crossAxisSpacing: cardGap,
                    mainAxisSpacing: cardGap,
                    children: [
                      for (var i = 0; i < actionCards.length; i++)
                        buildActionCard(actionCards[i], i),
                    ],
                  );
                }

                // Mosaico landscape 2x2: dos filas expandidas — las celdas
                // ceden al alto disponible sin scroll vertical y usan todo
                // el ancho de la columna derecha.
                Widget buildActionGridLandscape() {
                  return Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: buildActionCard(actionCards[0], 0,
                                  dense: true),
                            ),
                            SizedBox(width: cardGap),
                            Expanded(
                              child: buildActionCard(actionCards[1], 1,
                                  dense: true),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: cardGap),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: buildActionCard(actionCards[2], 2,
                                  dense: true),
                            ),
                            SizedBox(width: cardGap),
                            Expanded(
                              child: buildActionCard(actionCards[3], 3,
                                  dense: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Horizontal: dos columnas que llenan la pantalla sin
                // scroll — izquierda identidad + métricas + Terminal,
                // derecha Kali + mosaico 2x2 de acciones.
                if (landscape) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _NanoHeader(
                                  compact: true, landscape: true),
                              const SizedBox(height: 6),
                              _MetricsStrip(
                                ramFreeGb: ramFreeGb,
                                cpuCores: cpuCores,
                                temperatureC: temperatureC,
                                storageFreeGb: storageFreeGb,
                                batteryPercent: batteryPercent,
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.95, end: 1),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                        scale: scale, child: child);
                                  },
                                  child: GlassActionCard(
                                    title: 'Terminal',
                                    subtitle: linuxReady
                                        ? 'Linux listo'
                                        : 'Preparando Linux',
                                    icon: Icons.terminal_rounded,
                                    colors: const [
                                      Color(0xAA006B51),
                                      Color(0x77005A70),
                                    ],
                                    accent: NanoPalette.emerald,
                                    onTap: onTerminal,
                                    pulse: linuxReady,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 9,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Expanded(flex: 3, child: _KaliCard()),
                              const SizedBox(height: 6),
                              Expanded(flex: 5, child: buildActionGridLandscape()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

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
                          SizedBox(height: compact ? 10 : 14),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.94, end: 1),
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            builder: (context, scale, child) {
                              return Transform.scale(scale: scale, child: child);
                            },
                            child: _MetricsStrip(
                              ramFreeGb: ramFreeGb,
                              cpuCores: cpuCores,
                              temperatureC: temperatureC,
                              storageFreeGb: storageFreeGb,
                              batteryPercent: batteryPercent,
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.95, end: 1),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (context, scale, child) {
                              return Transform.scale(scale: scale, child: child);
                            },
                            child: GlassActionCard(
                              title: 'Terminal',
                              subtitle: linuxReady ? 'Linux listo' : 'Preparando Linux',
                              icon: Icons.terminal_rounded,
                              colors: const [Color(0xAA006B51), Color(0x77005A70)],
                              accent: NanoPalette.emerald,
                              height: terminalHeight,
                              onTap: onTerminal,
                              pulse: linuxReady,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _KaliCard(height: narrow ? 100 : (compact ? 120 : 132)),
                          const SizedBox(height: 10),
                          buildActionGrid(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NanoHeader extends StatelessWidget {
  const _NanoHeader({required this.compact, this.landscape = false});

  final bool compact;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // En horizontal el título no debe robarle alto a la pantalla:
    // tope 44 en vez de 74.
    final titleSize = landscape
        ? clampDouble(screenWidth * 0.10, 32.0, 44.0)
        : clampDouble(screenWidth * 0.18, 52.0, 74.0);

    return Semantics(
      header: true,
      label: 'NanoAI - inteligencia local',
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
              letterSpacing: landscape ? -2 : -3,
            ),
          ),
          SizedBox(height: landscape ? 3 : 8),
          Text(
            'local intelligence',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: landscape ? 12 : (compact ? 15 : 18),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Datos de una acción del launcher (Chat/Modelos/Escritorio/Ajustes).
class _ActionSpec {
  const _ActionSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color accent;
  final VoidCallback onTap;
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
        ramFreeGb,
        (v) => '${v.toStringAsFixed(1)} GB',
      ),
      _MetricData(
        Icons.developer_board_rounded,
        'CPU',
        cpuCores?.toDouble(),
        (v) => '${v.round()}',
      ),
      _MetricData(
        Icons.thermostat_rounded,
        'TEMP.',
        temperatureC,
        (v) => '${v.round()} °C',
      ),
      _MetricData(
        Icons.storage_rounded,
        'LIBRE',
        storageFreeGb,
        (v) => '${v.round()} GB',
      ),
      _MetricData(
        Icons.battery_full_rounded,
        'BATERÍA',
        batteryPercent?.toDouble(),
        (v) => '${v.round()}%',
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
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 320 + (index * 90)),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) {
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 8 * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: _MetricItem(data: items[index]),
                ),
              ),
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
  const _MetricData(this.icon, this.label, this.value, this.format);

  final IconData icon;
  final String label;
  final double? value;
  final String Function(double value) format;
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.data});

  final _MetricData data;

  /// Contador animado: arranca en 0 y sube hasta el valor real; cuando la
  /// métrica cambia, TweenAnimationBuilder re-apunta desde el valor actual.
  Widget _animatedValue(BuildContext context) {
    final value = data.value;
    if (value == null) {
      return const Text(
        '—',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return Text(
        data.format(value),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        return Text(
          data.format(animated),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${data.label}: ${data.value == null ? '—' : data.format(data.value!)}',
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
            child: _animatedValue(context),
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
    required this.onTap,
    this.height,
    this.dense = false,
    this.pulse = false,
    this.progress,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color accent;

  /// Altura fija (portrait). Null → la card se expande al espacio que le
  /// dé el padre (landscape, grids flexibles).
  final double? height;

  /// Modo compacto para mosaicos landscape: menos padding, título e icono
  /// reducidos para caber en celdas bajas sin desperdiciar espacio.
  final bool dense;

  final VoidCallback onTap;

  /// Muestra un punto de estado que late junto al subtítulo
  /// (servicio vivo: Linux listo, Kali instalado...).
  final bool pulse;

  /// 0..1: muestra una barra de progreso fina bajo el subtítulo
  /// (instalación de Kali en curso).
  final double? progress;

  @override
  State<GlassActionCard> createState() => _GlassActionCardState();
}

class _GlassActionCardState extends State<GlassActionCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _startPulse();
  }

  @override
  void didUpdateWidget(covariant GlassActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El pulso puede activarse DESPUÉS del initState (linuxReady, Kali
    // listo): sin esta sincronización, build con pulse:true llegaba a
    // `_pulse!` con el controller aún nulo y crasheaba la home entera.
    if (oldWidget.pulse != widget.pulse) {
      if (widget.pulse) {
        _startPulse();
      } else {
        _pulse?.dispose();
        _pulse = null;
      }
    }
  }

  void _startPulse() {
    _pulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  /// Tamaño del icono según el espacio: dense (mosaico landscape) usa 34;
  /// con altura fija crece con la card; sin altura (expandida) usa 48.
  double get _iconSize {
    if (widget.dense) return 34;
    final height = widget.height;
    if (height == null) return 48;
    if (height > 250) return 104;
    return height < 180 ? 48 : 72;
  }

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
                      padding: EdgeInsets.all(widget.dense ? 10 : 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.dense ? 15 : 24,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: AnimatedScale(
                                scale: _pressed && !reduceMotion ? 0.82 : 1,
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutBack,
                                // En celdas bajas el icono se encoje al
                                // espacio libre en vez de desbordar y pintar
                                // encima del título/subtítulo (retrato 112dp
                                // y landscape dense).
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Icon(
                                    widget.icon,
                                    size: _iconSize,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: widget.accent,
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.pulse)
                                AnimatedBuilder(
                                  animation: _pulse!,
                                  builder: (context, child) {
                                    final t = reduceMotion ? 1.0 : _pulse!.value;
                                    return Opacity(
                                      opacity: 0.45 + (0.55 * t),
                                      child: Transform.scale(
                                        scale: 0.75 + (0.25 * t),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 7),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.accent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.accent,
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  widget.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.accent,
                                    fontSize: widget.dense ? 10.5 : 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.progress != null) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: widget.progress),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                builder: (context, t, _) {
                                  return LinearProgressIndicator(
                                    value: t,
                                    minHeight: 3,
                                    color: widget.accent,
                                    backgroundColor:
                                        widget.accent.withValues(alpha: 0.18),
                                  );
                                },
                              ),
                            ),
                          ],
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
// Card Kali con lógica funcional real
// ════════════════════════════════════════════════════════════════════

/// Card Kali: si el rootfs no está instalado, el tap confirma y lanza la
/// descarga real (kali.download + SHA256) con progreso visible en la propia
/// card; si ya está instalado, abre el terminal con `kali shell` ejecutado.
class _KaliCard extends ConsumerStatefulWidget {
  const _KaliCard({this.height});

  /// Altura fija (portrait). Null → se expande al espacio del padre
  /// (columna derecha del layout landscape).
  final double? height;

  @override
  ConsumerState<_KaliCard> createState() => _KaliCardState();
}

class _KaliCardState extends ConsumerState<_KaliCard> {
  bool _installing = false;
  String _stage = '';
  int _pct = 0;

  static const _stageLabels = {
    'download': 'Descargando rootfs Kali',
    'verify': 'Verificando SHA256',
    'extract': 'Extrayendo rootfs',
    'done': 'Instalación completa',
    'error': 'Falló la instalación',
  };

  Future<void> _tap() async {
    final kali = ref.read(kaliProvider);
    if (kali == null) {
      // Sin manager (deps no iniciadas): terminal es el único camino real.
      if (mounted) context.go('/terminal');
      return;
    }
    await kali.checkInstalled();
    if (!mounted) return;
    if (kali.isInstalled) {
      context.go('/terminal?cmd=kali shell');
      return;
    }
    if (_installing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Instalar Kali Linux ARM64'),
        content: const Text(
          'Descargará ~200 MB desde kali.download (rootfs oficial '
          'NetHunter) y verificará el SHA256 antes de extraer. '
          'Requiere espacio libre en almacenamiento. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Instalar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _installing = true;
      _stage = 'download';
      _pct = 0;
    });
    final ok = await kali.install((stage, pct) {
      if (!mounted) return;
      setState(() {
        _stage = stage;
        _pct = pct;
      });
    });
    if (!mounted) return;
    setState(() {
      _installing = false;
      _stage = ok ? 'done' : 'error';
      _pct = ok ? 100 : 0;
    });
    if (ok) {
      context.go('/terminal?cmd=kali shell');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kali = ref.read(kaliProvider);
    final audit = kali?.auditTools() ?? const <String, bool>{};
    final ready = kali?.isInstalled == true;
    final installedCount = audit.values.where((v) => v).length;
    final missingCount = audit.length - installedCount;
    final coverage =
        audit.isEmpty ? null : (installedCount / audit.length).clamp(0.0, 1.0);

    // Estado → (chip, detalle, color). Layout horizontal propio: la card
    // Kali no comparte estructura con GlassActionCard (Terminal), así el
    // usuario distingue ambas de un vistazo.
    final String chip;
    final String detail;
    final Color accent;
    if (_installing) {
      chip = '$_pct%';
      detail = _stageLabels[_stage] ?? _stage;
      accent = NanoPalette.cyan;
    } else if (_stage == 'error') {
      chip = 'ERROR';
      detail = 'Toca para reintentar la instalación';
      accent = const Color(0xFFFF5D6C);
    } else if (ready && missingCount == 0) {
      chip = 'AUDIT 100%';
      detail = 'Catálogo completo — toca para abrir shell';
      accent = NanoPalette.emerald;
    } else if (ready) {
      chip = 'AUDIT $installedCount/${audit.length}';
      detail = 'Faltan $missingCount tools — toca para abrir shell';
      accent = NanoPalette.cyan;
    } else if (kali == null) {
      chip = 'NO INICIALIZADO';
      detail = 'Abre el terminal para usar el comando kali';
      accent = NanoPalette.slate;
    } else {
      chip = 'NO INSTALADO';
      detail = 'Rootfs Kali ARM64 — toca para instalar';
      accent = NanoPalette.slate;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1),
      duration: const Duration(milliseconds: 540),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xD106233F), Color(0xD102101F)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accent.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _tap,
                  splashColor: accent.withValues(alpha: 0.14),
                  highlightColor: Colors.white.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        // Escudo Kali: bloque cuadrado, no icono centrado.
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.22),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            size: 24,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Kali',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // En columnas angostas el chip cede y
                                  // trunca su texto antes que desbordar.
                                  Flexible(
                                    child: _KaliStatusChip(
                                        label: chip, accent: accent),
                                  ),
                                  if (ready) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: NanoPalette.emerald,
                                        boxShadow: [
                                          BoxShadow(
                                            color: NanoPalette.emerald,
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (_installing) ...[
                                const SizedBox(height: 7),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: _pct / 100),
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, t, _) {
                                      return LinearProgressIndicator(
                                        value: t,
                                        minHeight: 3,
                                        color: accent,
                                        backgroundColor:
                                            accent.withValues(alpha: 0.18),
                                      );
                                    },
                                  ),
                                ),
                              ] else if (ready && coverage != null) ...[
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    Text(
                                      'Cobertura',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.45),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: coverage,
                                          minHeight: 3,
                                          color: NanoPalette.emerald,
                                          backgroundColor:
                                              NanoPalette.emerald
                                                  .withValues(alpha: 0.15),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$installedCount/${audit.length}',
                                      style: const TextStyle(
                                        color: NanoPalette.emerald,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
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
    );
  }
}

/// Chip de estado compacto de la card Kali (instalación/auditoría).
class _KaliStatusChip extends StatelessWidget {
  const _KaliStatusChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
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
      // /desktop arranca el flujo completo: instala + lanza Xvnc + espera TCP
      // y navega solo a VNC cuando el puerto responde. Apuntar directo a
      // /desktop/vnc dejaba el cliente RFB sin servidor (pantalla muerta).
      onDesktop: () => context.push('/desktop'),
      onSettings: () => context.go('/settings'),
    );
  }
}


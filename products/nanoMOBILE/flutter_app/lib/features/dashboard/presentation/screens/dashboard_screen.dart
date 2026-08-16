import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nanoai/core/providers/app_providers.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/nano_ambient_background.dart';

// ════════════════════════════════════════════════════════════════════
// Dashboard — NanoAI Launcher (diseño de referencia 2026-08-13)
// ════════════════════════════════════════════════════════════════════
// Pantalla de inicio limpia: sin AppBar ni navegación inferior (el
// ScaffoldShell oculta la barra en el index 0). Los cards llevan a
// Terminal/Chat/Modelos; el resto de la navegación vive en las demás
// pestañas.

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
    this.chatSubtitle = 'Habla con NanoAI',
    this.chatPulse = false,
    this.modelsSubtitle = 'Gestionar modelos',
    this.modelsPulse = false,
  });

  final double? ramFreeGb;
  final int? cpuCores;
  final double? temperatureC;
  final double? storageFreeGb;
  final int? batteryPercent;
  final bool linuxReady;

  /// Subtítulo de la card Chat inyectado desde chatProvider: refleja el
  /// modelo activo y el estado real del motor (listo/cargando/error).
  final String chatSubtitle;

  /// Punto vivo en la card Chat cuando el motor está online.
  final bool chatPulse;

  /// Subtítulo de la card Modelos inyectado desde modelsProvider: conteo
  /// real de modelos del catálogo + detectados en storage.
  final String modelsSubtitle;

  /// Punto vivo en la card Modelos cuando hay al menos un modelo.
  final bool modelsPulse;

  final VoidCallback onTerminal;
  final VoidCallback onChat;
  final VoidCallback onModels;
  final VoidCallback onDesktop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
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
        backgroundColor: colors.background,
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
                // La fila Terminal+Kali comparte altura: antes Terminal solo
                // medía hasta 260px verticales — ahora mitad de pantalla.
                final terminalRowHeight = landscape
                    ? 108.0
                    : (compact ? 100.0 : 118.0);
                final tileAspect = landscape ? 1.02 : (narrow ? 1.5 : 1.72);

                // Especificación única de las 4 acciones: el layout portrait
                // (columna/grid) y el landscape (mosaico 2x2) comparten datos
                // sin duplicarlos.
                final actionCards = <_ActionSpec>[
                  _ActionSpec(
                    title: 'Chat',
                    subtitle: chatSubtitle,
                    icon: Icons.chat_bubble_outline_rounded,
                    colors: [
                      colors.surface.withValues(alpha: 0.6),
                      colors.surfaceVariant.withValues(alpha: 0.47),
                    ],
                    accent: colors.accent,
                    pulse: chatPulse,
                    onTap: onChat,
                  ),
                  _ActionSpec(
                    title: 'Modelos',
                    subtitle: modelsSubtitle,
                    icon: Icons.view_in_ar_rounded,
                    colors: [
                      colors.surface.withValues(alpha: 0.53),
                      colors.surfaceVariant.withValues(alpha: 0.53),
                    ],
                    accent: colors.secondary,
                    pulse: modelsPulse,
                    onTap: onModels,
                  ),
                  _ActionSpec(
                    title: 'Escritorio',
                    subtitle: 'Linux completo',
                    icon: Icons.desktop_windows_rounded,
                    colors: [
                      colors.surface.withValues(alpha: 0.53),
                      colors.surfaceVariant.withValues(alpha: 0.47),
                    ],
                    accent: colors.success,
                    onTap: onDesktop,
                  ),
                  _ActionSpec(
                    title: 'Linux',
                    subtitle: 'Multi-distro',
                    icon: Icons.computer_rounded,
                    colors: [
                      colors.surface.withValues(alpha: 0.53),
                      colors.surfaceVariant.withValues(alpha: 0.47),
                    ],
                    accent: colors.success,
                    onTap: () => context.push('/linux'),
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
                      // Sin altura fija: la celda del grid impone el tamaño
                      // y el contenido se adapta (icono FittedBox).
                      dense: dense,
                      pulse: spec.pulse,
                      onTap: spec.onTap,
                    ),
                  );
                }

                Widget buildActionGrid() {
                  // Mosaico 2x2 de las 4 acciones principales. Dense: la
                  // celda del grid impone la altura y el contenido se adapta
                  // (icono y tipografía compactos) sin alturas fijas.
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: constraints.maxWidth < 1000 ? 2 : 3,
                    childAspectRatio: tileAspect,
                    crossAxisSpacing: cardGap,
                    mainAxisSpacing: cardGap,
                    children: [
                      for (var i = 0; i < actionCards.length; i++)
                        buildActionCard(actionCards[i], i, dense: true),
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
                              _NanoHeader(
                                compact: true,
                                landscape: true,
                                onSettings: onSettings,
                              ),
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
                                    colors: [
                                      colors.surface.withValues(alpha: 0.67),
                                      colors.surfaceVariant
                                          .withValues(alpha: 0.47),
                                    ],
                                    accent: colors.success,
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
                          _NanoHeader(
                            compact: compact,
                            onSettings: onSettings,
                          ),
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
                          // Launcher primero: las 4 acciones principales en
                          // mosaico 2x2 compacto. Antes el grid iba al final,
                          // tras una card Terminal gigante (hasta 260px) que
                          // empujaba la navegación fuera de la pantalla.
                          buildActionGrid(),
                          SizedBox(height: compact ? 8 : 10),
                          // Terminal + Kali en una fila: mismo peso visual y
                          // la mitad del alto vertical que ocupaban antes.
                          // Sin CrossAxisAlignment.stretch: en un scroll
                          // vertical la altura es infinita y stretch exige
                          // h=Infinity — ambos hijos ya traen height fija.
                          Row(
                            children: [
                              Expanded(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.95, end: 1),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: GlassActionCard(
                                    title: 'Terminal',
                                    subtitle: linuxReady
                                        ? 'Linux listo'
                                        : 'Preparando Linux',
                                    icon: Icons.terminal_rounded,
                                    colors: [
                                      colors.surface.withValues(alpha: 0.67),
                                      colors.surfaceVariant
                                          .withValues(alpha: 0.47),
                                    ],
                                    accent: colors.success,
                                    dense: true,
                                    height: terminalRowHeight,
                                    onTap: onTerminal,
                                    pulse: linuxReady,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _KaliCard(height: terminalRowHeight),
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
      ),
    );
  }
}

class _NanoHeader extends StatelessWidget {
  const _NanoHeader({
    required this.compact,
    this.landscape = false,
    this.onSettings,
  });

  final bool compact;
  final bool landscape;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Fila compacta: el título gigante (hasta 74px) robaba el primer tercio
    // de la pantalla; ahora el encabezado completo cabe en una sola fila
    // con el acceso a Ajustes integrado.
    final titleSize = landscape
        ? clampDouble(screenWidth * 0.055, 22.0, 28.0)
        : clampDouble(screenWidth * 0.085, 26.0, 34.0);

    return Semantics(
      header: true,
      label: 'NanoAI - inteligencia local',
      // LayoutBuilder: en landscape el header vive en una columna de ~243dp
      // aunque la pantalla mida 480dp — las decisiones de ancho deben usar
      // el espacio REAL del header, no el global (overflow confirmado).
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // El chip "local intelligence" es ancho fijo (~110dp): por debajo
          // de 280dp no cabe junto al título + botón de Ajustes.
          final showTag = w >= 280;
          // Columnas ultra-angostas (<120dp): IconButton compacto y sin gap.
          final ultraNarrow = w < 120;
          return Row(
        children: [
          Flexible(
            child: Text(
              'nanoai',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: ultraNarrow
                    ? 15
                    : (compact ? titleSize * 0.86 : titleSize),
                fontWeight: FontWeight.w300,
                height: 1,
                letterSpacing: landscape ? -1.6 : -2,
              ),
            ),
          ),
          if (!ultraNarrow) const SizedBox(width: 10),
          if (showTag)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.07),
                borderRadius: NanoShapes.full,
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                'local intelligence',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.6),
                  fontSize: landscape ? 10 : 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const Spacer(),
          if (onSettings != null)
            IconButton(
              tooltip: 'Ajustes',
              visualDensity: ultraNarrow ? VisualDensity.compact : null,
              padding: ultraNarrow ? EdgeInsets.zero : null,
              icon: Icon(
                Icons.settings_rounded,
                color: colors.onSurface.withValues(alpha: 0.75),
                size: 21,
              ),
              onPressed: onSettings,
            ),
          ],
          );
        },
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
    this.pulse = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final Color accent;
  final VoidCallback onTap;

  /// Punto de estado vivo junto al subtítulo (motor online, modelos listos).
  final bool pulse;
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
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
      tint: colors.surface,
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
                  color: colors.onSurface.withValues(alpha: 0.12),
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final value = data.value;
    if (value == null) {
      return Text(
        '—',
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return Text(
        data.format(value),
        style: TextStyle(
          color: colors.onSurface,
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
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Semantics(
      label: '${data.label}: ${data.value == null ? '—' : data.format(data.value!)}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            size: 17,
            color: colors.onSurface.withValues(alpha: 0.88),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            maxLines: 1,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.52),
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
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
                    highlightColor: colors.onSurface.withValues(alpha: 0.04),
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
                              color: colors.onSurface,
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
                                    color: colors.onSurface,
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
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
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
      accent = colors.accent;
    } else if (_stage == 'error') {
      chip = 'ERROR';
      detail = 'Toca para reintentar la instalación';
      accent = colors.danger;
    } else if (ready && missingCount == 0) {
      chip = 'AUDIT 100%';
      detail = 'Catálogo completo — toca para abrir shell';
      accent = colors.success;
    } else if (ready) {
      chip = 'AUDIT $installedCount/${audit.length}';
      detail = 'Faltan $missingCount tools — toca para abrir shell';
      accent = colors.accent;
    } else if (kali == null) {
      chip = 'NO INICIALIZADO';
      detail = 'Abre el terminal para usar el comando kali';
      accent = colors.onSurfaceVariant;
    } else {
      chip = 'NO INSTALADO';
      detail = 'Rootfs Kali ARM64 — toca para instalar';
      accent = colors.onSurfaceVariant;
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface.withValues(alpha: 0.82),
                    colors.background.withValues(alpha: 0.82),
                  ],
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
                  highlightColor: colors.onSurface.withValues(alpha: 0.04),
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
                                  Flexible(
                                    child: Text(
                                      'Kali',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.onSurface,
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
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.success,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.success,
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
                                  color:
                                      colors.onSurface.withValues(alpha: 0.6),
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
                                        color: colors.onSurface
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
                                          color: colors.success,
                                          backgroundColor:
                                              colors.success
                                                  .withValues(alpha: 0.15),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$installedCount/${audit.length}',
                                      style: TextStyle(
                                        color: colors.success,
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
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final radius = BorderRadius.circular(borderRadius);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (tint ?? colors.surface).withValues(alpha: 0.62),
              borderRadius: radius,
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.12),
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

  /// Subtítulo de la card Chat según el estado REAL del motor LLM.
  /// Prioridad: generando > cargando modelo > online > error > sin modelo.
  static String _chatSubtitle(ChatState chat) {
    if (chat.generating) return 'Generando respuesta...';
    switch (chat.connection) {
      case ModelConnectionState.loadingModel:
        return 'Cargando ${chat.activeModel}...';
      case ModelConnectionState.error:
        return 'Motor con error — toca para ver';
      case ModelConnectionState.ready:
        return chat.activeModel == 'Sin modelo'
            ? 'Motor listo — sin modelo'
            : '${chat.activeModel} — motor listo';
      case ModelConnectionState.noModel:
        return 'Motor apagado — elige modelo';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final rootfs = ref.watch(rootfsProvider);

    // Lógica real inyectada en las cards: el motor LLM (chatProvider) y el
    // inventario de modelos (modelsProvider) alimentan subtítulos y puntos
    // de estado vivos. El dashboard deja de ser solo navegación estática.
    final chat = ref.watch(chatProvider);
    final models = ref.watch(modelsProvider);
    final modelCount = models.models.length + models.detected.length;

    return NanoHomeScreen(
      chatSubtitle: _chatSubtitle(chat),
      chatPulse: chat.engineOnline && !chat.generating,
      modelsSubtitle: models.scanning
          ? 'Escaneando storage...'
          : modelCount > 0
              ? '$modelCount modelos disponibles'
              : 'Sin modelos — importa un GGUF',
      modelsPulse: modelCount > 0 && !models.scanning,
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


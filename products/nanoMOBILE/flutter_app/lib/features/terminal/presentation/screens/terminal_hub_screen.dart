import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'package:nanoai/core/widgets/nano_optical_surface.dart';
import 'package:nanoai/core/widgets/nano_screen_shell.dart';

/// Centro único de acceso a las herramientas de sistema.
///
/// Las pantallas y servicios reales permanecen en sus módulos; este widget
/// únicamente organiza sus puntos de entrada dentro de la rama Terminal.
class TerminalHubScreen extends StatefulWidget {
  const TerminalHubScreen({super.key});

  @override
  State<TerminalHubScreen> createState() => _TerminalHubScreenState();
}

class _TerminalHubScreenState extends State<TerminalHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.hero,
    )..forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    final destinations = <_TerminalDestination>[
      _TerminalDestination(
        icon: Icons.terminal_rounded,
        title: 'Terminal',
        eyebrow: 'CONSOLA PTY',
        description:
            'Sesiones persistentes para Bash, Python, Node, SSH y herramientas locales.',
        accent: colors.terminalGreen,
        onOpen: () => context.push('/terminal/shell'),
      ),
      _TerminalDestination(
        icon: Icons.hub_rounded,
        title: 'Nano Linux',
        eyebrow: 'ENTORNOS',
        description:
            'Administra distribuciones, contenedores y accesos al sistema Linux local.',
        accent: colors.accentCyan,
        onOpen: () => context.push('/linux'),
      ),
      _TerminalDestination(
        icon: Icons.desktop_windows_rounded,
        title: 'Visor Linux',
        eyebrow: 'ESCRITORIO',
        description:
            'Prepara el escritorio gráfico y abre el visor remoto cuando esté disponible.',
        accent: colors.accentLavender,
        onOpen: () => context.push('/desktop'),
      ),
    ];

    return NanoScreenShell(
      title: 'Terminal',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDeviceLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final compactLandscape = isDeviceLandscape &&
              width > constraints.maxHeight &&
              constraints.maxHeight < 520;
          final columns = compactLandscape
              ? 3
              : (width >= 900 ? 3 : (width >= 620 ? 2 : 1));
          final ratio = compactLandscape
              ? 1.30
              : (columns == 3
                    ? 1.18
                    : (columns == 2 ? 1.35 : (width < 360 ? 1.12 : 1.72)));

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  width < 600 ? 16 : 24,
                  compactLandscape ? 4 : 12,
                  width < 600 ? 16 : 24,
                  compactLandscape ? 8 : 28,
                ),
                sliver: SliverList.list(
                  children: [
                    Text(
                      'Sistemas locales',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontFamily: 'Inter',
                        fontSize: compactLandscape
                            ? 20
                            : (width < 600 ? 24 : 30),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: compactLandscape ? 2 : 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Text(
                        'Terminal, entornos Nano Linux y escritorio gráfico organizados en un solo lugar.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontFamily: 'Inter',
                          fontSize: compactLandscape ? 11.5 : 14,
                          height: compactLandscape ? 1.2 : 1.45,
                        ),
                        maxLines: compactLandscape ? 1 : null,
                        overflow: compactLandscape
                            ? TextOverflow.ellipsis
                            : TextOverflow.clip,
                      ),
                    ),
                    SizedBox(height: compactLandscape ? 8 : 22),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  compactLandscape ? 12 : (width < 600 ? 16 : 24),
                  0,
                  compactLandscape ? 12 : (width < 600 ? 16 : 24),
                  compactLandscape ? 8 : 28,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: compactLandscape ? 8 : 14,
                    mainAxisSpacing: compactLandscape ? 8 : 14,
                    childAspectRatio: ratio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: destinations.length,
                    (context, index) => _StaggeredTerminalCard(
                      index: index,
                      controller: _entryController,
                      destination: destinations[index],
                      compact: compactLandscape,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TerminalDestination {
  const _TerminalDestination({
    required this.icon,
    required this.title,
    required this.eyebrow,
    required this.description,
    required this.accent,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String eyebrow;
  final String description;
  final Color accent;
  final VoidCallback onOpen;
}

class _StaggeredTerminalCard extends StatelessWidget {
  const _StaggeredTerminalCard({
    required this.index,
    required this.controller,
    required this.destination,
    required this.compact,
  });

  final int index;
  final AnimationController controller;
  final _TerminalDestination destination;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = NanoMotion.reduceMotion(context);
    final start = index * 0.12;
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start,
        (start + 0.62).clamp(0.0, 1.0),
        curve: NanoMotionCurves.emphasized,
      ),
    );

    if (reduceMotion) {
      return _TerminalCard(destination: destination, compact: compact);
    }

    return AnimatedBuilder(
      animation: animation,
      child: _TerminalCard(destination: destination, compact: compact),
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - animation.value)),
          child: Transform.scale(
            scale: 0.985 + animation.value * 0.015,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _TerminalCard extends StatelessWidget {
  const _TerminalCard({required this.destination, required this.compact});

  final _TerminalDestination destination;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Semantics(
      button: true,
      label: 'Abrir ${destination.title}',
      child: NanoOpticalSurface(
        onTap: destination.onOpen,
        tilt: true,
        autoReflect: true,
        accent: destination.accent,
        borderStrength: 0.82,
        reflectionStrength: isDark ? 0.70 : 0.48,
        blurSigma: 16,
        depth: 0.9,
        padding: EdgeInsets.all(compact ? 10 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 32 : 46,
                  height: compact ? 32 : 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: destination.accent.withValues(
                      alpha: isDark ? 0.16 : 0.11,
                    ),
                    border: Border.all(
                      color: destination.accent.withValues(
                        alpha: isDark ? 0.42 : 0.28,
                      ),
                    ),
                  ),
                  child: Icon(
                    destination.icon,
                    color: destination.accent,
                    size: compact ? 17 : 23,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_outward_rounded,
                  color: colors.textSecondary.withValues(alpha: 0.72),
                  size: compact ? 16 : 20,
                ),
              ],
            ),
            const Spacer(),
            Text(
              destination.eyebrow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: destination.accent.withValues(alpha: 0.90),
                fontFamily: 'Inter',
                fontSize: compact ? 8 : 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: compact ? 2 : 5),
            Text(
              destination.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontFamily: 'Inter',
                fontSize: compact ? 15 : 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.45,
              ),
            ),
            SizedBox(height: compact ? 3 : 7),
            Text(
              destination.description,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontFamily: 'Inter',
                fontSize: compact ? 10 : 12.5,
                height: compact ? 1.2 : 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

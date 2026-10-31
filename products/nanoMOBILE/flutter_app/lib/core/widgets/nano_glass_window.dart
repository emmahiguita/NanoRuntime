import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'glass_surface.dart';

export 'nano_glass_list_window.dart'
    show NanoGlassListWindow, NanoGlassListTile;

/// Un solo responsable dibuja el marco y el cierre. Los diálogos que ya
/// tienen cabecera y superficie propias no reciben una segunda ventana.
enum NanoWindowChrome { managed, contentOwned }

/// Abre una ventana flotante centrada con cristal iOS y animación fluida.
/// Conserva el Future y el Navigator del selector original: cerrar devuelve
/// null; elegir devuelve el valor real.
Future<T?> showNanoGlassWindow<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  BoxConstraints? constraints,
  Color? barrierColor,
  AnimationStyle? animationStyle,
  NanoWindowChrome chrome = NanoWindowChrome.managed,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: .36),
    transitionDuration: reduced
        ? Duration.zero
        : (animationStyle?.duration ?? NanoMotionDurations.hero),
    pageBuilder: (routeContext, _, _) => themes.wrap(
      Material(
        type: MaterialType.transparency,
        child: Overlay.wrap(
          child: _NanoGlassWindow(
            constraints: constraints,
            builder: builder,
            chrome: chrome,
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondary, child) {
      if (reduced) {
        return FadeTransition(opacity: animation, child: child);
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: NanoMotionCurves.glassSpring,
        reverseCurve: NanoMotionCurves.standardAccel,
      );
      return AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, content) {
          final t = curved.value;
          final opacity = animation.value.clamp(0.0, 1.0);
          final scale = lerpDouble(0.94, 1.0, t)!;
          final dy = lerpDouble(10.0, 0.0, t)!;
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.scale(scale: scale, child: content),
            ),
          );
        },
      );
    },
  );
}

/// El marco reserva espacio seguro y teclado una sola vez. La altura disponible
/// se comunica al contenido para que sus listas y formularios sigan adaptándose.
class _NanoGlassWindow extends StatelessWidget {
  const _NanoGlassWindow({
    required this.builder,
    required this.chrome,
    this.constraints,
  });
  final WidgetBuilder builder;
  final BoxConstraints? constraints;
  final NanoWindowChrome chrome;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final owned = chrome == NanoWindowChrome.contentOwned;

    return SafeArea(
      child: AnimatedPadding(
        padding: media.viewInsets + const EdgeInsets.all(16),
        duration: NanoMotion.adapt(context, NanoMotionDurations.standard),
        curve: NanoMotionCurves.glassSpring,
        child: LayoutBuilder(
          builder: (context, available) {
            final width = math.min(
              available.maxWidth,
              constraints?.maxWidth ?? 620.0,
            );
            final height = math.min(
              available.maxHeight,
              constraints?.maxHeight ?? available.maxHeight,
            );
            final contentHeight = math.max(0.0, height - (owned ? 0 : 38));
            Widget content = MediaQuery(
              data: media.copyWith(
                size: Size(width, contentHeight),
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: Builder(builder: builder),
            );
            if (!owned) {
              content = ClipRRect(
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: GlassSurface(
                  interactive: false,
                  padding: EdgeInsets.zero,
                  radius: 24,
                  blur: 24,
                  opacity: 0.96,
                  tint: isDark
                      ? const Color(0xFF111827).withValues(alpha: 0.88)
                      : const Color(0xFFF8FAFC).withValues(alpha: 0.95),
                  clarity: 0.65,
                  intensity: 0.60,
                  depth: 1.1,
                  borderWidth: 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 32),
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: Semantics(
                                label: 'Cerrar ventana',
                                button: true,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(CupertinoIcons.xmark_circle_fill, size: 20, color: isDark ? Colors.white.withValues(alpha: 0.40) : Colors.black.withValues(alpha: 0.28)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(fit: FlexFit.loose, child: content),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: height),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/nano_motion.dart';
import 'glass_surface.dart';

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
  // El modal cubre también el dock: la navegación de fondo no puede quedar
  // por encima ni recibir pulsaciones mientras una ventana está abierta.
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: .32),
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
            // Solo el marco administrado reserva sus 40 px para el botón de cierre.
            final contentHeight = math.max(0.0, height - (owned ? 0 : 40));
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
              content = GlassSurface(
                interactive: false,
                padding: EdgeInsets.zero,
                radius: 24,
                blur: 24,
                opacity: .66,
                clarity: .88,
                intensity: .72,
                depth: 1.3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // No se crea este cierre cuando la cabecera del contenido lo posee.
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        height: 40,
                        child: Semantics(
                          label: 'Cerrar ventana',
                          button: true,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ),
                      ),
                    ),
                    Flexible(fit: FlexFit.loose, child: content),
                  ],
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

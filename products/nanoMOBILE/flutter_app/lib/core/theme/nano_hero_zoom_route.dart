// QUÉ: la tarjeta se expande hasta la vista existente y se contrae al volver.
// CÓMO: mide el origen en el Navigator, comparte tag y recorta una sola página.
// POR QUÉ: sin snapshots, Overlay propio, controladores extra ni lógica duplicada.
import 'package:flutter/material.dart';
import 'nano_hero_source.dart';
import 'nano_motion.dart';

Route<T> nanoHeroZoomRoute<T>({
  required BuildContext originContext,
  required String tag,
  required WidgetBuilder builder,
}) {
  final navigator = Navigator.of(originContext);
  final navigatorBox = navigator.context.findRenderObject()! as RenderBox;
  final originBox = originContext.findRenderObject()! as RenderBox;
  final initialOrigin =
      originBox.localToGlobal(Offset.zero, ancestor: navigatorBox) &
      originBox.size;
  // Relee el origen al volver si hubo rotación; no usa coordenadas de otra vista.
  Rect currentOrigin() {
    if (!originContext.mounted) return initialOrigin;
    final box = originContext.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return initialOrigin;
    }
    return box.localToGlobal(Offset.zero, ancestor: navigatorBox) & box.size;
  }

  final themes = InheritedTheme.capture(
    from: originContext,
    to: navigator.context,
  );
  final theme = Theme.of(originContext);
  final reduced = NanoMotion.reduceMotion(originContext);
  return PageRouteBuilder<T>(
    // Mantener la ruta inferior durante toda la expansión impide fondos negros.
    opaque: false,
    transitionDuration: Duration(milliseconds: reduced ? 0 : 380),
    reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 380),
    pageBuilder: (context, animation, secondary) => Stack(
      fit: StackFit.expand,
      children: [
        themes.wrap(Builder(builder: builder)),
        // Dentro de pageBuilder: HeroController busca en el subárbol de la ruta.
        if (!reduced)
          Positioned.fill(
            child: IgnorePointer(
              child: Hero(
                tag: tag,
                createRectTween: nanoHeroRectTween,
                flightShuttleBuilder: nanoHeroCardFlight,
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    ),
    transitionsBuilder: (context, animation, secondary, child) {
      if (reduced) return child;
      return LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Offset.zero & constraints.biggest;
          return AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, page) {
              // HeroController aplica esta curva; no curvar su RectTween otra vez.
              final curve = animation.status == AnimationStatus.reverse
                  ? Curves.fastOutSlowIn.flipped
                  : Curves.fastOutSlowIn;
              final t = curve.transform(animation.value);
              final rect = Rect.lerp(currentOrigin(), viewport, t)!;
              final fade = const Interval(
                0.12,
                0.65,
                curve: Curves.easeOutCubic,
              ).transform(t);
              return Stack(
                children: [
                  // Captura gestos sobre la ruta activa, también fuera del recorte.
                  const Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(color: Colors.transparent),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: rect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22 * (1 - t)),
                      child: ColoredBox(
                        color: Color.lerp(
                          theme.colorScheme.surface,
                          theme.scaffoldBackgroundColor,
                          t,
                        )!,
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: viewport.width,
                          maxWidth: viewport.width,
                          minHeight: viewport.height,
                          maxHeight: viewport.height,
                          child: FadeTransition(
                            opacity: AlwaysStoppedAnimation(fade),
                            child: ScaleTransition(
                              scale: AlwaysStoppedAnimation(
                                0.985 + 0.015 * fade,
                              ),
                              alignment: Alignment.topLeft,
                              child: page,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

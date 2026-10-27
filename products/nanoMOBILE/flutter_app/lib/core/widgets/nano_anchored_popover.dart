import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';

/// Una ruta y una superficie de cristal junto al botón. Cerrar fuera o con
/// Atrás devuelve null; el menú no inicia tareas ni crea relojes de reposo.
/// [maxWidth] permite compactar un menú sin estrechar las demás ventanas.
Future<T?> showNanoAnchoredPopover<T>({
  required BuildContext anchorContext,
  required WidgetBuilder builder,
  required String label,
  double maxWidth = 320,
}) {
  final navigator = Navigator.of(anchorContext, rootNavigator: true);
  final themes = InheritedTheme.capture(
    from: anchorContext,
    to: navigator.context,
  );
  final box = anchorContext.findRenderObject();
  final media = MediaQuery.of(anchorContext);
  final fallback = Rect.fromLTWH(
    16,
    media.size.height - media.viewInsets.bottom - 64,
    48,
    48,
  );
  final initial = box is RenderBox && box.attached && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : fallback;
  Rect currentAnchor() =>
      box is RenderBox && box.attached && box.hasSize && !box.size.isEmpty
      ? box.localToGlobal(Offset.zero) & box.size
      : initial;
  final reduced = media.disableAnimations;
  return showGeneralDialog<T>(
    context: anchorContext,
    requestFocus: false,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(
      anchorContext,
    ).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: reduced
        ? Duration.zero
        : const Duration(milliseconds: 190),
    pageBuilder: (route, _, _) => themes.wrap(
      Builder(
        builder: (context) {
          final viewport = MediaQuery.of(context);
          final animation = ModalRoute.of(route)!.animation!;
          return CustomSingleChildLayout(
            delegate: _PopoverPlacement(
              currentAnchor(),
              viewport.padding,
              viewport.viewInsets.bottom,
              Directionality.of(context),
              maxWidth,
            ),
            child: ScaleTransition(
              alignment: Alignment.bottomLeft,
              scale: animation.drive(
                Tween(
                  begin: .96,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: Semantics(
                scopesRoute: true,
                // Una ruta semántica debe exponer sus hijos explícitamente.
                // Sin esto Flutter rechaza el menú antes de dibujar sus acciones.
                explicitChildNodes: true,
                namesRoute: true,
                label: label,
                child: Material(
                  type: MaterialType.transparency,
                  child: GlassSurface(
                    interactive: false,
                    radius: 24,
                    blur: 16,
                    padding: const EdgeInsets.all(8),
                    child: AnimatedSize(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomLeft,
                      child: Builder(builder: builder),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Prefiere situarse arriba del botón y limita ambos ejes al espacio seguro
/// disponible sobre el teclado. Usa el tamaño real del contenido, no una altura fija.
class _PopoverPlacement extends SingleChildLayoutDelegate {
  _PopoverPlacement(
    this.anchor,
    this.padding,
    this.keyboard,
    this.direction,
    this.maxWidth,
  );
  final Rect anchor;
  final EdgeInsets padding;
  final double keyboard;
  final TextDirection direction;
  final double maxWidth;
  Rect _available(Size size) => Rect.fromLTRB(
    padding.left + 8,
    padding.top + 8,
    math.max(padding.left + 8, size.width - padding.right - 8),
    math.max(
      padding.top + 8,
      size.height - math.max(padding.bottom, keyboard) - 8,
    ),
  );
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = _available(constraints.biggest);
    // Cada menú limita su ancho sin imponerlo a los demás paneles compartidos.
    final width = math.min(maxWidth, room.width);
    return BoxConstraints(
      minWidth: math.min(260, width),
      maxWidth: width,
      maxHeight: math.min(420, room.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final room = _available(size);
    final preferredX = direction == TextDirection.rtl
        ? anchor.right - childSize.width
        : anchor.left;
    final above = anchor.top - childSize.height - 8;
    final below = anchor.bottom + 8;
    final preferredY = above >= room.top
        ? above
        : below + childSize.height <= room.bottom
        ? below
        : above;
    return Offset(
      preferredX.clamp(
        room.left,
        math.max(room.left, room.right - childSize.width),
      ),
      preferredY.clamp(
        room.top,
        math.max(room.top, room.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopoverPlacement old) =>
      anchor != old.anchor ||
      padding != old.padding ||
      keyboard != old.keyboard ||
      direction != old.direction ||
      maxWidth != old.maxWidth;
}
